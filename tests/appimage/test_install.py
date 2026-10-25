import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]


class AppImageInstallTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'home'
        self.home.mkdir()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.calls = self.root / 'calls.jsonl'
        self.fixture = self.root / 'release.json'
        self.fixture.write_text(json.dumps({'assets': [
            {'name': 'sample-aarch64.AppImage', 'browser_download_url': 'https://example.test/arm'},
            {'name': 'sample-x86_64.AppImage', 'browser_download_url': 'https://example.test/x86'},
        ]}))
        self.tool('uname', 'print("x86_64")\n')
        self.tool('curl', '''import json,os,sys
from pathlib import Path
args=sys.argv[1:]
with open(os.environ['CALLS'],'a') as f:f.write(json.dumps(['curl',*args])+'\\n')
if '-o' in args:
 Path(args[args.index('-o')+1]).write_bytes(b'appimage-test')
else: print(Path(os.environ['FIXTURE']).read_text())
''')
        self.tool('shelly', '''import json,os,sys
from pathlib import Path
args=sys.argv[1:];home=Path.home();state=home/'registered';directory=Path(os.environ.get('SHELLY_DIR',str(home/'AppImages')))
with open(os.environ['CALLS'],'a') as f:f.write(json.dumps(['shelly',*args])+'\\n')
if args[:3]==['config','get','AppImageInstallPath']: print(os.environ.get('SHELLY_DIR',str(directory)))
elif args[:2]==['list','appimage']: print(json.dumps([{'Name':'sample'}] if state.exists() else []))
elif args[:2]==['install','appimage']:
 state.touch();dest=directory/'sample.AppImage';dest.parent.mkdir(exist_ok=True);dest.write_bytes(Path(args[2]).read_bytes())
elif args[:2]==['sync','appimage'] and os.environ.get('FAIL_SYNC'): sys.exit(7)
''')
        template = REPO / 'home/run_onchange_31-install-packages-appimage.sh.tmpl'
        overrides = {'profile': 'test', 'profiles': {'test': {'appimage': True}},
                     'tags': 'ui', 'de': '', 'work': False, 'decrypt': False, 'backup': False,
                     'packages': {'selkies': {'enabled': False}, 'sample': {'tags': ['ui'], 'pacman': False,
                     'brew': False, 'apt': False, 'dnf': False, 'appimage': 'owner/sample'}}}
        config = self.root / 'chezmoi.toml'
        config.write_text('')
        rendered = subprocess.check_output([
            'chezmoi', '--source', str(REPO / 'home'), '--config', str(config),
            '--override-data', json.dumps(overrides),
            'execute-template', template.read_text()], text=True)
        self.script = self.root / 'install.sh'
        self.script.write_text(rendered)
        self.env = os.environ | {'HOME': str(self.home), 'PATH': str(self.bin)+':/usr/bin:/bin',
            'CALLS': str(self.calls), 'FIXTURE': str(self.fixture),
            'CHEZMOI_SOURCE_DIR': str(REPO / 'home')}

    def tool(self, name, body):
        p=self.bin/name
        p.write_text('#!/usr/bin/python3\n'+body)
        p.chmod(0o755)

    def run_installer(self, **extra):
        return subprocess.run(['bash', str(self.script)], env=self.env | extra,
                              text=True, capture_output=True)

    def test_selects_host_asset_and_registers_updates(self):
        result=self.run_installer()
        self.assertEqual(result.returncode,0,result.stderr)
        calls=[json.loads(line) for line in self.calls.read_text().splitlines()]
        downloads=[c for c in calls if c[0]=='curl' and '-o' in c]
        self.assertEqual(len(downloads),1)
        self.assertIn('https://example.test/x86', downloads[0])
        self.assertIn(['shelly','sync','appimage','sample','owner/sample','GitHub','--no-confirm'],calls)
        self.calls.write_text('')
        result=self.run_installer()
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertNotIn('"curl"',self.calls.read_text())

    def test_local_bin_with_trailing_slash_does_not_replace_the_binary_with_a_link(self):
        result=self.run_installer(SHELLY_DIR=str(self.home/'.local/bin')+'/')
        self.assertEqual(result.returncode,0,result.stderr)
        executable=self.home/'.local/bin/sample.AppImage'
        self.assertFalse(executable.is_symlink())
        self.assertEqual(executable.read_bytes(),b'appimage-test')

    def test_custom_shelly_directory_has_a_stable_executable(self):
        directory=self.home/'CustomImages'
        result=self.run_installer(SHELLY_DIR=str(directory))
        self.assertEqual(result.returncode,0,result.stderr)
        executable=self.home/'.local/bin/sample.AppImage'
        self.assertTrue(executable.is_symlink())
        self.assertEqual(executable.resolve(),directory/'sample.AppImage')
        # Shelly replaces the target at the same path during an upgrade.
        (directory/'sample.AppImage').write_bytes(b'updated')
        self.assertEqual(executable.read_bytes(),b'updated')

    def test_missing_registered_file_is_reinstalled(self):
        (self.home/'registered').touch()
        result=self.run_installer()
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertTrue((self.home/'AppImages/sample.AppImage').exists())

    def test_ambiguous_assets_are_rejected(self):
        self.fixture.write_text(json.dumps({'assets':[
            {'name':'sample-standard-x86_64.AppImage','browser_download_url':'https://example.test/standard'},
            {'name':'sample-portable-x86_64.AppImage','browser_download_url':'https://example.test/portable'}]}))
        self.assertNotEqual(self.run_installer().returncode,0)

    def test_registration_failure_is_reported(self):
        result=self.run_installer(FAIL_SYNC='1')
        self.assertNotEqual(result.returncode,0)

    def test_rejects_incompatible_architecture(self):
        self.fixture.write_text(json.dumps({'assets':[
            {'name':'sample-aarch64.AppImage','browser_download_url':'https://example.test/arm'}]}))
        result=self.run_installer()
        self.assertNotEqual(result.returncode,0)
        self.assertFalse((self.home/'AppImages/sample.AppImage').exists())


if __name__=='__main__':unittest.main()
