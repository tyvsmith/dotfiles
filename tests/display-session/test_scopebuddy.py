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


@unittest.skipUnless(shutil.which('scb'), 'ScopeBuddy is not installed')
class ScopeBuddyTest(unittest.TestCase):
    def run_game(self, mode='native', fail_start=False, exit_code=0, hyprland=True, punktfunk="idle", fail_hdr=False, reported_peak=80, probe_failed=False, reference=203, fallback=None, never_hdr=False, never_peak=False):
        with tempfile.TemporaryDirectory(prefix='scopebuddy-hooks-') as temporary:
            root=Path(temporary)
            config=root/'.config/scopebuddy'
            shutil.copytree(ROOT/'home/dot_config/scopebuddy',config)
            (config/'AppID/1234.conf').write_text('mode '+mode+'\n' +
                ('' if fallback is None else 'export SCB_PUNKTFUNK_HDR_MAX_LUMINANCE='+str(fallback)+'\n'))
            binary=root/'bin';binary.mkdir()
            (binary/'punktfunk-host').write_text("#!/usr/bin/env python3\n" +
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
if sys.argv[1]=='eval' and 'lg_hdr' in sys.argv[2]:
 with Path(os.environ['EVENT_LOG']).open('a') as f:f.write('hdr-on\\n' if 'true' in sys.argv[2] else 'hdr-off\\n')
 Path(os.environ['EVENT_LOG']+'.hdr').write_text('hdr' if 'true' in sys.argv[2] else 'srgb')
 print('error: rejected' if os.environ['FAIL_START']=='1' else 'ok')
elif sys.argv[1]=='eval':
 with Path(os.environ['EVENT_LOG']).open('a') as f:f.write('hdr '+sys.argv[2]+'\\n')
 if os.environ['FAIL_HDR']=='1':print('error: rejected');sys.exit(0)
 print('ok')
else:
 monitors=json.loads(os.environ['MONITORS'])
 state=Path(os.environ['EVENT_LOG']+'.hdr')
 for m in monitors:
  if m['name']=='DP-1' and state.exists() and os.environ['NEVER_HDR']=='0':m['colorManagementPreset']=state.read_text()
 print(json.dumps(monitors))
''')
            metadata = dict(output='PF-test', max_luminance=reported_peak, reference_luminance=reference)
            probe_script = "#!/usr/bin/env python3\nimport json,os\nfrom pathlib import Path\n" + "metadata=" + repr(metadata) + "\n"
            if probe_failed:
                probe_script += "raise SystemExit(1)\n"
            else:
                probe_script += "log=Path(os.environ['EVENT_LOG'])\n"
                probe_script += "if log.exists() and 'hdr hl.monitor' in log.read_text() and os.environ['NEVER_PEAK']=='0': metadata.update(max_luminance=float(os.environ['FALLBACK_PEAK']))\n"
                probe_script += "print(json.dumps(metadata))\n"
            (binary/'scb-output-luminance').write_text(probe_script)
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
                NEVER_HDR=str(int(never_hdr)),NEVER_PEAK=str(int(never_peak)),FALLBACK_PEAK=str(1000 if fallback is None else fallback),FAIL_START=str(int(fail_start)),GAME_EXIT=str(exit_code),
                EVENT_LOG=str(log),LD_PRELOAD='',SCB_NESTEDFIX='0',
                MONITORS=json.dumps([monitor, dict(name="DP-1", focused=punktfunk in ("idle","local"), colorManagementPreset="srgb")]),FAIL_HDR=str(int(fail_hdr)),
                HYPRLAND_INSTANCE_SIGNATURE='test' if hyprland else '')
            result=subprocess.run([shutil.which('scb'),'--',str(binary/'fake-game')],
                env=env,capture_output=True,text=True,timeout=10)
            return result,log.read_text().splitlines() if log.exists() else []

    def test_local_hooks_wrap_game_and_preserve_exit_status(self):
        result,events=self.run_game(exit_code=7)
        self.assertEqual(result.returncode,7,result.stdout+result.stderr)
        self.assertEqual(events,['hdr-on','game 6 preset=2,fps_limit=161','hdr-off'])

    def test_accepted_but_unapplied_hdr_aborts_and_restores(self):
        result, events = self.run_game(never_hdr=True)
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
        self.assertIn('-w 2364 -h 1080 -W 2364 -H 1080 -r 120', events[1])
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


    def test_hdr_stream_updates_only_virtual_output_before_game(self):
        for mode in ['native','gamescope']:
            with self.subTest(mode=mode):
                result,events=self.run_game(mode=mode,punktfunk='hdr',exit_code=7)
                self.assertEqual(result.returncode,7,result.stdout+result.stderr)
                self.assertTrue(events[0].startswith('hdr hl.monitor('),events)
                self.assertIn('PF-test',events[0])
                self.assertIn('max_luminance=1000',events[0])
                self.assertIn('-2364x140',events[0])
                self.assertIn('2364x1080@120',events[0])
                self.assertIn('sdr_max_luminance=203',events[0])
                self.assertNotIn('hdr-on',events)
                self.assertNotIn('game-stop',events)
                self.assertTrue(any(e.startswith('game  ') and 'fps_limit=120' in e for e in events),events)

    def test_valid_hdr_metadata_is_preserved_even_below_fallback(self):
        for mode in ['native', 'gamescope']:
            for peak in [400, 1600]:
                with self.subTest(mode=mode, peak=peak):
                    result, events = self.run_game(mode=mode, punktfunk='hdr', reported_peak=peak)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertFalse(any(e.startswith('hdr ') for e in events), events)

    def test_missing_or_invalid_peak_gets_fallback(self):
        for peak in [None, 0, 80, 203]:
            with self.subTest(peak=peak):
                result, events = self.run_game(punktfunk='hdr', reported_peak=peak)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('max_luminance=1000', events[0])

    def test_probe_failure_does_not_blindly_replace_metadata(self):
        result, events = self.run_game(punktfunk='hdr', probe_failed=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(events, [])

    def test_fallback_must_exceed_protocol_reference_white(self):
        result, events = self.run_game(punktfunk='hdr', reference=1200)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(events, [])

    def test_explicit_opt_out_skips_even_a_broken_probe(self):
        result, events = self.run_game(punktfunk='hdr', probe_failed=True, fallback=0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(e.startswith('hdr ') for e in events), events)

    def test_custom_fallback_does_not_override_valid_metadata(self):
        result, events = self.run_game(punktfunk='hdr', reported_peak=400, fallback=1600)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(e.startswith('hdr ') for e in events), events)

    def test_accepted_but_unapplied_peak_aborts_launch(self):
        result, events = self.run_game(punktfunk='hdr', never_peak=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(events), 1)
        self.assertTrue(events[0].startswith('hdr hl.monitor'))

    def test_sdr_stream_skips_luminance_and_local_profile(self):
        result,events=self.run_game(punktfunk='sdr', probe_failed=True)
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

    def test_rejected_hdr_rule_prevents_launch_in_both_modes(self):
        for mode in ['native','gamescope']:
            with self.subTest(mode=mode):
                result,events=self.run_game(mode=mode,punktfunk='hdr',fail_hdr=True)
                self.assertNotEqual(result.returncode,0,result.stdout+result.stderr)
                self.assertEqual(len(events),1,events)
                self.assertTrue(events[0].startswith('hdr '),events)


if __name__=='__main__':unittest.main()
