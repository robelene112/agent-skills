import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/update-matt-pocock.py'
SPEC = importlib.util.spec_from_file_location('updater', SCRIPT)
updater = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(updater)


def skill(name):
    return f'---\nname: {name}\ndescription: A bounded {name} task.\n---\nBody.\n'.encode()


def archive(skills, extras=None, symlink=None):
    files = {
        '.claude-plugin/plugin.json': json.dumps({
            'skills': [f'./skills/engineering/{name}' for name in skills]
        }).encode(),
        'LICENSE': b'MIT License\n',
    }
    files.update({f'skills/engineering/{name}/SKILL.md': raw for name, raw in skills.items()})
    files.update(extras or {})
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode='w:gz') as tar:
        for name, raw in files.items():
            item = tarfile.TarInfo('upstream/' + name)
            item.size = len(raw)
            tar.addfile(item, io.BytesIO(raw))
        if symlink:
            item = tarfile.TarInfo('upstream/' + symlink)
            item.type = tarfile.SYMTYPE
            item.linkname = '../../../personal/SKILL.md'
            tar.addfile(item)
    return stream.getvalue()


class UpstreamUpdateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.vendor = self.root / 'vendor/matt-pocock'
        old = self.vendor / 'skills/old/SKILL.md'
        old.parent.mkdir(parents=True)
        old.write_bytes(skill('old'))
        (self.vendor / 'LICENSE').write_bytes(b'MIT License\n')
        (self.vendor / 'source.json').write_text(json.dumps({
            'revision': 'a' * 40,
            'files': {'skills/old/SKILL.md': hashlib.sha256(old.read_bytes()).hexdigest()},
        }))
        self.personal = self.root / 'skills/personal-example/SKILL.md'
        self.personal.parent.mkdir(parents=True)
        self.personal.write_bytes(b'Personal decisions stay here.\n')

    def test_add_remove_and_metadata_preserve_personal_skill(self):
        candidate = archive({'new': skill('new')}, {
            'skills/engineering/new/agents/openai.yaml':
                b'policy:\n  allow_implicit_invocation: false\n',
        })
        result = updater.update(self.vendor, candidate, 'b' * 40)
        self.assertEqual(result['added'], ['new'])
        self.assertEqual(result['removed'], ['old'])
        self.assertFalse((self.vendor / 'skills/old').exists())
        self.assertEqual(self.personal.read_bytes(), b'Personal decisions stay here.\n')
        self.assertEqual((self.vendor / 'skills/new/agents/openai.yaml').read_bytes(),
                         b'policy:\n  allow_implicit_invocation: false\n')
        manifest, _, _, _ = updater.check_vendor(self.vendor)
        self.assertEqual(manifest['revision'], 'b' * 40)

    def test_same_payload_avoids_update_for_unrelated_upstream_commit(self):
        before = (self.vendor / 'source.json').read_bytes()
        result = updater.update(self.vendor, archive({'old': skill('old')}), 'b' * 40)
        self.assertFalse(result['changed'])
        self.assertEqual((self.vendor / 'source.json').read_bytes(), before)

    def test_local_vendor_edits_are_not_overwritten(self):
        old = self.vendor / 'skills/old/SKILL.md'
        old.write_bytes(b'Local edit\n')
        with self.assertRaisesRegex(ValueError, 'Locally modified'):
            updater.update(self.vendor, archive({'new': skill('new')}), 'b' * 40)
        self.assertEqual(old.read_bytes(), b'Local edit\n')
        self.assertFalse((self.vendor / 'skills/new').exists())

    def test_invalid_metadata_leaves_existing_snapshot_intact(self):
        before = (self.vendor / 'source.json').read_bytes()
        with self.assertRaisesRegex(ValueError, 'Missing frontmatter'):
            updater.update(self.vendor, archive({'new': b'Not a skill\n'}), 'b' * 40)
        self.assertEqual((self.vendor / 'source.json').read_bytes(), before)
        updater.check_vendor(self.vendor)

    def test_traversal_and_symlinks_cannot_enter_snapshot(self):
        for candidate in [
            archive({'new': skill('new')}, {'../outside': b'Bad\n'}),
            archive({'new': skill('new')}, symlink='skills/engineering/new/linked.md'),
        ]:
            with self.subTest(), self.assertRaises(ValueError):
                updater.update(self.vendor, candidate, 'b' * 40)
            updater.check_vendor(self.vendor)
        self.assertEqual(self.personal.read_bytes(), b'Personal decisions stay here.\n')


if __name__ == '__main__':
    unittest.main()
