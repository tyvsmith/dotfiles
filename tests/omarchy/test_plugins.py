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
    if ident == 'jgarza.hlsovpp':
        installer = dest / 'install'
        installer.write_text('#!/bin/sh\\nprintf \\'["native-install"]\\\\n\\' >> "$CALLS"\\ntouch "$HOME/native-installed"\\n')
        installer.chmod(0o755)
''')

        self.tool('hyprpm', '''import os, sys
from pathlib import Path
if sys.argv[1:] == ['list'] and (Path.home() / 'native-installed').exists():
    print('Repository hlsovpp (by plugins):')
''')
        self.tool('hyprctl', '''import json, os, sys
with open(os.environ['CALLS'], 'a') as f:
    f.write(json.dumps(['hyprctl', *sys.argv[1:]]) + '\\n')
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
        self.assertEqual(calls.count(['native-install']), 1)
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

    def test_fathom_bindings_reload_when_native_provider_already_exists(self):
        (self.root / 'native-installed').touch()
        result = self.run_script('run_onchange_49-install-omarchy-plugins.sh.tmpl',
                                 HYPRLAND_INSTANCE_SIGNATURE='test')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertEqual(calls[-1], ['hyprctl', 'reload'])
        self.assertNotIn(['native-install'], calls)

    def test_headers_are_initialized_before_adding_native_repositories(self):
        self.tool('hyprpm', '''import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as f: f.write(json.dumps(args) + '\\n')
headers = Path.home() / 'headers'
if args == ['update']: headers.touch()
elif args[0] == 'add' and not headers.exists():
    sys.exit('Headers outdated, please run hyprpm update.')
''')
        result = self.run_script('run_onchange_50-configure-hyprpm.sh.tmpl')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertTrue(any(c[0] == 'add' for c in calls))

    def test_hyprpm_leaves_overview_provider_alone(self):
        self.tool('hyprpm', '''import json, os, sys
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as f: f.write(json.dumps(args) + '\\n')
if args == ['list']:
    print('Repository hyprland-plugins (by hyprwm):')
    print('Plugin hyprfocus\\n enabled: true')
    print('Repository hyprland-scroll-overview (by yayuuu):')
''')
        result = self.run_script('run_onchange_50-configure-hyprpm.sh.tmpl')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertFalse(any(c[0] in ('add', 'remove', 'disable', 'enable') for c in calls))

    def test_native_state_write_failures_remain_retryable(self):
        self.tool('hyprpm', '''import os, sys
args = sys.argv[1:]
if args == ['list']:
    print('Repository hyprland-plugins (by hyprwm):')
    print('Plugin hyprfocus\\n enabled: false')
if args[0] == os.environ['FAIL_STEP']:
    sys.exit('Failed to write plugin state')
''')
        for step in ('update', 'enable'):
            with self.subTest(step=step):
                result = self.run_script('run_onchange_50-configure-hyprpm.sh.tmpl', FAIL_STEP=step)
                self.assertNotEqual(result.returncode, 0,
                                    'failed setup must not be recorded as completed by chezmoi')
