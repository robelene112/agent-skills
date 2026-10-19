#!/usr/bin/env python3
"""Invoke classic Outlook on demand without shell evaluation or mailbox files."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def stage_windows_script(powershell, source, digest):
    """Install the WSL source as a Windows-local helper, keeping file metadata."""
    request = base64.b64encode(json.dumps({'source': source, 'sha256': digest}).encode()).decode('ascii')
    # Only installer operations run as commands. The mail helper itself always
    # runs with -File, under the user's existing execution policy.
    command = r'''
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
try {
    $request = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__REQUEST__')) | ConvertFrom-Json
    $local = [Environment]::GetFolderPath('LocalApplicationData')
    if ($local -notmatch '^[A-Za-z]:\\') { throw 'LocalApplicationData must be on a local Windows drive.' }
    if ((Get-FileHash -LiteralPath $request.source -Algorithm SHA256).Hash -ne $request.sha256) {
        throw 'The source helper changed during installation. Run the wrapper again.'
    }
    $root = Join-Path $local ('agent-skills\outlook-local\' + $request.sha256)
    [void][IO.Directory]::CreateDirectory($root)
    $target = Join-Path $root 'outlook-local.ps1'
    if (-not [IO.File]::Exists($target)) {
        $temporary = Join-Path $root ([Guid]::NewGuid().ToString() + '.ps1')
        try {
            # Windows file copy retains alternate streams, including an existing
            # Zone.Identifier. Do not strip download markers or unblock files.
            [IO.File]::Copy($request.source, $temporary, $false)
            if ((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash -ne $request.sha256) {
                throw 'The copied helper does not match its source.'
            }
            try { [IO.File]::Move($temporary, $target) }
            catch { if (-not [IO.File]::Exists($target)) { throw } }
        } finally {
            if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
        }
    }
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $request.sha256) {
        throw 'The installed helper was modified. Inspect the local application cache.'
    }
    @{ok = $true; script = $target} | ConvertTo-Json -Compress
} catch {
    @{ok = $false; error = $_.Exception.Message} | ConvertTo-Json -Compress
    exit 2
}
'''.replace('__REQUEST__', request)
    result = subprocess.run(
        [powershell, '-NoLogo', '-NoProfile', '-NonInteractive', '-Command', command],
        capture_output=True, timeout=15,
    )
    try:
        data = json.loads(result.stdout.decode('utf-8-sig'))
        if result.returncode or data.get('ok') is not True:
            raise RuntimeError(data.get('error', 'Windows helper installation failed.'))
        target = data['script']
        if not isinstance(target, str) or len(target) < 4 or target[1:3] != ':\\':
            raise ValueError('Expected a local Windows helper path')
        return target
    except (ValueError, KeyError, TypeError, AttributeError, UnicodeError) as exc:
        detail = result.stderr.decode('utf-8-sig', errors='replace').strip()
        raise RuntimeError('Windows helper installation did not return a valid local path. ' + detail) from exc


def invocation(action, options):
    script = Path(__file__).resolve().with_suffix('.ps1')
    powershell = shutil.which('powershell.exe')
    if os.name == 'nt':
        windows_script = str(script)
    else:
        if 'microsoft' not in Path('/proc/sys/kernel/osrelease').read_text().lower():
            raise RuntimeError('Run this helper on Windows or its WSL environment, not the VPS.')
        powershell = powershell or '/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
        windows_script = subprocess.run(
            ['wslpath', '-w', str(script)], check=True, capture_output=True, text=True, timeout=5,
        ).stdout.strip()
    if not powershell or not Path(powershell).is_file():
        raise RuntimeError('Windows PowerShell was not found in this environment.')
    if os.name != 'nt':
        windows_script = stage_windows_script(powershell, windows_script, hashlib.sha256(script.read_bytes()).hexdigest())
    encoded = base64.b64encode(json.dumps(options, ensure_ascii=True).encode('utf-8')).decode('ascii')
    return [powershell, '-NoLogo', '-NoProfile', '-NonInteractive', '-File', windows_script,
            '-Action', action, '-QueryBase64', encoded]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='action', required=True)
    for action in ('probe', 'search', 'read'):
        command = commands.add_parser(action)
        command.add_argument('--timeout', type=int, default=40, help='Client timeout in seconds (5-180).')
        if action in ('probe', 'search'):
            command.add_argument('--max-folders', type=int, default=2000)
        if action == 'search':
            command.add_argument('--unread-only', action='store_true')
            for flag in ('subject', 'sender', 'participant', 'body', 'received-after', 'received-before', 'store-id', 'folder-contains'):
                command.add_argument('--' + flag)
            command.add_argument('--max-candidates', type=int, default=2000)
            command.add_argument('--limit', type=int, default=50)
            command.add_argument('--offset', type=int, default=0)
        if action == 'read':
            command.add_argument('--entry-id', required=True)
            command.add_argument('--store-id', required=True)
            command.add_argument('--body-chars', type=int, default=8000, help='0 returns the full body.')
            command.add_argument('--html', action='store_true')
    args = vars(parser.parse_args())
    action, timeout = args.pop('action'), args.pop('timeout')
    if not 5 <= timeout <= 180:
        parser.error('--timeout must be between 5 and 180')
    options = {key: value for key, value in args.items() if value is not None}
    options['budget_seconds'] = min(120, timeout - 5)
    try:
        result = subprocess.run(invocation(action, options), capture_output=True, timeout=timeout)
        try:
            output = result.stdout.decode('utf-8-sig').strip()
            data = json.loads(output)
            if not isinstance(data, dict) or not isinstance(data.get('ok'), bool):
                raise ValueError('Expected an object with a boolean ok field')
        except (ValueError, UnicodeError):
            detail = result.stderr.decode('utf-8-sig', errors='replace').strip()
            raise RuntimeError('PowerShell did not return JSON. Check script execution policy and the active Outlook session. ' + detail)
        print(json.dumps(data, ensure_ascii=False))
        return result.returncode or (0 if data.get('ok') else 2)
    except subprocess.TimeoutExpired:
        error = 'Outlook helper timed out. The operation is incomplete and final unread state was not verified. Do not terminate Outlook.'
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        error = str(exc)
    print(json.dumps({'ok': False, 'error': error, 'unread_state_verified': False}, ensure_ascii=False))
    return 2


if __name__ == '__main__':
    sys.exit(main())
