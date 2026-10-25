"""Keep the apply error visible even when the daemon cannot roll back."""
from contextlib import redirect_stderr
import io
from pathlib import Path
import runpy
import unittest
from unittest.mock import Mock, patch

MODULE = runpy.run_path(str(Path(__file__).resolve().parents[2] /
                           'home/dot_local/bin/executable_hyprmoncfg-helper'))


class ScaleFailureTest(unittest.TestCase):
    def test_rollback_failure_preserves_commit_error(self):
        state = {
            'displays': [{'key': 'panel', 'focused': True}],
            'profile': {'outputs': [{'key': 'panel', 'scale': 1}]},
            'profiles': [{'name': 'desktop'}],
            'source_profile': 'desktop',
        }
        client = Mock()
        client.call.side_effect = [
            state, {'daemon': {}}, {'profile': {}}, state, {'id': 'preview'},
            RuntimeError('save failed'), RuntimeError('daemon disconnected'),
        ]
        with patch.dict(MODULE['change_scale'].__globals__, next_scale=lambda *_: 1.25):
            with self.assertRaisesRegex(RuntimeError, 'save failed'):
                MODULE['change_scale'](client, 'up')
        client.call.assert_called_with('revert', transaction_id='preview')


class CommandParsingTest(unittest.TestCase):
    def test_scale_dispatch(self):
        for direction in ('up', 'down'):
            args = MODULE['parse_args'](['scale', direction])
            self.assertIs(args.handler, MODULE['change_scale'])
            self.assertEqual(args.direction, direction)

    def test_reject_invalid_commands_before_connecting(self):
        for arguments in ([], ['up'], ['scale'], ['scale', 'sideways'],
                          ['scale', 'up', 'extra']):
            with self.subTest(arguments=arguments), redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    MODULE['parse_args'](arguments)
                self.assertEqual(error.exception.code, 2)
