#!/usr/bin/env python3
"""Refresh only the promoted Matt Pocock skills; never install or execute them."""

import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import tarfile
import tempfile
from urllib.request import Request, urlopen

import yaml

REPOSITORY = 'mattpocock/skills'
ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / 'vendor/matt-pocock'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def safe_path(value):
    path = PurePosixPath(value)
    if path.is_absolute() or '..' in path.parts or any(ord(c) < 32 for c in value):
        raise ValueError(f'Invalid archive path: {value!r}')
    return path


def validate_payload(payload):
    names = set()
    for name, raw in payload.items():
        safe_path(name)
        if not name.endswith('/SKILL.md'):
            continue
        text = raw.decode('utf-8')
        if not text.startswith('---\n') or len(text.split('---', 2)) != 3:
            raise ValueError(f'Missing frontmatter: {name}')
        meta = yaml.safe_load(text.split('---', 2)[1])
        if not isinstance(meta, dict):
            raise ValueError(f'Invalid frontmatter: {name}')
        skill = meta.get('name')
        if not isinstance(skill, str) or not re.fullmatch(r'[a-z0-9-]{1,64}', skill):
            raise ValueError(f'Invalid skill name: {name}')
        if skill != PurePosixPath(name).parent.name or skill in names:
            raise ValueError(f'Duplicate or mismatched skill name: {name}')
        if not isinstance(meta.get('description'), str) or not meta['description'].strip():
            raise ValueError(f'Missing description: {name}')
        names.add(skill)
    if not names:
        raise ValueError('Snapshot contains no skills')
    for name, raw in payload.items():
        if name.endswith('/agents/openai.yaml'):
            meta = yaml.safe_load(raw)
            if not isinstance(meta, dict):
                raise ValueError(f'Invalid Codex metadata: {name}')
            implicit = meta.get('policy', {}).get('allow_implicit_invocation')
            if implicit is not None and not isinstance(implicit, bool):
                raise ValueError(f'Invalid invocation policy: {name}')
    return names


def check_vendor(destination=VENDOR):
    manifest = json.loads((destination / 'source.json').read_text())
    expected = manifest['files']
    actual = {}
    for path in (destination / 'skills').rglob('*'):
        if path.is_symlink():
            raise ValueError(f'Unexpected symlink: {path}')
        if path.is_file():
            actual[path.relative_to(destination).as_posix()] = path.read_bytes()
    if set(expected) != set(actual):
        raise ValueError('Vendor file list differs from source.json; review local changes first')
    for name, sha in expected.items():
        safe_path(name)
        if digest(actual[name]) != sha:
            raise ValueError(f'Locally modified vendor file: {name}')
    license_data = (destination / 'LICENSE').read_bytes()
    if manifest.get('license_sha256') not in (None, digest(license_data)):
        raise ValueError('Locally modified upstream license')
    names = validate_payload(actual)
    return manifest, actual, license_data, names


def latest_revision():
    headers = {'User-Agent': 'agent-skills-updater', 'Accept': 'application/vnd.github+json'}
    token = os.environ.get('GH_TOKEN')
    if token:
        headers['Authorization'] = f'Bearer {token}'
    request = Request(f'https://api.github.com/repos/{REPOSITORY}/commits/main', headers=headers)
    with urlopen(request, timeout=30) as response:
        return json.load(response)['sha']


def download_archive(revision):
    request = Request(
        f'https://codeload.github.com/{REPOSITORY}/tar.gz/{revision}',
        headers={'User-Agent': 'agent-skills-updater'},
    )
    with urlopen(request, timeout=60) as response:
        data = response.read(32 * 1024 * 1024 + 1)
    if len(data) > 32 * 1024 * 1024:
        raise ValueError('Upstream archive exceeds the expected size limit')
    return data


