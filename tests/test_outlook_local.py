"""Exercise transport and failure behavior without Windows or real mail."""

import base64
from contextlib import redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
from types import SimpleNamespace
import unittest
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


if __name__ == '__main__':
    unittest.main()
