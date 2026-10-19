#!/usr/bin/env python3
"""Install or update shared agent skills on Linux and Windows through WSL."""

import argparse
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import platform
import shlex
import shutil
import subprocess
import sys
import tempfile


REMOTE = 'https://github.com/robelene112/agent-skills.git'
PERSONAL = (
    'global-communication', 'workspace-hygiene', 'proactive-updates',
    'github-issues', 'development-preferences',
)
BEGIN = '<!-- agent-skills:begin -->'
END = '<!-- agent-skills:end -->'


class SetupError(Exception):
    pass


def git(repo, *args):
    result = subprocess.run(
        ['git', '-C', str(repo), *args], text=True, capture_output=True,
        timeout=120, env={**os.environ, 'GIT_TERMINAL_PROMPT': '0'},
    )
    if result.returncode:
        raise SetupError(result.stderr.strip() or 'Git command failed.')
    return result.stdout.strip()


@contextmanager
def locked(state_dir):
    state_dir.mkdir(parents=True, exist_ok=True)
    with (state_dir / 'setup.lock').open('a') as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SetupError('Another skills setup/update is running.') from None
        yield


def sync(repo, offline):
    if not repo.exists():
        if offline:
            raise SetupError('--offline needs an existing source checkout.')
        repo.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='.agent-skills-', dir=repo.parent) as tmp:
            clone = Path(tmp) / 'source'
            git(repo.parent, 'clone', '--quiet', '--origin', 'origin', REMOTE, str(clone))
            clone.rename(repo)
        print(f'Cloned {repo}', flush=True)
    if not (repo / 'instructions/global/AGENTS.md').is_file():
        raise SetupError(f'Not an agent-skills source checkout: {repo}')
    if offline:
        return False
    if Path(git(repo, 'rev-parse', '--show-toplevel')).resolve() != repo:
        raise SetupError('The source must be its own Git checkout.')
    remote = git(repo, 'remote', 'get-url', 'origin')
    if remote not in (REMOTE, REMOTE.removesuffix('.git'),
                       'git@github.com:robelene112/agent-skills.git'):
        raise SetupError('Unexpected origin; source checkout was left intact.')
    if git(repo, 'branch', '--show-current') != 'main':
        raise SetupError('Source is pinned or not on main; checkout was left intact.')
    if git(repo, 'rev-parse', '--abbrev-ref', '@{upstream}') != 'origin/main':
        raise SetupError('Expected upstream origin/main; checkout was left intact.')
    if git(repo, 'status', '--porcelain', '--untracked-files=all'):
        raise SetupError('Source has local changes; commit or resolve them before updating.')
    git(repo, 'fetch', '--quiet', 'origin', 'refs/heads/main:refs/remotes/origin/main')
    ahead, behind = map(int, git(repo, 'rev-list', '--left-right', '--count',
                                'HEAD...origin/main').split())
    if ahead:
        raise SetupError('Source has local commits or diverged; checkout was left intact.')
    if behind:
        # Check again after the network call. The setup lock serializes this
        # helper, while Git locks protect its own operations.
        if git(repo, 'status', '--porcelain', '--untracked-files=all'):
            raise SetupError('Source changed while fetching; update stopped.')
        git(repo, 'merge', '--ff-only', 'origin/main')
        print('Updated source with a fast-forward.', flush=True)
        return True
    print('Source is up to date.', flush=True)
    return False


def environment(requested, previous):
    if requested != 'auto':
        return requested
    if previous.get('environment') in ('linux', 'wsl', 'vps'):
        return previous['environment']
    release = platform.release().lower()
    return 'wsl' if 'microsoft' in release or 'WSL_INTEROP' in os.environ else 'linux'


def desired_skills(repo, env):
    sources = {name: repo / 'skills' / name for name in PERSONAL}
    if env == 'wsl':
        sources['outlook-local'] = repo / 'skills/outlook-local'
    vendor = repo / 'vendor/matt-pocock/skills'
    upstream = sorted(path for path in vendor.iterdir() if path.is_dir())
    if not upstream:
        raise SetupError('No Matt Pocock skills found in the source.')
    for path in upstream:
        if path.name in sources:
            raise SetupError(f'Skill name collision: {path.name}')
        sources[path.name] = path
    for name, source in sources.items():
        if not (source / 'SKILL.md').is_file():
            raise SetupError(f'Skill is missing its SKILL.md: {name}')
    return sources