def promoted_payload(archive):
    """Read regular files in memory without extracting upstream paths."""
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:gz') as tar:
        members = {}
        for member in tar.getmembers():
            relative = PurePosixPath(member.name).parts[1:]
            if not relative:
                continue
            name = '/'.join(relative)
            safe_path(name)
            if name in members:
                raise ValueError(f'Duplicate archive entry: {name}')
            members[name] = member

        def read(name):
            member = members[name]
            if not member.isfile() or member.size > 8 * 1024 * 1024:
                raise ValueError(f'Unexpected upstream file type or size: {name}')
            return tar.extractfile(member).read()

        plugin = json.loads(read('.claude-plugin/plugin.json'))
        selected = {}
        roots = []
        for raw in plugin['skills']:
            path = safe_path(raw.removeprefix('./'))
            if len(path.parts) != 3 or path.parts[:2] not in (
                ('skills', 'engineering'), ('skills', 'productivity')
            ):
                raise ValueError(f'Unexpected promoted skill location: {raw}')
            skill = path.parts[-1]
            if not re.fullmatch(r'[a-z0-9-]{1,64}', skill) or skill in selected:
                raise ValueError(f'Duplicate or invalid promoted skill: {skill}')
            selected[skill] = path.as_posix()
            roots.append(path.as_posix() + '/')
            if path.as_posix() + '/SKILL.md' not in members:
                raise ValueError(f'Promoted skill has no SKILL.md: {skill}')
        payload = {}
        for name, member in members.items():
            for prefix in roots:
                if name.startswith(prefix) and not member.isdir():
                    skill = PurePosixPath(prefix.rstrip('/')).name
                    target = f'skills/{skill}/{name[len(prefix):]}'
                    payload[target] = read(name)
                    break
        names = validate_payload(payload)
        if names != set(selected):
            raise ValueError('Promoted skill manifest differs from the snapshot')
        return payload, read('LICENSE')


def replace_snapshot(destination, payload, license_data, revision):
    manifest = {
        'repository': f'https://github.com/{REPOSITORY}',
        'revision': revision,
        'snapshot_date': datetime.now(timezone.utc).date().isoformat(),
        'scope': 'All promoted engineering and productivity skills; upstream files unchanged.',
        'skill_count': len(validate_payload(payload)),
        'license_sha256': digest(license_data),
        'files': {name: digest(raw) for name, raw in sorted(payload.items())},
    }
    with tempfile.TemporaryDirectory(prefix='.matt-update-', dir=destination.parent) as temp:
        staged = Path(temp) / 'snapshot'
        staged.mkdir()
        for name, raw in payload.items():
            path = staged / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
        (staged / 'LICENSE').write_bytes(license_data)
        (staged / 'source.json').write_text(json.dumps(manifest, indent=2) + '\n')
        check_vendor(staged)
        previous = Path(temp) / 'previous'
        destination.rename(previous)
        try:
            staged.rename(destination)
        except BaseException:
            previous.rename(destination)
            raise


def update(destination, archive, revision):
    old, previous, old_license, old_names = check_vendor(destination)
    payload, license_data = promoted_payload(archive)
    names = validate_payload(payload)
    result = {
        'changed': payload != previous or license_data != old_license,
        'previous_revision': old['revision'], 'revision': revision,
        'added': sorted(names - old_names), 'removed': sorted(old_names - names),
        'changed_files': sorted(name for name in set(previous) | set(payload)
                                if previous.get(name) != payload.get(name)),
        'skill_count': len(names),
    }
    if result['changed']:
        replace_snapshot(destination, payload, license_data, revision)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Validate the snapshot without network access')
    parser.add_argument('--revision', help='Fetch a specific immutable upstream commit')
    args = parser.parse_args()
    manifest, _, _, names = check_vendor()
    if args.check:
        for skill in (ROOT / 'skills').glob('*/SKILL.md'):
            validate_payload({f'skills/{skill.parent.name}/SKILL.md': skill.read_bytes()})
        print(f'Valid: {len(names)} upstream skills, personal skill metadata and snapshot hashes')
        return
    revision = args.revision or latest_revision()
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('Expected a complete upstream commit SHA')
    if revision == manifest['revision']:
        print('Upstream revision is already current')
        return
    result = update(VENDOR, download_archive(revision), revision)
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
