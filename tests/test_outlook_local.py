"""Exercise transport and failure behavior without Windows or real mail."""

import base64
from contextlib import redirect_stdout
import importlib.util
import io
import json
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
import uuid
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1] / 'skills/outlook-local/scripts/outlook-local.py'
SPEC = importlib.util.spec_from_file_location('outlook_local_helper', SOURCE)
HELPER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(HELPER)


class OutlookTransportTests(unittest.TestCase):
    def invoke(self, argv, result=None, failure=None):
        output = io.StringIO()
        with patch.object(sys, 'argv', ['outlook-local.py'] + argv), \
                patch.object(HELPER, 'invocation', return_value=['fake-powershell']), \
                patch.object(HELPER.subprocess, 'run', return_value=result, side_effect=failure) as run, \
                redirect_stdout(output):
            code = HELPER.main()
        return code, json.loads(output.getvalue()), run

    def test_query_is_data_not_powershell_source(self):
        query = {'subject': "O'Brien \"caf\u00e9\"", 'body': '\U0001f600'}
        with patch.object(HELPER, 'os', SimpleNamespace(name='nt')), \
                patch.object(HELPER.shutil, 'which', return_value=sys.executable):
            args = HELPER.invocation('search', query)
        self.assertEqual(json.loads(base64.b64decode(args[-1])), query)
        self.assertNotIn('-Command', args)
        self.assertNotIn('-ExecutionPolicy', args)
        self.assertEqual(args[args.index('-Action') + 1], 'search')

    def test_wsl_executes_verified_windows_local_copy_instead_of_unc_source(self):
        local = r'C:\Users\Fixture\AppData\Local\agent-skills\outlook-local\digest\outlook-local.ps1'
        unc = r'\\wsl.localhost\Fixture\home\user\outlook-local.ps1'
        with patch.object(HELPER, 'os', SimpleNamespace(name='posix')), \
                patch.object(HELPER.shutil, 'which', return_value=sys.executable), \
                patch.object(Path, 'read_text', return_value='microsoft-standard-WSL2'), \
                patch.object(HELPER.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, unc + '\n', '')), \
                patch.object(HELPER, 'stage_windows_script', return_value=local) as install:
            args = HELPER.invocation('probe', {})
        self.assertEqual(args[args.index('-File') + 1], local)
        self.assertNotIn(unc, args)
        install.assert_called_once_with(sys.executable, unc, hashlib.sha256(SOURCE.with_suffix('.ps1').read_bytes()).hexdigest())
        self.assertNotIn('-ExecutionPolicy', args)

    def test_installer_treats_source_path_as_data_and_does_not_override_policy(self):
        source = "\\\\wsl.localhost\\Fixture\\O'Brien $(throw 'do not run').ps1"
        local = r'C:\Users\Fixture\AppData\Local\agent-skills\outlook-local\digest\outlook-local.ps1'
        result = subprocess.CompletedProcess([], 0, json.dumps({'ok': True, 'script': local}).encode(), b'')
        with patch.object(HELPER.subprocess, 'run', return_value=result) as run:
            self.assertEqual(HELPER.stage_windows_script('powershell.exe', source, 'a' * 64), local)
        args = run.call_args.args[0]
        self.assertNotIn('-ExecutionPolicy', args)
        command = args[-1]
        self.assertNotIn(source, command)
        encoded = command.split("FromBase64String('", 1)[1].split("')", 1)[0]
        self.assertEqual(json.loads(base64.b64decode(encoded)), {'source': source, 'sha256': 'a' * 64})

    def test_failed_installation_never_retries_or_accepts_an_unc_target(self):
        for payload in ({'ok': False, 'error': 'Source hash mismatch'},
                        {'ok': True, 'script': r'\\wsl.localhost\Fixture\helper.ps1'}, []):
            result = subprocess.CompletedProcess([], 0, json.dumps(payload).encode(), b'')
            with self.subTest(payload=payload), patch.object(HELPER.subprocess, 'run', return_value=result) as run:
                with self.assertRaises(RuntimeError):
                    HELPER.stage_windows_script('powershell.exe', r'\\source\helper.ps1', 'a' * 64)
                self.assertEqual(run.call_count, 1)

    def test_broad_scope_and_partial_coverage_are_preserved(self):
        payload = {'ok': True, 'search_complete_in_outlook_data': False,
                   'issues': [{'code': 'candidate_limit'}], 'messages': []}
        result = subprocess.CompletedProcess([], 0, json.dumps(payload).encode(), b'')
        with patch.object(sys, 'argv', ['outlook-local.py', 'search']), \
                patch.object(HELPER, 'invocation', return_value=['fake']) as build, \
                patch.object(HELPER.subprocess, 'run', return_value=result), \
                redirect_stdout(io.StringIO()) as output:
            self.assertEqual(HELPER.main(), 0)
        self.assertEqual(json.loads(output.getvalue()), payload)
        options = build.call_args.args[1]
        self.assertNotIn('store_id', options)
        self.assertNotIn('folder_contains', options)

    def test_participant_search_passes_contact_text_without_adding_recency_or_unread_filters(self):
        participant = "O'Brien $(not executable)"
        result = subprocess.CompletedProcess([], 0, b'{"ok":true,"messages":[]}', b'')
        with patch.object(sys, 'argv', ['outlook-local.py', 'search', '--participant', participant]), \
                patch.object(HELPER, 'invocation', return_value=['fake']) as build, \
                patch.object(HELPER.subprocess, 'run', return_value=result), redirect_stdout(io.StringIO()):
            self.assertEqual(HELPER.main(), 0)
        options = build.call_args.args[1]
        self.assertEqual(options['participant'], participant)
        self.assertNotIn('received_after', options)
        self.assertFalse(options['unread_only'])

    def test_timeout_never_claims_verified_unread_state(self):
        code, data, _ = self.invoke(['probe'], failure=subprocess.TimeoutExpired('fake', 40))
        self.assertEqual(code, 2)
        self.assertFalse(data['ok'])
        self.assertFalse(data['unread_state_verified'])

    def test_policy_failure_is_reported_without_retry(self):
        result = subprocess.CompletedProcess([], 1, b'', b'Script execution is disabled.')
        code, data, run = self.invoke(['probe'], result=result)
        self.assertEqual(code, 2)
        self.assertIn('Script execution is disabled', data['error'])
        self.assertEqual(run.call_count, 1)

    def test_utf8_bom_and_unicode_survive_transport(self):
        payload = {'ok': True, 'message': {'body': {'text': 'caf\u00e9 \U0001f600', 'truncated': False}}}
        result = subprocess.CompletedProcess([], 0, ('\ufeff' + json.dumps(payload, ensure_ascii=False)).encode(), b'')
        code, data, _ = self.invoke(['read', '--store-id', 'synthetic-store', '--entry-id', 'synthetic-id'], result=result)
        self.assertEqual(code, 0)
        self.assertEqual(data, payload)

    def test_malformed_or_unexpected_output_becomes_a_structured_failure(self):
        for output in (b'\xff', b'[]', b'"unexpected"', b'{"message": "missing status"}'):
            with self.subTest(output=output):
                result = subprocess.CompletedProcess([], 0, output, b'')
                code, data, run = self.invoke(['probe'], result=result)
                self.assertEqual(code, 2)
                self.assertFalse(data['ok'])
                self.assertEqual(run.call_count, 1)


