#!/usr/bin/env python3
"""Exercise the installed ScopeBuddy without starting a game or compositor."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
GAMES = {
    '2825860': 'sinking-city-2',
    '3010850': 'gears-of-war-e-day',
    '3669870': 'control-resonant',
    '553850': 'helldivers-2',
    '3357650': 'pragmata',
    '3764200': 'resident-evil-requiem',
    '2947440': 'silent-hill-f',
}


@unittest.skipUnless(shutil.which('scb'), 'ScopeBuddy is not installed')
class ScopeBuddyTest(unittest.TestCase):
    def run_game(self, mode='native', fail_start=False, exit_code=0, hyprland=True, punktfunk="idle", never_hdr=False, fullscreen=True, session=None, background_gamemode=False, desktop=None, app_config='', hdr_env='1', local_mode=(5120,2160,165), session_metadata=True, inherited_env=None, appid='3669870', game_filename=None):
        with tempfile.TemporaryDirectory(prefix='scopebuddy-hooks-') as temporary:
            root=Path(temporary)
            config=root/'.config/scopebuddy'
            shutil.copytree(ROOT/'home/dot_config/scopebuddy',config)
            # Render the chezmoi relative symlink in the isolated live layout.
            link = config/'symlink_gamemode.conf'
            (config/'gamemode.conf').symlink_to(link.read_text().strip())
            link.unlink()
            for preference in ['local', 'streaming']:
                with (config/(preference+'.conf')).open('a') as f:
                    f.write('\nexport TEST_PREFERENCE='+preference+'\n')
            (config/'games/000-unrelated.conf').write_text('APP_ID=unrelated\nexit 88\n')
            if mode is not None:
                (config/'games').mkdir(exist_ok=True)
                filename=game_filename or f'{GAMES[appid]}.conf'
                (config/'games'/filename).write_text(f'# Per-game settings\nAPP_ID={appid}\n' +
                    ('mode='+mode+'\n' if mode else '') +
                    ('' if fullscreen else 'export HYPR_FULLSCREEN=0\n') + app_config)
            binary=root/'bin';binary.mkdir()
            runtime=root/'run';runtime.mkdir()
            if session and session != 'missing-relay':
                # A different session's relay must not classify a local launch as streamed.
                relay = 'punktfunk-gamescope-test-ei' if session == 'isolated' else 'punktfunk-gamescope-ei'
                (runtime/relay).write_text('gamescope-test-ei' if session != 'local' else 'gamescope-other-ei')
            (binary/'ps').write_text('#!/bin/sh\n' +
                ('echo "123 steam.sh -gamepadui -steampal"\n' if background_gamemode else 'exit 0\n'))
            xrandr_mode=(1920,1080,59.94) if session else local_mode
            (binary/'xrandr').write_text('#!/bin/sh\n' + (
                "printf 'XWAYLAND0 connected primary\\n   %sx%s %s*+\\n'\n" % xrandr_mode
                if session_metadata else 'exit 1\n'))
            (binary/'punktfunk-host').write_text("#!/usr/bin/env python3\n" +
                ("import os\nfrom pathlib import Path\nwith Path(os.environ['EVENT_LOG']).open('a') as f:f.write('unexpected punktfunk query\\n')\n" if session else '') +
                ("raise SystemExit(1)\n" if punktfunk == 'unavailable' else
                 "print(" + repr(json.dumps({'data': {'active_sessions': 0 if punktfunk == 'idle' else 1}})) + ")\n"))
            monitor=dict(name='PF-test', focused=punktfunk != 'local', disabled=False,
                width=2364,height=1080,refreshRate=120,x=-2364,y=140,scale=1,
                transform=0,colorManagementPreset='srgb' if punktfunk == 'sdr' else 'hdr',
                sdrBrightness=1,sdrSaturation=1,sdrMinLuminance=0.2,sdrMaxLuminance=203,
                vrr=False)
            (binary/'hyprctl').write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
if os.environ['SESSION_TEST']=='1':
 with Path(os.environ['EVENT_LOG']).open('a') as f:f.write('unexpected hyprctl query\\n')
 sys.exit(91)
if sys.argv[1]=='eval' and 'lg_hdr' in sys.argv[2]:
 with Path(os.environ['EVENT_LOG']).open('a') as f:f.write('hdr-on\\n' if 'true' in sys.argv[2] else 'hdr-off\\n')
 Path(os.environ['EVENT_LOG']+'.hdr').write_text('hdr' if 'true' in sys.argv[2] else 'srgb')
 print('error: rejected' if os.environ['FAIL_START']=='1' else 'ok')
elif sys.argv[1]=='eval':
 with Path(os.environ['EVENT_LOG']).open('a') as f:f.write('hdr '+sys.argv[2]+'\\n')
 sys.exit(91)
else:
 monitors=json.loads(os.environ['MONITORS'])
 state=Path(os.environ['EVENT_LOG']+'.hdr')
 for m in monitors:
  if m['name']=='DP-1' and state.exists() and os.environ['NEVER_HDR']=='0':m['colorManagementPreset']=state.read_text()
 print(json.dumps(monitors))
''')
            for name in ['game-performance','gamemoderun']:
                (binary/name).write_text('#!/bin/sh\nexec "$@"\n')
            (binary/'gamescope').write_text('''#!/bin/bash
printf 'gamescope %s\\n' "$*" >> "$EVENT_LOG"
[[ -z $TEST_OUTER_HUD || $MANGOHUD_CONFIG == "$TEST_OUTER_HUD" ]] || exit 84
while [[ $1 != -- ]]; do shift; done
shift
exec "$@"
''')
            (binary/'fake-game').write_text('''#!/bin/sh
printf 'game %s %s\\n' "$HYPR_WORKSPACE" "$MANGOHUD_CONFIG" >> "$EVENT_LOG"
test "${HYPR_FULLSCREEN:-}" = "$EXPECTED_FULLSCREEN" || exit 98
test "$TEST_PREFERENCE" = "$EXPECTED_PREFERENCE" || exit 92
if [ "$SESSION_TEST" = 1 ]; then
 test "$PROTON_ENABLE_WAYLAND" = "$EXPECTED_SESSION_WAYLAND" || exit 97
 test "${DXVK_HDR-unset}" = "$EXPECTED_HDR" || exit 89
 test "$VKD3D_CONFIG" = descriptor_heap || exit 96
 test "$PROTON_DLSS_UPGRADE" = 1 || exit 90
 test "$DISPLAY" = ':42' && test "$GAMESCOPE_WAYLAND_DISPLAY" = gamescope-test || exit 93
 test "$VK_ADD_IMPLICIT_LAYER_PATH" = /test/punktfunk-wsi || exit 83
 test "$PUNKTFUNK_GAMESCOPE_WSI:$DISABLE_GAMESCOPE_WSI:$ENABLE_GAMESCOPE_WSI" = 1:1:0 || exit 82
elif [ "$EXPECTED_BACKEND" = native ]; then
 test "${PROTON_ENABLE_WAYLAND-unset}" = "$EXPECTED_NATIVE_HDR" || exit 88
 test "${DXVK_HDR-unset}" = "$EXPECTED_NATIVE_HDR" || exit 87
else
 test -z "$PROTON_ENABLE_WAYLAND$DXVK_HDR" || exit 86
fi
if [ "$SESSION_TEST" = 1 ] || [ "$TEST_CHECK_ARGS" = 1 ]; then
 test "$1" = 'argument with spaces' || exit 95
 test "$2" = '--another-argument' && test "$#" = 2 || exit 94
fi
test "$MANGOHUD" = "${TEST_EXPECTED_MANGOHUD:-$EXPECTED_MANGOHUD}" || exit 85
exit "$GAME_EXIT"
''')
            for p in binary.iterdir():p.chmod(0o755)
            log=root/'events'
            env=os.environ|dict(HOME=str(root),XDG_CONFIG_HOME=str(root/'.config'),
                PATH=str(binary)+':/usr/bin:/bin',SCB_APPID=appid if mode is not None else '1234',EXPECTED_FULLSCREEN=('1' if fullscreen else '0') if not session else '',
                XDG_CURRENT_DESKTOP=desktop or ('gamescope' if session else 'Hyprland'),
                XDG_RUNTIME_DIR=str(runtime),GAMESCOPE_WAYLAND_DISPLAY='gamescope-test' if session else '',
                LIBEI_SOCKET='gamescope-test-ei' if session else '',DISPLAY=':42',
                VK_ADD_IMPLICIT_LAYER_PATH='/test/punktfunk-wsi',PUNKTFUNK_GAMESCOPE_WSI='1',
                DISABLE_GAMESCOPE_WSI='1',ENABLE_GAMESCOPE_WSI='0',
                EXPECTED_PREFERENCE=('local' if session in ('local', 'missing-relay') else 'streaming') if session else ('local' if punktfunk in ('idle', 'local', 'unavailable') else 'streaming'),
                HYPR_WORKSPACE='' if session else '9',HYPR_FULLSCREEN='' if session else '1',
                EXPECTED_SESSION_WAYLAND='',
                MANGOHUD='1',MANGOHUD_CONFIG='preset=2,fps_limit=17' if session else '',
                EXPECTED_HDR='unset' if hdr_env is None else hdr_env,
                EXPECTED_BACKEND=mode or 'gamescope',
                EXPECTED_NATIVE_HDR='1',EXPECTED_MANGOHUD='0' if session else '1',
                SESSION_TEST='1' if session else '0',
                NEVER_HDR=str(int(never_hdr)),FAIL_START=str(int(fail_start)),GAME_EXIT=str(exit_code),
                EVENT_LOG=str(log),LD_PRELOAD='',SCB_NESTEDFIX='0',
                MONITORS=json.dumps([monitor, dict(name="DP-1", focused=punktfunk in ("idle","local"), colorManagementPreset="srgb", width=local_mode[0],height=local_mode[1],refreshRate=local_mode[2],scale=1.5)]),
                HYPRLAND_INSTANCE_SIGNATURE='test' if hyprland else '')
            env.pop('PROTON_ENABLE_WAYLAND', None)
            if hdr_env is None or not session:
                env.pop('DXVK_HDR', None)
            else:
                env['DXVK_HDR']=hdr_env
            env.update(inherited_env or {})
            args=['argument with spaces', '--another-argument'] if mode is None else []
            result=subprocess.run([shutil.which('scb'),'--',str(binary/'fake-game'),*args],
                env=env,capture_output=True,text=True,timeout=10)
            return result,log.read_text().splitlines() if log.exists() else []

    def test_appid_declarations_load_named_game_files(self):
        for appid, name in GAMES.items():
            with self.subTest(appid=appid, name=name):
                result, events = self.run_game(appid=appid,
                    app_config=f"printf 'loaded {name}\\n' >> \"$EVENT_LOG\"\n")
                self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
                self.assertEqual(events, [f'loaded {name}', 'hdr-on',
                    'game 6 preset=2,fps_limit=161', 'hdr-off'])

    def test_new_game_needs_only_a_declared_id(self):
        result, events = self.run_game(appid='7654321', game_filename='my-new-game.conf',
            app_config="printf 'new-game-loaded\\n' >> \"$EVENT_LOG\"\n")
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(events, ['new-game-loaded', 'hdr-on',
            'game 6 preset=2,fps_limit=161', 'hdr-off'])

    def test_default_uses_gamescope_or_existing_session(self):
        for session in [None, 'local', 'streaming']:
            for target in ['local', 'hdr']:
                with self.subTest(session=session, target=target):
                    result, events = self.run_game(mode=None, session=session, punktfunk=target,
                        inherited_env=dict(VKD3D_CONFIG='descriptor_heap'))
                    self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
                    self.assertEqual(sum(e.startswith('game ') for e in events), 1)
                    self.assertEqual(sum(e.startswith('gamescope ') for e in events), int(not session))
                    self.assertEqual(events.count('hdr-on'), int(not session and target == 'local'))
                    self.assertEqual(events.count('hdr-off'), int(not session and target == 'local'))

    def test_game_config_without_mode_runs_once_then_uses_fallback(self):
        for session in [None, 'local', 'streaming']:
            with self.subTest(session=session):
                result, events = self.run_game(mode='', session=session, app_config='''
printf 'config-loaded\\n' >> "$EVENT_LOG"
[[ $mode == gamescope ]] || exit 99
fps_cap=60
export VKD3D_CONFIG=descriptor_heap
export TEST_CHECK_ARGS=1
command="$command 'argument with spaces' --another-argument"
''')
                self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
                expected = ['config-loaded', 'game  preset=2,fps_limit=17'] if session else [
                    'config-loaded', 'hdr-on', 'game 6 no_display,fps_limit=60', 'hdr-off']
                self.assertEqual([e for e in events if not e.startswith('gamescope ')], expected)
                self.assertEqual(sum(e.startswith('gamescope ') for e in events), int(not session))

    def test_mode_assignment_applies_only_after_the_game_config(self):
        result, events = self.run_game(app_config='''
[[ $command != *game-performance* ]] || exit 99
mode=gamescope
fps_cap=60
export TEST_CHECK_ARGS=1
command="$command 'argument with spaces' --another-argument"
export EXPECTED_BACKEND=gamescope
''')
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(events.count('hdr-on'), 1)
        self.assertEqual(sum(e.startswith('gamescope ') for e in events), 1)
        self.assertIn('game 6 no_display,fps_limit=60', events)
        self.assertEqual(events[-1], 'hdr-off')

    def test_gamescope_appid_never_gets_native_flags(self):
        result, events = self.run_game(mode='gamescope', app_config='''
[[ -z ${PROTON_ENABLE_WAYLAND:-}${DXVK_HDR:-} ]] || exit 99
''')
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertIn('game 6 no_display,fps_limit=161', events)

    def test_game_settings_survive_mode_defaults(self):
        args = '-w 1920 -h 1080 -W 1920 -H 1080 -r 60 -f --hdr-enabled --mangoapp'
        for mode in ['native', 'gamescope']:
            with self.subTest(mode=mode):
                result, events = self.run_game(mode=mode, app_config=f'''
fps_cap=60
export MANGOHUD_CONFIG=preset=3,fps_limit=60
export TEST_OUTER_HUD=preset=3,fps_limit=60
SCB_GAMESCOPE_ARGS="{args}"
''')
                self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
                if mode == 'gamescope':
                    self.assertIn(args, events[1])
                    self.assertNotIn('-w 5120', events[1])
                    self.assertIn('game 6 no_display,fps_limit=60', events)
                else:
                    self.assertIn('game 6 preset=3,fps_limit=60', events)

    def test_existing_gamescope_reuses_local_and_streaming_sessions(self):
        for session in ['local', 'streaming', 'isolated', 'missing-relay']:
            for mode in ['native', 'gamescope', 'session']:
                with self.subTest(session=session, mode=mode):
                    result, events = self.run_game(
                        session=session, mode=mode, punktfunk='hdr', exit_code=7,
                        app_config='export VKD3D_CONFIG=descriptor_heap\ncommand="$command \'argument with spaces\' --another-argument"\n')
                    self.assertEqual(result.returncode, 7, result.stdout+result.stderr)
                    self.assertEqual(events, ['game  preset=2,fps_limit=17'])

    def test_gamescope_socket_overrides_inherited_desktop_name(self):
        result, events = self.run_game(session='local', desktop='Hyprland',
            app_config='export VKD3D_CONFIG=descriptor_heap\ncommand="$command \'argument with spaces\' --another-argument"\n')
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(events, ['game  preset=2,fps_limit=17'])

    def test_session_preserves_hdr_and_sdr_environment(self):
        for hdr_env in ['1', '0', None]:
            with self.subTest(hdr_env=hdr_env):
                result, events = self.run_game(session='streaming', hdr_env=hdr_env,
                    app_config='export VKD3D_CONFIG=descriptor_heap\ncommand="$command \'argument with spaces\' --another-argument"\n')
                self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
                self.assertEqual(events, ['game  preset=2,fps_limit=17'])

    def test_background_steam_gamemode_does_not_redirect_local_launch(self):
        result, events = self.run_game(background_gamemode=True, punktfunk='local')
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(events, ['hdr-on', 'game 6 preset=2,fps_limit=161', 'hdr-off'])

    def test_session_preserves_explicit_caller_environment_and_hook(self):
        result, events = self.run_game(session='streaming',
            inherited_env=dict(HYPR_WORKSPACE='9', HYPR_FULLSCREEN='1',
                PROTON_ENABLE_WAYLAND='0', EXPECTED_SESSION_WAYLAND='0', EXPECTED_FULLSCREEN='1',
                SCB_POST_COMMAND='printf "outer-post\\n" >> "$EVENT_LOG"'),
            app_config='export VKD3D_CONFIG=descriptor_heap\ncommand="$command \'argument with spaces\' --another-argument"\n')
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(events, ['game 9 preset=2,fps_limit=17', 'outer-post'])

    def test_per_game_prehook_runs_before_both_launch_paths(self):
        for mode in ['native', 'gamescope']:
            with self.subTest(mode=mode):
                result, events = self.run_game(mode=mode, app_config=r'''
SCB_PRE_COMMAND='scb_display_start || exit 1; printf "custom-pre\n" >> "$EVENT_LOG"'
''')
                self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
                self.assertEqual(events[:2], ['hdr-on', 'custom-pre'])
                self.assertEqual(events.count('custom-pre'), 1)
                self.assertEqual(events[-1], 'hdr-off')

    def test_per_game_prehook_can_abort_both_launch_paths(self):
        for mode in ['native', 'gamescope']:
            with self.subTest(mode=mode):
                result, events = self.run_game(mode=mode, app_config="SCB_PRE_COMMAND='exit 42'\n")
                self.assertEqual(result.returncode, 42, result.stdout+result.stderr)
                self.assertEqual(events, [])

    def test_local_hooks_wrap_game_and_preserve_exit_status(self):
        result,events=self.run_game(exit_code=7)
        self.assertEqual(result.returncode,7,result.stdout+result.stderr)
        self.assertEqual(events,['hdr-on','game 6 preset=2,fps_limit=161','hdr-off'])

    def test_native_exports_allow_per_game_overrides(self):
        result, events = self.run_game(app_config='''
[[ -z ${PROTON_ENABLE_WAYLAND:-}${DXVK_HDR:-} ]] || exit 99
export PROTON_ENABLE_WAYLAND=0 DXVK_HDR=0 EXPECTED_NATIVE_HDR=0
export TEST_CHECK_ARGS=1
command="$command 'argument with spaces' --another-argument"
''')
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(events, ['hdr-on', 'game 6 preset=2,fps_limit=161', 'hdr-off'])

    def test_native_unset_uses_defaults(self):
        result, events = self.run_game(app_config='''
unset PROTON_ENABLE_WAYLAND DXVK_HDR
export EXPECTED_NATIVE_HDR=1
''')
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(events, ['hdr-on', 'game 6 preset=2,fps_limit=161', 'hdr-off'])

    def test_gamescope_allows_explicit_hud_override(self):
        result, events = self.run_game(mode='gamescope',
            app_config='export MANGOHUD=0 TEST_EXPECTED_MANGOHUD=0\n')
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(events[-1], 'hdr-off')

    def test_native_exec_failure_restores_hdr_once(self):
        result, events = self.run_game(app_config='command="/nonexistent-scb-test-game"\n')
        self.assertEqual(result.returncode, 127, result.stdout+result.stderr)
        self.assertEqual(events, ['hdr-on', 'hdr-off'])

    def test_nested_gamescope_sets_its_own_hud_config(self):
        result, events = self.run_game(mode='gamescope',
            app_config='export TEST_OUTER_HUD=preset=2,fps_limit=161\n')
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertIn('game 6 no_display,fps_limit=161', events)

    def test_changed_local_mode_drives_both_desktop_launches(self):
        for mode in ['native', 'gamescope']:
            with self.subTest(mode=mode):
                result, events = self.run_game(mode=mode, local_mode=(3440,1440,143.97))
                self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
                self.assertTrue(any('fps_limit=140' in e for e in events), events)
                if mode == 'gamescope':
                    self.assertIn('-w 3440 -h 1440 -W 3440 -H 1440 -r 144', events[1])

    def test_session_metadata_failure_does_not_block_a_game(self):
        result, events = self.run_game(mode='session', session='streaming', session_metadata=False,
            app_config='export VKD3D_CONFIG=descriptor_heap\ncommand="$command \'argument with spaces\' --another-argument"\n')
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(events, ['game  preset=2,fps_limit=17'])

    def test_session_mode_requires_an_existing_compositor(self):
        result, events = self.run_game(mode='session')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(events, [])
        self.assertIn('existing Gamescope', result.stderr)

    def test_all_six_context_and_mode_combinations(self):
        for streaming in [False, True]:
            for mode in ['native', 'gamescope', 'session']:
                with self.subTest(streaming=streaming, mode=mode):
                    session=('streaming' if streaming else 'local') if mode == 'session' else None
                    result, events = self.run_game(mode=mode, session=session,
                        punktfunk='hdr' if streaming else 'local',
                        app_config=('export VKD3D_CONFIG=descriptor_heap\n'
                                    'command="$command \'argument with spaces\' --another-argument"\n'))
                    self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
                    self.assertEqual(sum(e.startswith('game ') for e in events), 1)
                    self.assertEqual(sum(e.startswith('gamescope ') for e in events), int(mode == 'gamescope'))
                    if mode == 'gamescope':
                        launch = next(e for e in events if e.startswith('gamescope '))
                        self.assertEqual('--adaptive-sync' in launch.split(), not streaming)
                        self.assertNotIn('--hdr-itm-enable', launch)
                        self.assertIn('--hdr-enabled', launch.split())
                        self.assertIn('--force-windows-fullscreen', launch.split())
                    self.assertEqual(events.count('hdr-on'), int(not streaming and mode != 'session'))
                    self.assertEqual(events.count('hdr-off'), int(not streaming and mode != 'session'))

    def test_per_game_fullscreen_opt_out(self):
        for mode in ['native', 'gamescope']:
            with self.subTest(mode=mode):
                result, events = self.run_game(mode=mode, fullscreen=False)
                self.assertEqual(result.returncode, 0, result.stdout+result.stderr)

    def test_accepted_but_unapplied_hdr_aborts_and_restores(self):
        for mode in ['native', 'gamescope']:
            with self.subTest(mode=mode):
                result, events = self.run_game(mode=mode, never_hdr=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(events, ['hdr-on', 'hdr-off'])

    def test_gamescope_hook_precedes_compositor(self):
        result,events=self.run_game(mode='gamescope')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(events[0],'hdr-on')
        self.assertEqual(events[-1],'hdr-off')
        self.assertTrue(events[1].startswith('gamescope '))

    def test_stream_dimensions_and_frame_cap_reach_gamescope(self):
        result, events = self.run_game(mode='gamescope', punktfunk='hdr')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('-w 2364 -h 1080 -W 2364 -H 1080 -r 120', events[0])
        self.assertIn('game  no_display,fps_limit=120', events)
        self.assertNotIn('hdr-on', events)

    def test_other_desktops_launch_without_display_hooks(self):
        for mode in ['native','gamescope']:
            with self.subTest(mode=mode):
                result,events=self.run_game(mode=mode,hyprland=False)
                self.assertEqual(result.returncode,0,result.stdout+result.stderr)
                self.assertTrue(any(x.startswith('game 6 ') for x in events))
                self.assertNotIn('hdr-on',events)
                self.assertNotIn('game-stop',events)

    def test_failed_display_start_prevents_both_launch_paths(self):
        for mode in ['native','gamescope']:
            with self.subTest(mode=mode):
                result,events=self.run_game(mode=mode,fail_start=True)
                self.assertNotEqual(result.returncode,0)
                self.assertEqual(events,['hdr-on'])


    def test_streaming_never_writes_monitor_rules(self):
        for mode in ['native', 'gamescope']:
            for stream in ['hdr', 'sdr']:
                with self.subTest(mode=mode, stream=stream):
                    result, events = self.run_game(mode=mode, punktfunk=stream, exit_code=7)
                    self.assertEqual(result.returncode, 7, result.stdout+result.stderr)
                    self.assertFalse(any(event.startswith('hdr') for event in events), events)
                    self.assertTrue(any(event.startswith('game  ') and 'fps_limit=120' in event
                        for event in events), events)

    def test_sdr_stream_leaves_local_display_alone(self):
        result,events=self.run_game(punktfunk='sdr')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(events,['game  preset=2,fps_limit=120'])

    def test_tablet_extension_does_not_redirect_local_game(self):
        result,events=self.run_game(punktfunk='local')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(events,['hdr-on','game 6 preset=2,fps_limit=161','hdr-off'])

    def test_unavailable_host_preserves_local_launch(self):
        result,events=self.run_game(punktfunk='unavailable')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(events,['hdr-on','game 6 preset=2,fps_limit=161','hdr-off'])


if __name__=='__main__':unittest.main()
