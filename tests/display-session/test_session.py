#!/usr/bin/env python3
"""Check lifecycle markers and CLI selection without touching the desktop."""
import json
import shutil
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'home/dot_local/bin/executable_hypr-display-session'
MODES = ['5120x2160@165.06Hz', '3840x2160@59.94Hz', '1920x1080@60.00Hz']


class SessionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        binary = self.root/'bin'
        binary.mkdir()
        command = binary/'hyprmoncfg'
        command.write_text('''#!/bin/sh
if [ -f "$XDG_RUNTIME_DIR/fail" ]; then exit 1; fi
printf '%s\\n' "$*" >> "$XDG_RUNTIME_DIR/calls"
''')
        command.chmod(0o755)
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.bind(str(self.root/'hyprmoncfgd.sock'))
        self.addCleanup(self.sock.close)
        config = self.root/'config'
        (config/'hyprmoncfg').mkdir(parents=True)
        shutil.copy2(ROOT/'home/dot_config/hyprmoncfg/streaming.json',config/'hyprmoncfg/streaming.json')
        monitor = dict(name='DP-1',description='LG Electronics LG ULTRAGEAR+ 502NTPC9M944',availableModes=MODES)
        (self.root/'monitors.json').write_text(json.dumps([monitor]))
        (binary/'hyprctl').write_text('#!/bin/sh\ncat "$XDG_RUNTIME_DIR/monitors.json"\n')
        (binary/'hyprctl').chmod(0o755)
        self.env = os.environ | dict(XDG_CONFIG_HOME=str(config), XDG_RUNTIME_DIR=str(self.root),
            HYPRLAND_INSTANCE_SIGNATURE='test', PATH=str(binary)+':/usr/bin:/bin')

    def run_command(self, *args, ok=True, instance='test'):
        result = subprocess.run(['bash', str(SCRIPT), *args], capture_output=True,
            text=True, env=self.env|dict(HYPRLAND_INSTANCE_SIGNATURE=instance), timeout=10)
        if ok:
            self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def applied(self):
        path = self.root/'calls'
        return [line.split()[1] for line in path.read_text().splitlines()] if path.exists() else []

    def test_non_steam_game_identifiers(self):
        for identifier in ['ubisoft/123','heroic/a-game','null']:
            with self.subTest(identifier=identifier):
                self.run_command('game-start','--game',identifier)
                self.assertEqual(self.run_command('status').stdout.strip(),'gaming')
                self.run_command('game-stop','--game',identifier)
                self.assertEqual(self.run_command('status').stdout.strip(),'desktop')

    def test_stream_game_exit_stream_exit(self):
        self.run_command('stream-start','--width','3840','--height','2160','--fps','60')
        self.run_command('game-start','--game','553850')
        self.run_command('game-stop','--game','553850')
        self.run_command('stream-stop')
        self.assertEqual(self.applied(), ['streaming','desktop'])

    def test_stream_ends_then_phone_reconnects_while_game_runs(self):
        self.run_command('stream-start','--width','3840','--height','2160','--fps','60')
        self.run_command('game-start','--game','3010850')
        self.run_command('stream-stop')
        self.run_command('stream-start','--width','1920','--height','1080','--fps','60')
        self.run_command('game-stop','--game','3010850')
        self.run_command('stream-stop')
        self.assertEqual(self.applied(), ['streaming','gaming','streaming','desktop'])

    def test_new_compositor_reset_ignores_old_activity(self):
        self.run_command('game-start','--game','553850')
        self.run_command('stream-start','--width','1920','--height','1080','--fps','60')
        self.run_command('reset',instance='new')
        self.assertEqual(self.applied()[-1], 'desktop')
        self.assertEqual(self.run_command('stream-info',instance='new').stdout.strip(), '0 0 0')

    def test_duplicate_start_and_unrelated_stop_do_not_reapply(self):
        self.run_command('game-start','--game','553850')
        self.run_command('game-start','--game','553850')
        self.run_command('game-stop','--game','3010850')
        self.assertEqual(self.applied(), ['gaming'])

    def test_unsupported_stream_mode_leaves_game_active(self):
        self.run_command('game-start','--game','553850')
        result=self.run_command('stream-start','--width','3840','--height','2160','--fps','120',ok=False)
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(self.applied(), ['gaming'])
        self.run_command('game-stop','--game','553850')
        self.assertEqual(self.applied()[-1], 'desktop')

    def test_sunshine_environment_and_fractional_refresh(self):
        self.env.update(SUNSHINE_CLIENT_WIDTH='3840',SUNSHINE_CLIENT_HEIGHT='2160',SUNSHINE_CLIENT_FPS='60')
        self.run_command('stream-start')
        profile=json.loads((self.root/'hypr-display-session-test/profiles/streaming.json').read_text())
        self.assertEqual(profile['outputs'][0]['mode'],'3840x2160@59.94Hz')
        self.assertEqual(self.run_command('stream-info').stdout.strip(),'3840 2160 60')

    def test_arbitrary_advertised_resolution_and_active_stream_change(self):
        monitors=json.loads((self.root/'monitors.json').read_text())
        monitors[0]['availableModes'].append('2560x1440@120.00Hz')
        (self.root/'monitors.json').write_text(json.dumps(monitors))
        self.run_command('stream-start','--width','1920','--height','1080','--fps','60')
        self.run_command('stream-start','--width','2560','--height','1440','--fps','120')
        self.assertEqual(self.applied(),['streaming','streaming'])
        self.assertEqual(self.run_command('stream-info').stdout.strip(),'2560 1440 120')

    def test_failed_stream_change_preserves_previous_dimensions(self):
        self.run_command('stream-start','--width','1920','--height','1080','--fps','60')
        (self.root/'fail').touch()
        self.assertNotEqual(self.run_command('stream-start','--width','3840','--height','2160','--fps','60',ok=False).returncode,0)
        self.assertEqual(self.run_command('stream-info').stdout.strip(),'1920 1080 60')

    def test_missing_daemon_socket_does_not_apply_directly(self):
        (self.root/'hyprmoncfgd.sock').unlink()
        result=self.run_command('game-start','--game','553850',ok=False)
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(self.applied(),[])
        self.assertEqual(self.run_command('status').stdout.strip(),'desktop')

    def test_failed_start_restores_previous_markers(self):
        (self.root/'fail').touch()
        self.assertNotEqual(self.run_command('game-start','--game','553850',ok=False).returncode,0)
        (self.root/'fail').unlink()
        self.run_command('game-start','--game','3010850')
        self.assertEqual(self.applied(), ['gaming'])

    def test_stop_records_cleanup_even_when_apply_fails(self):
        self.run_command('game-start','--game','553850')
        (self.root/'fail').touch()
        self.assertNotEqual(self.run_command('game-stop','--game','553850',ok=False).returncode,0)
        (self.root/'fail').unlink()
        self.run_command('reset')
        self.assertEqual(self.applied()[-1], 'desktop')


if __name__ == '__main__':
    unittest.main()