def global_guidance(repo, env):
    text = (repo / 'instructions/global/AGENTS.md').read_text(encoding='utf-8').rstrip()
    if env == 'vps':
        text += ('\n\nFor disk-space decisions, large artifacts or filesystem work on this VPS,\n'
                 f'read `{repo}/environments/vps/STORAGE.md` and verify the actual mounts.\n')
    return text


def merge_guidance(existing, guidance, original):
    block = f'{BEGIN}\n{guidance.rstrip()}\n{END}'
    if BEGIN in existing or END in existing:
        if existing.count(BEGIN) != 1 or existing.count(END) != 1:
            raise SetupError('Malformed managed instructions block; repair it before setup.')
        start, end = existing.index(BEGIN), existing.index(END)
        if end < start:
            raise SetupError('Malformed managed instructions block; repair it before setup.')
        return existing[:start] + block + existing[end + len(END):]
    # Adopt the previously installed, exact global template without doubling it.
    if not existing.strip() or existing.strip() == original.strip():
        return block + '\n'
    return existing + ('\n' if existing.endswith('\n') else '\n\n') + block + '\n'


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, filename = tempfile.mkstemp(prefix=f'.{path.name}.', dir=path.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='') as handle:
            handle.write(text)
        if path.exists():
            os.chmod(filename, path.stat().st_mode & 0o777)
        os.replace(filename, path)
    finally:
        Path(filename).unlink(missing_ok=True)


def backup_legacy(paths, state_dir):
    """Move superseded Codex installs outside discovery, retaining local edits."""
    if not paths:
        return None
    backup_root = state_dir / 'backups'
    backup_root.mkdir(parents=True, exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix='legacy-codex-skills-', dir=backup_root))
    print(f'Backing up {len(paths)} legacy skills to {backup}', flush=True)
    moved = []
    try:
        for original in paths:
            saved = backup / original.name
            shutil.move(str(original), str(saved))
            moved.append((original, saved))
    except (OSError, KeyboardInterrupt) as error:
        rollback_errors = []
        for original, saved in reversed(moved):
            try:
                if os.path.lexists(original):
                    raise OSError(f'Original path is now occupied: {original}')
                shutil.move(str(saved), str(original))
            except OSError as rollback_error:
                rollback_errors.append(str(rollback_error))
        if rollback_errors:
            detail = '; '.join(rollback_errors)
            raise SetupError(f'Legacy migration stopped: {error}. '
                             f'Some backups still need restoring from {backup}: {detail}') from error
        if not any(backup.iterdir()):
            backup.rmdir()
        raise SetupError(f'Legacy migration stopped: {error}. '
                         f'Completed moves were restored; any incomplete copies are under {backup}.') from error
    return backup