@unittest.skipUnless(sys.platform == 'win32', 'Requires Windows PowerShell and the Windows filesystem')
class WindowsInstallationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="outlook-\u00e9-'fixture-")
        self.addCleanup(self.temporary.cleanup)
        self.source = Path(self.temporary.name) / 'helper.ps1'
        self.source.write_text(
            'param([string]$Action, [string]$QueryBase64)\n'
            f'# Unique fixture {uuid.uuid4()}\n'
            '[Console]::OutputEncoding = [Text.Encoding]::UTF8\n'
            '$query = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($QueryBase64)) | ConvertFrom-Json\n'
            '@{ok = $true; action = $Action; query = $query} | ConvertTo-Json -Compress\n', encoding='ascii',
        )
        self.digest = hashlib.sha256(self.source.read_bytes()).hexdigest()
        self.powershell = shutil.which('powershell.exe')

    def install(self):
        cached = Path(HELPER.stage_windows_script(self.powershell, str(self.source), self.digest))
        self.addCleanup(shutil.rmtree, cached.parent)
        return cached

    def test_installed_copy_executes_under_remotesigned_and_is_reused(self):
        cached = self.install()
        self.assertEqual(cached.read_bytes(), self.source.read_bytes())
        modified = cached.stat().st_mtime_ns
        self.assertEqual(Path(HELPER.stage_windows_script(self.powershell, str(self.source), self.digest)), cached)
        self.assertEqual(cached.stat().st_mtime_ns, modified)
        query = {'subject': "O'Brien caf\u00e9 \U0001f600"}
        encoded = base64.b64encode(json.dumps(query).encode()).decode()
        # A restrictive policy for this synthetic child process only. Production
        # invocations never override policy. No Outlook or actual mail is used.
        result = subprocess.run([self.powershell, '-NoProfile', '-NonInteractive',
                                 '-ExecutionPolicy', 'RemoteSigned', '-File', str(cached),
                                 '-Action', 'probe', '-QueryBase64', encoded], capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors='replace'))
        data = json.loads(result.stdout.decode('utf-8-sig'))
        self.assertEqual(data, {'ok': True, 'action': 'probe', 'query': query})

    def test_source_and_cached_modifications_are_rejected(self):
        cached = self.install()
        cached.write_text('Modified cache', encoding='ascii')
        with self.assertRaisesRegex(RuntimeError, 'installed helper was modified'):
            HELPER.stage_windows_script(self.powershell, str(self.source), self.digest)
        self.source.write_text('Source changed concurrently', encoding='ascii')
        with self.assertRaisesRegex(RuntimeError, 'source helper changed'):
            HELPER.stage_windows_script(self.powershell, str(self.source), self.digest)

    def test_download_marker_survives_install_and_signature_policy_still_blocks(self):
        marker = '[ZoneTransfer]\r\nZoneId=3\r\n'
        Path(str(self.source) + ':Zone.Identifier').write_text(marker, encoding='ascii')
        cached = self.install()
        self.assertEqual(Path(str(cached) + ':Zone.Identifier').read_bytes(),
                         Path(str(self.source) + ':Zone.Identifier').read_bytes())
        result = subprocess.run([self.powershell, '-NoProfile', '-NonInteractive',
                                 '-ExecutionPolicy', 'RemoteSigned', '-File', str(cached)],
                                capture_output=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'UnauthorizedAccess', result.stderr)


if __name__ == '__main__':
    unittest.main()
