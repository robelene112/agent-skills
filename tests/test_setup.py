"""Exercise setup/update using temporary homes and local Git remotes only."""

from contextlib import redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location('skills_setup', Path(__file__).parents[1] / 'setup.py')
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='agent-skills-test-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.home = self.base / 'home with spaces'
        self.home.mkdir()
        self.repo = self.base / 'source'
        self.repo.mkdir()
        (self.repo / 'instructions/global').mkdir(parents=True)
        (self.repo / 'instructions/global/AGENTS.md').write_text('# Personal rules\nRead the skills.\n')
        for name in (*setup.PERSONAL, 'outlook-local', 'saito-dev', 'odoo-20'):
            self.skill(self.repo / 'skills' / name)
        self.skill(self.repo / 'vendor/matt-pocock/skills/grill-with-docs')
        self.skill(self.repo / 'vendor/matt-pocock/skills/implement-spec')
        self.state = self.home / '.local/state/agent-skills/install.json'
        self.env = patch.dict(os.environ, {'HOME': str(self.home)}, clear=False)
        self.env.start()
        self.addCleanup(self.env.stop)
        self.codex = patch.dict(os.environ, {'CODEX_HOME': str(self.home / '.codex')})
        self.codex.start()
        self.addCleanup(self.codex.stop)

    @staticmethod
    def skill(path):
        path.mkdir(parents=True)
        (path / 'SKILL.md').write_text(f'---\nname: {path.name}\ndescription: Test skill\n---\n')

    def apply(self, env='linux', claude=False):
        previous = json.loads(self.state.read_text()) if self.state.exists() else {}
        with redirect_stdout(io.StringIO()):
            setup.apply(self.repo, self.home, self.state, previous, env, claude)

    def test_install_is_idempotent_and_updates_instructions_without_losing_local_text(self):
        doc = self.home / '.codex/AGENTS.md'
        doc.parent.mkdir()
        local = '# Laptop rules\r\nKeep these exact bytes.\r\n'
        doc.write_bytes(local.encode())
        self.apply()
        link = self.home / '.agents/skills/global-communication'
        self.assertTrue(link.is_symlink())
        self.assertEqual(link.resolve(), self.repo / 'skills/global-communication')
        self.assertTrue(doc.read_bytes().startswith(local.encode()))
        before = {p: p.stat().st_mtime_ns for p in (doc, self.state)}
        self.apply()
        self.assertEqual(before, {p: p.stat().st_mtime_ns for p in before})
        (self.repo / 'instructions/global/AGENTS.md').write_text('# Personal rules\nUpdated rules.\n')
        self.apply()
        self.assertIn('Updated rules.', doc.read_text())
        self.assertEqual(doc.read_text().count(setup.BEGIN), 1)
        self.assertTrue(doc.read_bytes().startswith(local.encode()))

    def test_profiles_and_pocock_additions_removals_reconcile_only_managed_links(self):
        self.apply('wsl')
        root = self.home / '.agents/skills'
        self.assertTrue((root / 'outlook-local').is_symlink())
        self.assertFalse((root / 'saito-dev').exists())
        self.assertFalse((root / 'odoo-20').exists())
        unrelated = root / 'my-local-skill'
        self.skill(unrelated)
        shutil.rmtree(self.repo / 'vendor/matt-pocock/skills/implement-spec')
        self.skill(self.repo / 'vendor/matt-pocock/skills/new-stable-skill')
        self.apply('vps')
        self.assertFalse(os.path.lexists(root / 'implement-spec'))
        self.assertFalse(os.path.lexists(root / 'outlook-local'))
        self.assertTrue((root / 'new-stable-skill').is_symlink())
        self.assertTrue((unrelated / 'SKILL.md').exists())
        self.assertIn('environments/vps/STORAGE.md', (self.home / '.codex/AGENTS.md').read_text())
        self.apply('linux')
        self.assertNotIn('environments/vps/STORAGE.md', (self.home / '.codex/AGENTS.md').read_text())

    def test_conflict_preserves_all_existing_files_before_making_changes(self):
        conflicting = self.home / '.agents/skills/workspace-hygiene'
        self.skill(conflicting)
        original = (conflicting / 'SKILL.md').read_bytes()
        with self.assertRaisesRegex(setup.SetupError, 'Existing skill was preserved'):
            self.apply()
        self.assertEqual((conflicting / 'SKILL.md').read_bytes(), original)
        self.assertFalse((self.home / '.agents/skills/global-communication').exists())
        self.assertFalse((self.home / '.codex/AGENTS.md').exists())
        self.assertFalse(self.state.exists())

    def test_changed_obsolete_link_is_preserved(self):
        self.apply('wsl')
        link = self.home / '.agents/skills/outlook-local'
        link.unlink()
        link.symlink_to(self.home / 'my-other-outlook-skill')
        with self.assertRaisesRegex(setup.SetupError, 'changed locally'):
            self.apply('linux')
        self.assertEqual(link.readlink(), self.home / 'my-other-outlook-skill')

    def test_legacy_codex_skills_are_backed_up_without_active_duplicates(self):
        legacy_root = self.home / '.codex/skills'
        legacy = legacy_root / 'grill-with-docs'
        self.skill(legacy)
        customized = b'Keep my local changes.\n'
        (legacy / 'local-notes.txt').write_bytes(customized)
        original = (legacy / 'SKILL.md').read_bytes()
        unrelated = legacy_root / 'my-custom-skill'
        self.skill(unrelated)
        system = legacy_root / '.system'
        system.mkdir()
        (system / 'keep.txt').write_text('Bundled skills stay in place.')
        self.apply()
        self.assertFalse(os.path.lexists(legacy))
        self.assertEqual((self.home / '.agents/skills/grill-with-docs').resolve(),
                         self.repo / 'vendor/matt-pocock/skills/grill-with-docs')
        state = json.loads(self.state.read_text())
        backup = Path(state['legacy_backups'][0])
        self.assertNotIn(legacy_root, backup.parents)
        self.assertEqual((backup / 'grill-with-docs/SKILL.md').read_bytes(), original)
        self.assertEqual((backup / 'grill-with-docs/local-notes.txt').read_bytes(), customized)
        self.assertTrue((unrelated / 'SKILL.md').exists())
        self.assertEqual((system / 'keep.txt').read_text(), 'Bundled skills stay in place.')
        before = self.state.read_bytes()
        self.apply()
        self.assertEqual(self.state.read_bytes(), before)
        self.assertEqual(list(backup.parent.iterdir()), [backup])

    def test_legacy_symlinks_are_backed_up_without_touching_their_targets(self):
        legacy_root = self.home / '.codex/skills'
        legacy_root.mkdir(parents=True)
        external = self.base / 'external-skill'
        self.skill(external)
        original = (external / 'SKILL.md').read_bytes()
        (legacy_root / 'grill-with-docs').symlink_to(external, target_is_directory=True)
        (legacy_root / 'implement-spec').symlink_to('../missing-skill', target_is_directory=True)
        self.apply()
        backup = Path(json.loads(self.state.read_text())['legacy_backups'][0])
        self.assertEqual((backup / 'grill-with-docs').readlink(), external)
        self.assertEqual((backup / 'implement-spec').readlink(), Path('../missing-skill'))
        self.assertEqual((external / 'SKILL.md').read_bytes(), original)
        self.assertFalse(os.path.lexists(legacy_root / 'grill-with-docs'))
        self.assertFalse(os.path.lexists(legacy_root / 'implement-spec'))

    def test_other_conflicts_are_checked_before_moving_any_legacy_skills(self):
        legacy = self.home / '.codex/skills/grill-with-docs'
        self.skill(legacy)
        self.skill(self.home / '.agents/skills/workspace-hygiene')
        with self.assertRaisesRegex(setup.SetupError, 'Existing skill was preserved'):
            self.apply()
        self.assertTrue((legacy / 'SKILL.md').exists())
        self.assertFalse((self.state.parent / 'backups').exists())

    def test_failed_legacy_migration_restores_completed_moves(self):
        legacy_root = self.home / '.codex/skills'
        for name in ('grill-with-docs', 'implement-spec'):
            self.skill(legacy_root / name)
        original_move = shutil.move
        calls = 0

        def fail_second_move(source, target):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError('Simulated backup failure')
            return original_move(source, target)

        with patch.object(setup.shutil, 'move', side_effect=fail_second_move):
            with self.assertRaisesRegex(setup.SetupError, 'Completed moves were restored'):
                self.apply()
        for name in ('grill-with-docs', 'implement-spec'):
            self.assertTrue((legacy_root / name / 'SKILL.md').exists())
        self.assertFalse((self.home / '.agents').exists())
        self.assertFalse(self.state.exists())
        self.assertEqual(list((self.state.parent / 'backups').iterdir()), [])

    def test_legacy_root_alias_is_not_migrated_repeatedly(self):
        self.apply()
        (self.home / '.codex/skills').symlink_to(self.home / '.agents/skills', target_is_directory=True)
        before = self.state.read_bytes()
        self.apply()
        self.assertEqual(self.state.read_bytes(), before)
        self.assertFalse((self.state.parent / 'backups').exists())

    def test_custom_codex_home_override_and_claude_preserve_existing_settings(self):
        custom = self.home / 'codex profile'
        custom.mkdir()
        override = custom / 'AGENTS.override.md'
        override.write_text('My temporary override.\n')
        base = custom / 'AGENTS.md'
        base.write_text('Keep the inactive base.\n')
        with patch.dict(os.environ, {'CODEX_HOME': str(custom)}):
            self.apply(claude=True)
        self.assertIn('My temporary override.', override.read_text())
        self.assertIn(setup.BEGIN, override.read_text())
        self.assertEqual(base.read_text(), 'Keep the inactive base.\n')
        self.assertTrue((self.home / '.claude/skills/grill-with-docs').is_symlink())
        self.assertIn(setup.BEGIN, (self.home / '.claude/CLAUDE.md').read_text())

    def test_existing_exact_template_is_adopted_without_duplication(self):
        doc = self.home / '.codex/AGENTS.md'
        doc.parent.mkdir()
        shutil.copyfile(self.repo / 'instructions/global/AGENTS.md', doc)
        self.apply()
        self.assertEqual(doc.read_text().count('# Personal rules'), 1)

    def test_instruction_symlinks_and_broken_managed_blocks_are_preserved(self):
        doc = self.home / '.codex/AGENTS.md'
        doc.parent.mkdir()
        source = self.repo / 'instructions/global/AGENTS.md'
        original = source.read_bytes()
        doc.symlink_to(source)
        with self.assertRaisesRegex(setup.SetupError, 'manual inspection'):
            self.apply()
        self.assertEqual(source.read_bytes(), original)
        doc.unlink()
        doc.write_text(setup.BEGIN + '\nMissing end marker.\n')
        with self.assertRaisesRegex(setup.SetupError, 'Malformed'):
            self.apply()
        self.assertFalse((self.home / '.agents').exists())

    def test_environment_auto_detection_and_remembered_vps(self):
        with patch('platform.release', return_value='6.6-microsoft-standard-WSL2'):
            self.assertEqual(setup.environment('auto', {}), 'wsl')
        with patch.dict(os.environ, {}, clear=True), patch('platform.release', return_value='6.17-arch1'):
            self.assertEqual(setup.environment('auto', {}), 'linux')
        self.assertEqual(setup.environment('auto', {'environment': 'vps'}), 'vps')
        self.assertEqual(setup.environment('wsl', {'environment': 'vps'}), 'wsl')

    def test_parallel_setup_is_rejected(self):
        with setup.locked(self.state.parent):
            with self.assertRaisesRegex(setup.SetupError, 'Another skills setup'):
                with setup.locked(self.state.parent):
                    self.fail('Second setup acquired the lock')

    def test_cli_installs_real_snapshot_and_second_run_changes_nothing(self):
        # Exercise argument parsing, profile persistence and the public snapshot,
        # without touching the caller's home or reaching a network service.
        real_repo = Path(__file__).resolve().parents[1]
        installer = real_repo / 'setup.py'
        # Reproduce an already populated work laptop using every skill in the
        # real snapshot, including local edits that must survive migration.
        upstream = sorted((real_repo / 'vendor/matt-pocock/skills').iterdir())
        for skill in upstream:
            self.skill(self.home / '.codex/skills' / skill.name)
            (self.home / '.codex/skills' / skill.name / 'local.txt').write_text('My local changes.')
        with patch.dict(os.environ, {'XDG_STATE_HOME': str(self.home / 'state')}):
            command = [sys.executable, str(installer), '--offline', '--environment', 'wsl']
            first = subprocess.run(command, text=True, capture_output=True, env=os.environ)
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertIn('Ready (wsl)', first.stdout)
            state = json.loads((self.home / 'state/agent-skills/install.json').read_text())
            backup = Path(state['legacy_backups'][0])
            for skill in upstream:
                self.assertFalse(os.path.lexists(self.home / '.codex/skills' / skill.name))
                self.assertEqual((backup / skill.name / 'local.txt').read_text(), 'My local changes.')
            link = self.home / '.agents/skills/outlook-local'
            self.assertEqual(link.resolve(), real_repo / 'skills/outlook-local')
            second = subprocess.run(command[:-2], text=True, capture_output=True, env=os.environ)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertIn('Ready (wsl)', second.stdout)
            self.assertIn('0 links created, 0 removed, 0 instruction files updated', second.stdout)


class GitUpdateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='skills-git-test-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.remote = self.base / 'remote.git'
        self.writer = self.base / 'writer'
        self.checkout = self.base / 'checkout'
        self.run_git(self.base, 'init', '--bare', '--initial-branch=main', str(self.remote))
        self.run_git(self.base, 'clone', str(self.remote), str(self.writer))
        self.run_git(self.writer, 'config', 'user.name', 'Setup Test')
        self.run_git(self.writer, 'config', 'user.email', 'test@example.invalid')
        (self.writer / 'instructions/global').mkdir(parents=True)
        (self.writer / 'instructions/global/AGENTS.md').write_text('Test rules.\n')
        self.commit('Initial')
        self.patch_remote = patch.object(setup, 'REMOTE', str(self.remote))
        self.patch_remote.start()
        self.addCleanup(self.patch_remote.stop)
        with redirect_stdout(io.StringIO()):
            setup.sync(self.checkout, False)

    @staticmethod
    def run_git(repo, *args):
        return subprocess.run(['git', '-C', str(repo), *args], check=True, capture_output=True, text=True).stdout.strip()

    def commit(self, message):
        self.run_git(self.writer, 'add', '.')
        self.run_git(self.writer, 'commit', '-m', message)
        self.run_git(self.writer, 'push', 'origin', 'main')

    def test_clone_and_fast_forward_use_local_remote(self):
        (self.writer / 'new-file').write_text('upstream change')
        self.commit('Upstream update')
        with redirect_stdout(io.StringIO()):
            self.assertTrue(setup.sync(self.checkout, False))
            self.assertFalse(setup.sync(self.checkout, False))
        self.assertEqual((self.checkout / 'new-file').read_text(), 'upstream change')

    def test_dirty_source_is_preserved(self):
        (self.checkout / 'untracked-note').write_text('keep me')
        with self.assertRaisesRegex(setup.SetupError, 'local changes'):
            setup.sync(self.checkout, False)
        self.assertEqual((self.checkout / 'untracked-note').read_text(), 'keep me')

    def test_local_commits_unexpected_remotes_and_pins_are_preserved(self):
        self.run_git(self.checkout, 'config', 'user.name', 'Setup Test')
        self.run_git(self.checkout, 'config', 'user.email', 'test@example.invalid')
        self.run_git(self.checkout, 'commit', '--allow-empty', '-m', 'Local only')
        head = self.run_git(self.checkout, 'rev-parse', 'HEAD')
        with self.assertRaisesRegex(setup.SetupError, 'local commits'):
            setup.sync(self.checkout, False)
        self.assertEqual(self.run_git(self.checkout, 'rev-parse', 'HEAD'), head)
        self.run_git(self.checkout, 'remote', 'set-url', 'origin', str(self.base / 'unexpected.git'))
        with self.assertRaisesRegex(setup.SetupError, 'Unexpected origin'):
            setup.sync(self.checkout, False)
        self.run_git(self.checkout, 'remote', 'set-url', 'origin', str(self.remote))
        self.run_git(self.checkout, 'checkout', '--detach')
        with self.assertRaisesRegex(setup.SetupError, 'pinned'):
            setup.sync(self.checkout, False)

    def test_fetch_failure_is_not_reported_as_current(self):
        shutil.rmtree(self.remote)
        with self.assertRaises(setup.SetupError):
            setup.sync(self.checkout, False)

    def test_downloaded_bootstrap_and_self_update_execute_new_installer(self):
        code = (Path(__file__).parents[1] / 'setup.py').read_text()
        code = code.replace(f'REMOTE = {setup.REMOTE!r}', f'REMOTE = {str(self.remote)!r}')
        # The module constant is patched to the local remote for these tests;
        # replace the original public literal in the source as well.
        code = code.replace("REMOTE = 'https://github.com/robelene112/agent-skills.git'",
                            f'REMOTE = {str(self.remote)!r}')
        (self.writer / 'setup.py').write_text(code)
        for name in setup.PERSONAL:
            SetupTests.skill(self.writer / 'skills' / name)
        SetupTests.skill(self.writer / 'vendor/matt-pocock/skills/grill-with-docs')
        self.commit('Add installer')
        home = self.base / 'bootstrap-home'
        home.mkdir()
        source = home / 'agent-skills'
        env = {**os.environ, 'HOME': str(home), 'CODEX_HOME': str(home / '.codex'),
               'XDG_STATE_HOME': str(home / 'state')}
        bootstrap = subprocess.run([sys.executable, '-'], input=code, text=True,
                                   capture_output=True, cwd=home, env=env)
        self.assertEqual(bootstrap.returncode, 0, bootstrap.stderr)
        self.assertTrue((source / '.git').is_dir())
        self.assertTrue((home / '.agents/skills/grill-with-docs').is_symlink())
        # A syntax change that only the new process can observe proves the
        # updater does not finish installation with its previously loaded code.
        (self.writer / 'setup.py').write_text(code.replace("print(f'Ready ({env})",
                                                          "print(f'NEW INSTALLER ({env})"))
        SetupTests.skill(self.writer / 'vendor/matt-pocock/skills/added-upstream')
        self.commit('Installer and skill update')
        updated = subprocess.run([sys.executable, str(source / 'setup.py')], text=True,
                                 capture_output=True, cwd=home, env=env)
        self.assertEqual(updated.returncode, 0, updated.stderr)
        self.assertIn('NEW INSTALLER', updated.stdout)
        self.assertTrue((home / '.agents/skills/added-upstream').is_symlink())


if __name__ == '__main__':
    unittest.main()
