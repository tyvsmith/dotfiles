"""Exercise the hook with isolated audio devices and host state."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'home/dot_local/bin/executable_punktfunk-restore-audio'


class RestoreAudioTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.state = self.root / 'punktfunk'
        self.state.mkdir()
        self.devices = self.root / 'devices.json'
        self.devices.write_text(json.dumps({'sink': 'punktfunk-speaker-1', 'source': 'punktfunk-mic'}))
        self.snapshot = self.state / 'audio-before-connect.json'
        self.snapshot.write_text(json.dumps({'fingerprint': 'tablet', 'event_ms': 1000,
                                             'sink': 'desktop-speakers', 'source': 'desktop-mic'}))
        fake = self.root / 'fake'
        fake.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
p = pathlib.Path(os.environ['DEVICES'])
a = sys.argv[1:]
if pathlib.Path(sys.argv[0]).name == 'punktfunk-host':
    counter = p.with_suffix('.calls')
    n = int(counter.read_text()) if counter.exists() else 0
    counter.write_text(str(n + 1))
    counts = os.environ.get('SESSIONS', '1').split(',')
    count = int(counts[min(n, len(counts)-1)])
    ids = os.environ.get('SESSION_IDS', '4').split(',')
    clients = os.environ.get('CLIENTS', 'tablet').split(',')
    rows = [{'id': int(ids[min(n, len(ids)-1)]), 'client': clients[min(n, len(clients)-1)]}] if count else []
    print(json.dumps({'v': 1, 'data': {'active_sessions': count, 'sessions': rows}}))
else:
    d = json.loads(p.read_text())
    if a[0].startswith('get-default-'):
        print(d[a[0].removeprefix('get-default-')])
    elif a[:2] == ['-f', 'json']:
        kind = a[3].removesuffix('s')
        print(json.dumps([{'name': 'desktop-speakers' if kind == 'sink' else 'desktop-mic'}]))
    elif a[0].startswith('set-default-'):
        d[a[0].removeprefix('set-default-')] = a[1]
        p.write_text(json.dumps(d))
    else:
        sys.exit(2)
''')
        fake.chmod(0o755)
        for name in ['pactl', 'punktfunk-host']:
            (self.root / name).symlink_to(fake)
        self.env = dict(os.environ, PATH=f'{self.root}:' + os.environ['PATH'],
                        XDG_STATE_HOME=str(self.root), XDG_RUNTIME_DIR=str(self.root),
                        DEVICES=str(self.devices), PF_EVENT_KIND='stream.started',
                        PF_EVENT_STREAM_FINGERPRINT='tablet', PF_EVENT_TS_MS='1001')

    def run_hook(self):
        result = subprocess.run(['bash', str(SCRIPT)], env=self.env,
                                capture_output=True, text=True, timeout=12)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(self.devices.read_text())

    def test_restores_saved_devices(self):
        self.assertEqual(self.run_hook(), {'sink': 'desktop-speakers', 'source': 'desktop-mic'})

    def test_capture_then_restore(self):
        self.snapshot.unlink()
        self.devices.write_text(json.dumps({'sink': 'desktop-speakers', 'source': 'desktop-mic'}))
        env = dict(self.env, PF_EVENT_KIND='client.connected',
                   PF_EVENT_CLIENT_FINGERPRINT='tablet', PF_EVENT_TS_MS='1000')
        result = subprocess.run(['bash', str(SCRIPT)], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.snapshot.exists(), 'connection hook must save the effective devices')
        self.devices.write_text(json.dumps({'sink': 'punktfunk-speaker-1', 'source': 'punktfunk-mic'}))
        self.assertEqual(self.run_hook(), {'sink': 'desktop-speakers', 'source': 'desktop-mic'})

    def test_late_capture_is_logged_without_restoring_remote_mic(self):
        snapshot = json.loads(self.snapshot.read_text())
        snapshot['source'] = 'punktfunk-mic'
        self.snapshot.write_text(json.dumps(snapshot))
        self.assertEqual(self.run_hook(), {'sink': 'desktop-speakers', 'source': 'punktfunk-mic'})
        self.assertIn('takeover preceded capture', (self.state / 'audio-hook.log').read_text())

    def capture_after_mic_claim(self, saved_source, modified=1):
        previous = self.state / 'default-audio-source.json'
        previous.write_text(json.dumps({'name': saved_source}))
        os.utime(previous, (modified, modified))
        env = dict(self.env, PF_EVENT_KIND='client.connected',
                   PF_EVENT_CLIENT_FINGERPRINT='tablet', PF_EVENT_TS_MS='2000')
        result = subprocess.run(['bash', str(SCRIPT)], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.env['PF_EVENT_TS_MS'] = '2001'

    def test_late_capture_recovers_available_preclaim_mic(self):
        self.capture_after_mic_claim('desktop-mic')
        self.assertEqual(self.run_hook()['source'], 'desktop-mic')

    def test_late_capture_rejects_unavailable_preclaim_mic(self):
        self.capture_after_mic_claim('unplugged-mic')
        self.assertEqual(self.run_hook()['source'], 'punktfunk-mic')

    def test_late_capture_rejects_stale_preclaim_mic(self):
        self.capture_after_mic_claim('desktop-mic', modified=-10)
        self.assertEqual(self.run_hook()['source'], 'punktfunk-mic')

    def test_late_capture_rejects_record_from_after_connection(self):
        self.capture_after_mic_claim('desktop-mic', modified=2.5)
        self.assertEqual(self.run_hook()['source'], 'punktfunk-mic')

    def test_stale_capture_is_not_used(self):
        self.env['PF_EVENT_TS_MS'] = '20000'
        self.assertEqual(self.run_hook()['sink'], 'punktfunk-speaker-1')

    def test_mismatched_session_is_untouched(self):
        self.env['PF_EVENT_STREAM_FINGERPRINT'] = 'gaming'
        self.assertEqual(self.run_hook()['source'], 'punktfunk-mic')

    def test_missing_event_fingerprint_is_untouched(self):
        self.env.pop('PF_EVENT_STREAM_FINGERPRINT')
        self.assertEqual(self.run_hook()['source'], 'punktfunk-mic')

    def test_overlapping_streams_are_untouched(self):
        self.env['SESSIONS'] = '2'
        self.assertEqual(self.run_hook()['sink'], 'punktfunk-speaker-1')

    def test_waits_for_session_registration(self):
        self.env['SESSIONS'] = '0,1'
        self.assertEqual(self.run_hook(), {'sink': 'desktop-speakers', 'source': 'desktop-mic'})

    def test_stream_joining_before_write_prevents_restore(self):
        self.env['SESSIONS'] = '1,2'
        self.assertEqual(self.run_hook(), {'sink': 'punktfunk-speaker-1', 'source': 'punktfunk-mic'})

    def test_replacement_gaming_session_is_untouched(self):
        self.env['CLIENTS'] = 'tablet,gaming'
        self.assertEqual(self.run_hook(), {'sink': 'punktfunk-speaker-1', 'source': 'punktfunk-mic'})

    def test_reconnected_session_is_not_changed_by_old_hook(self):
        self.env['SESSION_IDS'] = '4,5'
        self.assertEqual(self.run_hook(), {'sink': 'punktfunk-speaker-1', 'source': 'punktfunk-mic'})

    def test_manual_device_choice_is_preserved(self):
        self.devices.write_text(json.dumps({'sink': 'manual-speakers', 'source': 'manual-mic'}))
        self.assertEqual(self.run_hook(), {'sink': 'manual-speakers', 'source': 'manual-mic'})

    def test_missing_saved_device_is_not_selected(self):
        snapshot = json.loads(self.snapshot.read_text())
        snapshot['source'] = 'unplugged-mic'
        self.snapshot.write_text(json.dumps(snapshot))
        self.assertEqual(self.run_hook(), {'sink': 'desktop-speakers', 'source': 'punktfunk-mic'})

    def test_missing_snapshot_does_not_guess(self):
        self.snapshot.unlink()
        self.assertEqual(self.run_hook()['source'], 'punktfunk-mic')


if __name__ == '__main__':
    unittest.main()
