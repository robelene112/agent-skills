#!/usr/bin/env python3
"""Invoke classic Outlook on demand without shell evaluation or mailbox files."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import queue
import shutil
import subprocess
import sys
import threading
import time
from collections import deque


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


def session(timeout):
    """Relay JSON lines to one foreground helper; retain mail only in its memory."""
    started = time.monotonic()
    process = subprocess.Popen(invocation('session', {}), stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, text=True, encoding='utf-8', bufsize=1)
    lines = queue.Queue()
    errors = deque(maxlen=16)

    def read_output():
        try:
            for line in process.stdout:
                lines.put(line)
        finally:
            lines.put(None)

    def read_errors():
        for line in process.stderr:
            errors.append(line[-1000:])

    readers = [threading.Thread(target=read_output, daemon=True), threading.Thread(target=read_errors, daemon=True)]
    for reader in readers:
        reader.start()

    def receive(seconds):
        try:
            line = lines.get(timeout=seconds)
        except queue.Empty:
            raise subprocess.TimeoutExpired('Outlook session helper', seconds) from None
        if line is None:
            readers[1].join(timeout=1)
            raise RuntimeError('Outlook session ended without JSON. ' + ''.join(errors).strip())
        data = json.loads(line.lstrip('\ufeff'))
        if not isinstance(data, dict) or not isinstance(data.get('ok'), bool):
            raise RuntimeError('Outlook session returned an invalid response.')
        return data

    try:
        ready = receive(timeout)
        if not ready.get('ok'):
            print(json.dumps(ready, ensure_ascii=False), flush=True)
            return 2
        if ready.get('ready') is not True:
            raise RuntimeError('Outlook helper did not confirm session startup.')
        ready['startup_ms'] = round((time.monotonic() - started) * 1000, 1)
        print(json.dumps(ready, ensure_ascii=False), flush=True)
        for line in sys.stdin:
            try:
                request = json.loads(line)
                if not isinstance(request, dict) or request.get('action') not in ('probe', 'search', 'read', 'refresh', 'close'):
                    raise ValueError('Expected action probe, search, read, refresh or close.')
                if set(request) - {'action', 'options', 'timeout'}:
                    raise ValueError('Unexpected request fields.')
                seconds = request.pop('timeout', timeout)
                if isinstance(seconds, bool) or not isinstance(seconds, int) or not 5 <= seconds <= 180:
                    raise ValueError('timeout must be an integer between 5 and 180.')
                options = request.setdefault('options', {})
                if not isinstance(options, dict):
                    raise ValueError('options must be an object.')
                options['budget_seconds'] = min(120, seconds - 5)
            except (ValueError, TypeError) as exc:
                print(json.dumps({'ok': False, 'error': str(exc)}), flush=True)
                continue
            # Escaped JSON keeps Unicode data intact across console code pages.
            process.stdin.write(json.dumps(request, ensure_ascii=True) + '\n')
            process.stdin.flush()
            data = receive(seconds)
            print(json.dumps(data, ensure_ascii=False), flush=True)
            if not data['ok'] or request['action'] == 'close':
                return 0 if data['ok'] else 2
        return 0
    finally:
        # Kill only this helper, never the user's Outlook. EOF/close occurs
        # between requests; a hard timeout still leaves unread state unverified.
        if process.poll() is None:
            process.stdin.close()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        for reader in readers:
            reader.join(timeout=1)
        for stream in (process.stdin, process.stdout, process.stderr):
            stream.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='action', required=True)
    for action in ('probe', 'search', 'read', 'session'):
        command = commands.add_parser(action)
        command.add_argument('--timeout', type=int, default=40, help='Client timeout in seconds (5-180).')
        if action in ('probe', 'search'):
            command.add_argument('--max-folders', type=int, default=2000)
        if action == 'search':
            command.add_argument('--term', dest='terms', action='append', help='Repeat for an OR-union of subject/body terms and contacts.')
            command.add_argument('--contact', dest='contacts', action='append', help='Repeat for contact names/addresses in the same union.')
            command.add_argument('--engine', choices=('table', 'scan'), default='table', help='scan is the reference route for comparison.')
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
        if action == 'session':
            return session(timeout)
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
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError) as exc:
        error = str(exc)
    print(json.dumps({'ok': False, 'error': error, 'unread_state_verified': False}, ensure_ascii=False))
    return 2


if __name__ == '__main__':
    sys.exit(main())
