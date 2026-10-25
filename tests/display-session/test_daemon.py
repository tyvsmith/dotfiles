#!/usr/bin/env python3
"""Run the installed daemon against a disposable compositor, never the desktop."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

from test_session import MODES, ROOT


HYPRCTL = r'''#!/usr/bin/env python3
import json, os, re, sys
from pathlib import Path
root = Path(os.environ['FIXTURE_ROOT'])
args = sys.argv[1:]
if args[:1] == ['--instance']: args = args[2:]
with (root/'calls.log').open('a') as f: f.write(json.dumps(args)+'\n')
state = root/'monitors.json'
if args[:2] == ['-j', 'version']:
    print('{"version":"0.56.2"}')
elif args[:2] == ['-j', 'monitors']:
    print(state.read_text())
elif args[:2] in [['-j', 'workspacerules'], ['-j', 'workspaces']]:
    print('[]')
elif args[:1] == ['reload']:
    target = root/'home/.config/hypr/hyprmoncfg-monitors.lua'
    if target.exists():
        text = target.read_text()
        monitors = json.loads(state.read_text())
        for block in re.findall(r'hl.monitor\(\{(.*?)\}\)', text, re.S):
            values = {}
            for k, v in re.findall(r'^\s*(\w+) = (.*?),?$', block, re.M):
                v = v.rstrip(',')
                try: values[k] = json.loads(v)
                except ValueError: values[k] = v
            for m in monitors:
                if values.get('output') not in [m['name'], 'desc:'+m['description']]: continue
                mode = values.get('mode', 'preferred')
                if mode == 'preferred': mode = m['availableModes'][0]
                match = re.fullmatch(r'(\d+)x(\d+)@([\d.]+)(?:Hz)?', mode)
                if match:
                    m['width'],m['height'],m['refreshRate']=int(match[1]),int(match[2]),float(match[3])
                pos = re.fullmatch(r'(-?\d+)x(-?\d+)', values.get('position', '0x0'))
                m.update(scale=values.get('scale',1),transform=values.get('transform',0),
                    x=int(pos[1]),y=int(pos[2]),vrr=bool(values.get('vrr',0)),
                    colorManagementPreset=values.get('cm','srgb'),
                    currentFormat='XBGR2101010' if values.get('bitdepth',8)==10 else 'XRGB8888',
                    sdrBrightness=values.get('sdrbrightness',1),sdrSaturation=values.get('sdrsaturation',1))
        state.write_text(json.dumps(monitors))
        (root/'loaded.lua').write_text(text)
    print('ok')
elif args[:1] == ['eval']:
    probe = re.search(r'_G\.(hyprmoncfg_\w+)', ' '.join(args))
    loaded = (root/'loaded.lua').read_text() if (root/'loaded.lua').exists() else ''
    if probe and probe[1] not in loaded:
        print('error: generated configuration did not run');sys.exit(1)
    print('ok')
else:
    print('unsupported fake compositor call: '+repr(args),file=sys.stderr);sys.exit(1)
'''


@unittest.skipUnless(shutil.which('hyprmoncfgd'), 'hyprmoncfgd is not installed')
class InstalledDaemonTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='display-daemon-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root/'home'
        self.config = self.home/'.config'
        runtime = self.root/'runtime'
        binary = self.root/'bin'
        for p in [runtime,binary,self.config/'hypr',self.config/'hyprmoncfg/profiles']:
            p.mkdir(parents=True, exist_ok=True)
        (self.config/'hypr/hyprland.lua').write_text('-- isolated compositor fixture\n')
        for source in (ROOT/'home/dot_config/hyprmoncfg/profiles').glob('*.json'):
            shutil.copy2(source,self.config/'hyprmoncfg/profiles'/source.name)
        shutil.copy2(ROOT/'home/dot_config/hyprmoncfg/streaming.json',self.config/'hyprmoncfg/streaming.json')
        self.monitor = dict(id=0,name='DP-1',description='LG Electronics LG ULTRAGEAR+ 502NTPC9M944',
            make='LG Electronics',model='LG ULTRAGEAR+',serial='502NTPC9M944',width=5120,
            height=2160,refreshRate=165.06,x=0,y=0,scale=1,transform=0,dpmsStatus=True,
            focused=True,disabled=False,vrr=False,currentFormat='XBGR2101010',
            colorManagementPreset='srgb',sdrBrightness=1.35,sdrSaturation=1,
            availableModes=MODES,mirrorOf='none')
        (self.root/'monitors.json').write_text(json.dumps([self.monitor]))
        (binary/'hyprctl').write_text(HYPRCTL)
        (binary/'hyprctl').chmod(0o755)
        # Intercept service integration too; never contact the real user manager.
        for command in ['systemctl','busctl','gdbus']:
            (binary/command).write_text('#!/bin/sh\nexit 1\n')
            (binary/command).chmod(0o755)
        self.env = os.environ | dict(HOME=str(self.home),XDG_CONFIG_HOME=str(self.config),
            XDG_RUNTIME_DIR=str(runtime),HYPRLAND_INSTANCE_SIGNATURE='fixture',
            FIXTURE_ROOT=str(self.root),DBUS_SESSION_BUS_ADDRESS='unix:path='+str(runtime/'missing-bus'),
            OMARCHY_PATH=str(self.root/'no-omarchy'),PATH=str(binary)+':/usr/bin:/bin')
        self.log = (self.root/'daemon.log').open('w')
        self.addCleanup(self.log.close)
        self.process = subprocess.Popen(['hyprmoncfgd','--config-dir',str(self.config/'hyprmoncfg'),
            '--hypr-config',str(self.config/'hypr/hyprland.lua'),
            '--monitors-conf',str(self.config/'hypr/hyprmoncfg-monitors.lua'),
            '--poll-interval','1h','--lid-poll-interval','1h'],env=self.env,
            stdout=self.log,stderr=subprocess.STDOUT)
        self.addCleanup(self.stop_daemon)
        path=runtime/'hyprmoncfgd.sock'
        for _ in range(100):
            if path.exists():break
            if self.process.poll() is not None:break
            time.sleep(0.05)
        if not path.exists():
            self.fail('daemon did not start: '+(self.root/'daemon.log').read_text())

    def stop_daemon(self):
        self.process.terminate()
        try:self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill();self.process.wait()

    def run_command(self,*args,instance='fixture',ok=True):
        env=self.env|dict(HYPRLAND_INSTANCE_SIGNATURE=instance)
        result=subprocess.run(['bash',str(ROOT/'home/dot_local/bin/executable_hypr-display-session'),*args],
            env=env,capture_output=True,text=True,timeout=35)
        if ok and result.returncode:
            self.fail(result.stderr+'\n'+(self.root/'daemon.log').read_text()[-5000:])
        return result

    def current(self):
        return json.loads((self.root/'monitors.json').read_text())[0]

    def test_installed_daemon_full_lifecycle_and_fresh_session(self):
        self.run_command('reset')
        self.run_command('stream-start','--width','3840','--height','2160','--fps','60')
        self.assertEqual(self.current()['width'],3840)
        self.assertEqual(self.current()['colorManagementPreset'],'hdr')
        self.run_command('game-start','--game','553850')
        self.run_command('stream-stop')
        self.assertEqual(self.current()['width'],5120)
        self.assertEqual(self.current()['colorManagementPreset'],'hdr')
        self.run_command('stream-start','--width','1920','--height','1080','--fps','60')
        self.run_command('game-stop','--game','553850')
        self.assertEqual(self.current()['width'],1920)
        self.run_command('stream-stop')
        self.assertEqual(self.current()['colorManagementPreset'],'srgb')
        self.run_command('game-start','--game','3010850')
        self.run_command('reset',instance='new-compositor')
        self.assertEqual(self.current()['colorManagementPreset'],'srgb')


    def test_scale_shortcuts_save_through_daemon_and_preserve_profile(self):
        self.run_command('reset')
        helper = ROOT/'home/dot_local/bin/executable_hyprmoncfg-helper'
        env = self.env | {'OMARCHY_PATH': '/usr/share/omarchy'}
        for direction, expected in [('up', 1.25), ('up', 1.6), ('down', 1.25)]:
            result = subprocess.run(['/usr/bin/python3', str(helper), 'scale', direction], env=env,
                                    capture_output=True, text=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertAlmostEqual(self.current()['scale'], expected)
            saved = json.loads((self.config/'hyprmoncfg/profiles/desktop.json').read_text())
            self.assertEqual(saved['outputs'][0]['scale'], expected)
            self.assertEqual(saved['outputs'][0]['mode'], 'preferred')
            self.assertEqual(saved['outputs'][0]['bitdepth'], 10)
        self.run_command('game-start', '--game', '123')
        self.assertEqual(self.current()['colorManagementPreset'], 'hdr')
        self.assertEqual(self.current()['scale'], 1)

    def test_scale_does_not_save_temporary_streaming_as_desktop(self):
        self.run_command('reset')
        saved = self.config/'hyprmoncfg/profiles/desktop.json'
        before = saved.read_bytes()
        self.run_command('stream-start','--width','1920','--height','1080','--fps','60')
        result = subprocess.run(['/usr/bin/python3', str(ROOT/'home/dot_local/bin/executable_hyprmoncfg-helper'), 'scale', 'up'],
                                env=self.env | {'OMARCHY_PATH': '/usr/share/omarchy'},
                                capture_output=True, text=True, timeout=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('temporary stream layouts', result.stderr)
        self.assertEqual(saved.read_bytes(), before)
        self.assertEqual(self.current()['width'], 1920)

if __name__=='__main__':unittest.main()
