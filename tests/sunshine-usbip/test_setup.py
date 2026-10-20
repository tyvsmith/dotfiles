"""Check setup authentication decisions without running privileged commands."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]

@unittest.skipUnless(shutil.which('chezmoi'),'chezmoi required')
class SetupTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        binary=self.root/'bin';binary.mkdir()
        (self.root/'config.toml').touch()
        (binary/'usbip').write_text('#!/bin/sh\nexit 0\n')
        (binary/'systemctl').write_text('#!/bin/sh\nexit 0\n')
        (binary/'sudo').write_text('''#!/usr/bin/env python3
import os,sys,shutil
from pathlib import Path
r=Path(os.environ['FIXTURE'])
with (r/'calls').open('a') as f:f.write('sudo\\n')
sys.stdin.read()
if (r/'fail').exists():sys.exit(1)
staging=Path(sys.argv[-1]);target=r/'modules'
target.parent.mkdir(exist_ok=True)
shutil.copy2(staging/'modules.conf',target)
shutil.copy2(staging/'sudoers',r/'installed-sudoers')
''')
        for p in binary.iterdir():p.chmod(0o755)
        self.env=os.environ|{'HOME':str(self.root),'XDG_STATE_HOME':str(self.root/'state'),
            'FIXTURE':str(self.root),'PATH':str(binary)+':/usr/bin:/bin'}

    def run_setup(self,username='testuser'):
        template=(ROOT/'home/run_onchange_52-configure-sunshine-usbip.sh.tmpl').read_text()
        rendered=subprocess.run(['chezmoi','--source',str(ROOT),'--config',str(self.root/'config.toml'),
            '--override-data','{"de":"hyprland-omarchy","chezmoi":{"username":"'+username+'"}}',
            'execute-template'],input=template,capture_output=True,text=True,check=True).stdout
        rendered=rendered.replace('/etc/modules-load.d/sunshine-usbip.conf',str(self.root/'modules'))
        return subprocess.run(['bash'],input=rendered,env=self.env,capture_output=True,text=True)

    def count(self):
        p=self.root/'calls'
        return len(p.read_text().splitlines()) if p.exists() else 0

    def test_unchanged_setup_and_user_config_changes_do_not_authenticate(self):
        first=self.run_setup();self.assertEqual(first.returncode,0,first.stderr)
        self.assertEqual(self.count(),1)
        (self.root/'sunshine-usbip.conf').write_text('declare -A controllers=([other.example]=1234:5678)\n')
        again=self.run_setup();self.assertEqual(again.returncode,0,again.stderr)
        self.assertEqual(self.count(),1)
        policy=(self.root/'installed-sudoers').read_text()
        self.assertIn('/usr/bin/usbip attach *, /usr/bin/usbip detach *',policy)
        self.assertNotIn('modprobe',policy)
        self.assertEqual((self.root/'modules').read_text(),'vhci_hcd\n')

    def test_changed_privileged_definitions_authenticate(self):
        self.assertEqual(self.run_setup().returncode,0)
        self.assertEqual(self.run_setup(username='otheruser').returncode,0)
        self.assertEqual(self.count(),2)

    def test_failed_installation_is_not_cached(self):
        (self.root/'fail').touch()
        self.assertNotEqual(self.run_setup().returncode,0)
        self.assertFalse((self.root/'state/sunshine-usbip/setup.sha256').exists())
        (self.root/'fail').unlink()
        self.assertEqual(self.run_setup().returncode,0)
        self.assertEqual(self.count(),2)

    def test_removed_module_file_requires_repair(self):
        self.assertEqual(self.run_setup().returncode,0)
        (self.root/'modules').unlink()
        self.assertEqual(self.run_setup().returncode,0)
        self.assertEqual(self.count(),2)

if __name__=='__main__':unittest.main()
