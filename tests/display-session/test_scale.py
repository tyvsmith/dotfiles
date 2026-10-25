"""Keep the apply error visible even when the daemon cannot roll back."""
from pathlib import Path
import runpy
import unittest
from unittest.mock import Mock, patch

MODULE = runpy.run_path(str(Path(__file__).resolve().parents[2] /
                           'home/dot_local/bin/executable_hypr-monitor-scale'))


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
        with patch.dict(MODULE['change'].__globals__, next_scale=lambda *_: 1.25):
            with self.assertRaisesRegex(RuntimeError, 'save failed'):
                MODULE['change'](client, 'up')
        client.call.assert_called_with('revert', transaction_id='preview')
