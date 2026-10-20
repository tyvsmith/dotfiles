#!/usr/bin/env python3
"""Exercise the installed ScopeBuddy without starting a game or compositor."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_session import ROOT


@unittest.skipUnless(shutil.which('scb'), 'ScopeBuddy is not installed')
class ScopeBuddyTest(unittest.TestCase):
    def run_game(self, mode='native', stream=False, fail_start=False, exit_code=0, hyprland=True):
        with tempfile.TemporaryDirectory(prefix='scopebuddy-hooks-') as temporary:
            root=Path(temporary)
            config=root/'.config/scopebuddy'
            shutil.copytree(ROOT/'home/dot_config/scopebuddy',config)
            (config/'AppID/1234.conf').write_text('mode '+mode+'\n')
            binary=root/'bin';binary.mkdir()
            (binary/'hypr-display-session').write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
if sys.argv[1]=='stream-info':
 print('1920 1080 60' if os.environ['STREAM']=='1' else '0 0 0')
else:
 with Path(os.environ['EVENT_LOG']).open('a') as f:f.write(sys.argv[1]+'\\n')
 if sys.argv[1]=='game-start' and os.environ['FAIL_START']=='1':sys.exit(1)
''')
            for name in ['game-performance','gamemoderun']:
                (binary/name).write_text('#!/bin/sh\nexec "$@"\n')
            (binary/'gamescope').write_text('''#!/bin/bash
printf 'gamescope %s\\n' "$*" >> "$EVENT_LOG"
while [[ $1 != -- ]]; do shift; done
shift
exec "$@"
''')
            (binary/'fake-game').write_text('''#!/bin/sh
printf 'game %s %s\\n' "$HYPR_WORKSPACE" "$MANGOHUD_CONFIG" >> "$EVENT_LOG"
exit "$GAME_EXIT"
''')
            for p in binary.iterdir():p.chmod(0o755)
            log=root/'events'
            env=os.environ|dict(HOME=str(root),XDG_CONFIG_HOME=str(root/'.config'),
                PATH=str(binary)+':/usr/bin:/bin',SCB_APPID='1234',
                STREAM=str(int(stream)),FAIL_START=str(int(fail_start)),GAME_EXIT=str(exit_code),
                EVENT_LOG=str(log),LD_PRELOAD='',SCB_NESTEDFIX='0',
                HYPRLAND_INSTANCE_SIGNATURE='test' if hyprland else '')
            result=subprocess.run([shutil.which('scb'),'--',str(binary/'fake-game')],
                env=env,capture_output=True,text=True,timeout=10)
            return result,log.read_text().splitlines() if log.exists() else []

    def test_native_hooks_wrap_game_and_preserve_exit_status(self):
        result,events=self.run_game(exit_code=7)
        self.assertEqual(result.returncode,7,result.stdout+result.stderr)
        self.assertEqual(events,['game-start','game 6 preset=2,fps_limit=161','game-stop'])

    def test_gamescope_hook_precedes_compositor(self):
        result,events=self.run_game(mode='gamescope')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(events[0],'game-start')
        self.assertTrue(events[1].startswith('gamescope '))
        self.assertEqual(events[-1],'game-stop')

    def test_stream_dimensions_and_frame_cap_reach_gamescope(self):
        result,events=self.run_game(mode='gamescope',stream=True)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('-w 1920 -h 1080 -W 1920 -H 1080 -r 60',events[1])
        self.assertIn('game 6 no_display,fps_limit=60',events)

    def test_other_desktops_launch_without_display_hooks(self):
        for mode in ['native','gamescope']:
            with self.subTest(mode=mode):
                result,events=self.run_game(mode=mode,hyprland=False)
                self.assertEqual(result.returncode,0,result.stdout+result.stderr)
                self.assertTrue(any(x.startswith('game 6 ') for x in events))
                self.assertNotIn('game-start',events)
                self.assertNotIn('game-stop',events)

    def test_failed_display_start_prevents_both_launch_paths(self):
        for mode in ['native','gamescope']:
            with self.subTest(mode=mode):
                result,events=self.run_game(mode=mode,fail_start=True)
                self.assertNotEqual(result.returncode,0)
                self.assertEqual(events,['game-start','game-stop'])


if __name__=='__main__':unittest.main()
