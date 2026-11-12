import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]
PLUGINS = {
    'jgarza.hlsovpp': 'https://github.com/jgarza9788/hlsovpp',
    'io.github.twiking.omacontrol': 'https://github.com/twiking/omacontrol',
    'io.github.mtolhuys.fathom': 'https://github.com/mtolhuys/fathom',
}


class PluginInstallTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.calls = self.root / 'calls'
        self.config = self.root / 'chezmoi.toml'
        self.config.write_text('')
        self.env = os.environ | {'HOME': str(self.root),
            'PATH': str(self.bin) + ':/usr/bin:/bin', 'CALLS': str(self.calls),
            'PLUGINS': json.dumps(PLUGINS), 'XDG_RUNTIME_DIR': str(self.root / 'run')}
        self.tool('omarchy', '''import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as f: f.write(json.dumps(args) + '\\n')
if args[:2] == ['plugin', 'add']:
    if os.environ.get('FAIL_ADD'): sys.exit(1)
    ids = json.loads(os.environ['PLUGINS'])
    ident = next(k for k, v in ids.items() if v == args[2])
    dest = Path.home() / '.config/omarchy/plugins' / ident
    dest.mkdir(parents=True)
    (dest / 'manifest.json').write_text(json.dumps({'id': ident}))
''')

    def tool(self, name, body):
        path = self.bin / name
        path.write_text('#!/usr/bin/python3\n' + body)
        path.chmod(0o755)

    def render(self, name, desktop='hyprland-omarchy'):
        template = REPO / 'home' / name
        return subprocess.check_output([
            'chezmoi', '--source', str(REPO / 'home'), '--config', str(self.config),
            '--override-data', json.dumps({'profile': 'test', 'profiles': {'test': {'de': desktop}}}),
            'execute-template', template.read_text()], text=True)

    def run_script(self, name, **env):
        return subprocess.run(['bash'], input=self.render(name), text=True,
            capture_output=True, env=self.env | env)

    def test_install_and_repeat_preserve_existing_plugins(self):
        for _ in range(2):
            result = self.run_script('run_onchange_49-install-omarchy-plugins.sh.tmpl')
            self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        adds = [c for c in calls if c[:2] == ['plugin', 'add']]
        self.assertCountEqual([c[2] for c in adds], PLUGINS.values())
        for call in adds:
            self.assertIn('--enable', call, 'add must wait for shell discovery before enabling')
        for ident in PLUGINS:
            self.assertIn(['plugin', 'enable', ident], calls)

    def test_failed_download_stops_install(self):
        result = self.run_script('run_onchange_49-install-omarchy-plugins.sh.tmpl', FAIL_ADD='1')
        self.assertNotEqual(result.returncode, 0)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertFalse(any(c[:2] == ['plugin', 'enable'] for c in calls))

    def test_other_desktops_do_nothing(self):
        script = self.render('run_onchange_49-install-omarchy-plugins.sh.tmpl', 'none')
        result = subprocess.run(['bash'], input=script, text=True, env=self.env)
        self.assertEqual(result.returncode, 0)
        self.assertFalse(self.calls.exists())

    def test_native_provider_migrates_before_enabling(self):
        self.tool('hyprpm', '''import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as f: f.write(json.dumps(args) + '\\n')
if args == ['list']:
    print('Repository hyprland-plugins (by hyprwm):')
    print('Plugin hyprfocus\\n enabled: true')
    if not (Path.home() / 'removed').exists(): print('Repository hyprland-scroll-overview (by yayuuu):')
elif args == ['remove', 'hyprland-scroll-overview']: (Path.home() / 'removed').touch()
''')
        result = self.run_script('run_onchange_50-configure-hyprpm.sh.tmpl')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        remove = calls.index(['remove', 'hyprland-scroll-overview'])
        add = calls.index(['add', PLUGINS['jgarza.hlsovpp']])
        enable = calls.index(['enable', 'scrolloverview'])
        self.assertLess(remove, add)
        self.assertLess(add, enable)