def apply(repo, home, state_file, previous, env, claude):
    sources = desired_skills(repo, env)
    roots = [home / '.agents/skills']
    if claude:
        roots.append(home / '.claude/skills')
    links = {str(root / name): str(source) for root in roots for name, source in sources.items()}
    conflicts = []
    for name, target in links.items():
        dest = Path(name)
        if dest.is_symlink() and dest.resolve() == Path(target).resolve():
            continue
        if os.path.lexists(dest):
            conflicts.append(f'Existing skill was preserved: {dest}')
    # Retire only names supplied by this checkout. Keep the old payload outside
    # discovery, including local edits; bundled and unrelated skills stay put.
    codex_home = Path(os.environ.get('CODEX_HOME') or home / '.codex').expanduser()
    legacy_paths = []
    for name in sources:
        legacy = codex_home / 'skills' / name
        if os.path.lexists(legacy) and not any(legacy.parent.resolve() == root.resolve() for root in roots):
            legacy_paths.append(legacy)

    override = codex_home / 'AGENTS.override.md'
    codex_doc = override if override.is_file() and override.stat().st_size else codex_home / 'AGENTS.md'
    docs = [codex_doc]
    if claude:
        docs.append(home / '.claude/CLAUDE.md')
    writes = {}
    guidance = global_guidance(repo, env)
    original = (repo / 'instructions/global/AGENTS.md').read_text(encoding='utf-8')
    for doc in docs:
        if doc.is_symlink() or (doc.exists() and not doc.is_file()):
            conflicts.append(f'Instructions need manual inspection: {doc}')
            continue
        existing = doc.read_bytes().decode('utf-8') if doc.exists() else ''
        updated = merge_guidance(existing, guidance, original)
        if updated != existing:
            writes[doc] = updated

    removals = []
    for name, target in previous.get('links', {}).items():
        if name in links:
            continue
        dest = Path(name)
        if dest.parent not in (home / '.agents/skills', home / '.claude/skills'):
            raise SetupError(f'Invalid managed path in local state: {dest}')
        if dest.is_symlink() and str(dest.readlink()) == target:
            removals.append(dest)
        elif os.path.lexists(dest):
            conflicts.append(f'Previously managed skill changed locally: {dest}')
    if conflicts:
        raise SetupError('\n'.join(conflicts) + '\nNo skills or instructions were changed.')

    backups = list(previous.get('legacy_backups', []))
    backup = backup_legacy(legacy_paths, state_file.parent)
    if backup:
        backups.append(str(backup))
    created = 0
    # Record literal link targets, including existing equivalent indirect links,
    # so cleanup later only removes links we can still identify as our own.
    installed = {}
    for name, target in links.items():
        dest = Path(name)
        if not dest.is_symlink():
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.symlink_to(target, target_is_directory=True)
            created += 1
        installed[name] = str(dest.readlink())
    for doc, content in writes.items():
        atomic_write(doc, content)
    for dest in removals:
        dest.unlink()
    state = {'repository': str(repo), 'environment': env, 'claude': claude, 'links': installed}
    if backups:
        state['legacy_backups'] = backups
    serialized = json.dumps(state, indent=2, sort_keys=True) + '\n'
    if not state_file.exists() or state_file.read_text(encoding='utf-8') != serialized:
        atomic_write(state_file, serialized)
    print(f'Ready ({env}): {len(sources)} skills per agent; '
          f'{created} links created, {len(removals)} removed, {len(writes)} instruction files updated.')
    print(f'Next setup/update: python3 {shlex.quote(str(repo / "setup.py"))}')
    print('Start a new Codex session to load the global instructions.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo-dir', type=Path, help='Source checkout (default: ~/agent-skills)')
    parser.add_argument('--environment', choices=('auto', 'linux', 'wsl', 'vps'), default='auto',
                        help='Remember the machine profile; auto detects WSL on first setup')
    parser.add_argument('--claude', action='store_true', help='Also set up Claude Code, even if not installed yet')
    parser.add_argument('--offline', action='store_true', help='Apply an existing checkout without fetching updates')
    args = parser.parse_args()
    if platform.system() != 'Linux':
        raise SetupError('Run this script on Linux or inside WSL, not Windows PowerShell.')
    if not shutil.which('git'):
        raise SetupError('Install Git first (Arch: sudo pacman -S git; Ubuntu/WSL: sudo apt install git).')
    home = Path.home()
    state_dir = Path(os.environ.get('XDG_STATE_HOME') or home / '.local/state') / 'agent-skills'
    state_file = state_dir / 'install.json'
    rerun = False
    with locked(state_dir):
        previous = json.loads(state_file.read_text(encoding='utf-8')) if state_file.exists() else {}
        script = Path(globals().get('__file__', '<stdin>')).resolve()
        local_repo = script.parent if (script.parent / 'instructions/global/AGENTS.md').is_file() else None
        repo = (args.repo_dir or local_repo or Path(previous.get('repository', home / 'agent-skills'))).expanduser().resolve()
        changed = sync(repo, args.offline)
        # Run the newly fetched installer rather than finishing with stale code
        # already loaded in this process (also handles the downloaded bootstrap).
        rerun = changed or script != repo / 'setup.py'
        if not rerun:
            env = environment(args.environment, previous)
            claude = args.claude or previous.get('claude', False) or (home / '.claude').is_dir()
            apply(repo, home, state_file, previous, env, claude)
    if rerun:
        forwarded = [*sys.argv[1:], '--repo-dir', str(repo)]
        if '--offline' not in forwarded:
            forwarded.append('--offline')
        os.execv(sys.executable, [sys.executable, str(repo / 'setup.py'), *forwarded])


if __name__ == '__main__':
    try:
        main()
    except (SetupError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f'Setup stopped: {error}', file=sys.stderr)
        sys.exit(1)
