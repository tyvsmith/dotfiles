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


class ScalePresetTest(unittest.TestCase):
    def test_daemon_presets_step_clamp_and_handle_rounded_readback(self):
        output = {'width': 5120, 'height': 2160, 'scale': 1}
        client = Mock()
        client.call.return_value = {'presets': [1, 1.25, 1.6, 2, 3.2, 4]}
        for current, direction, expected in (
                (1, 'up', 1.25), (1.25, 'up', 1.6),
                (1.59999, 'down', 1.25), (1, 'down', 1), (4, 'up', 4)):
            with self.subTest(current=current, direction=direction):
                output['scale'] = current
                self.assertEqual(MODULE['next_scale'](client, direction, output), expected)
                client.call.assert_called_with('scale_info', width=5120, height=2160,
                                               scale=current)

    def test_no_presets_fails_without_apply(self):
        client = Mock()
        client.call.return_value = {'presets': []}
        with self.assertRaisesRegex(RuntimeError, 'no scale presets'):
            MODULE['next_scale'](client, 'up', {'width': 5120, 'height': 2160, 'scale': 1})
