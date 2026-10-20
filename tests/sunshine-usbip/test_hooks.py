"""Exercise USB ownership with a fake kernel and USB/IP backend."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]

class USBTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        for name in ['bin','platform/vhci_hcd.0','usb']:(self.root/name).mkdir(parents=True)
        (self.root/'config').write_text("declare -A controllers=([nvidia-shield-pro.host.tysmith.app]=28de:1304)\n")
        self.status=self.root/'platform/vhci_hcd.0/status'
        self.status.write_text('hub port sta spd dev sock local_busid\n')
        (self.root/'bin/sudo').write_text('#!/bin/sh\nexec "$@"\n')
        (self.root/'bin/usbip').write_text('''#!/usr/bin/env python3
import os,sys
from pathlib import Path
r=Path(os.environ['FIXTURE']);a=sys.argv[1:]
device=os.environ.get('DEVICE_ID','28de:1304');vendor,product=device.split(':')
with (r/'calls').open('a') as f:f.write(' '.join(a)+'\\n')
if a[0]=='list':
 if (r/'unavailable').exists():sys.exit(1)
 if (r/'no-controller').exists():sys.exit(0)
 if a[2]!=os.environ.get('SERVER_HOST','nvidia-shield-pro.host.tysmith.app'):sys.exit(1)
 print(f'    1-2: Controller ({device})')
 if (r/'ambiguous').exists():print('    1-3: Valve : Steam Controller (28de:1304)')
elif a[0]=='attach':
 p=r/'usb/12-1';p.mkdir(exist_ok=True)
 for name,value in [('idVendor',vendor),('idProduct',product),('devnum','9')]: (p/name).write_text(value)
 with (r/'platform/vhci_hcd.0/status').open('a') as f:f.write('hs 0 6 3 0 0 12-1\\n')
 if (r/'attach-error').exists():sys.exit(1)
elif a[0]=='detach':
 (r/'platform/vhci_hcd.0/status').write_text('hub port sta spd dev sock local_busid\\n')
else:sys.exit(1)
''')
        for p in (self.root/'bin').iterdir():p.chmod(0o755)
        source=(ROOT/'home/dot_local/bin/executable_sunshine-usbip').read_text()
        for old,new in [('/sys/devices/platform',str(self.root/'platform')),('/sys/bus/usb/devices',str(self.root/'usb')),('/usr/bin/usbip',str(self.root/'bin/usbip'))]:source=source.replace(old,new)
        self.script=self.root/'helper';self.script.write_text(source)
        self.env=os.environ|{'FIXTURE':str(self.root),'XDG_RUNTIME_DIR':str(self.root),
            'XDG_CONFIG_HOME':str(self.root),'SUNSHINE_CLIENT_NAME':'nvidia-shield-pro.host.tysmith.app',
            'PATH':str(self.root/'bin')+':/usr/bin:/bin'}
        (self.root/'config').rename(self.root/'sunshine-usbip.conf')

    def run_hook(self,*args,ok=True):
        result=subprocess.run(['bash',str(self.script),*args],env=self.env,capture_output=True,text=True,timeout=15)
        if ok:self.assertEqual(result.returncode,0,result.stderr)
        return result

    def calls(self):
        p=self.root/'calls'
        return p.read_text().splitlines() if p.exists() else []

    def test_attach_duplicate_and_detach(self):
        self.run_hook('start');self.run_hook('start');self.run_hook('stop');self.run_hook('stop')
        self.assertEqual(sum(x.startswith('attach ') for x in self.calls()),1)
        self.assertEqual(sum(x.startswith('detach ') for x in self.calls()),1)

    def test_ambiguous_export_does_not_attach(self):
        (self.root/'ambiguous').touch()
        self.assertIn('sunshine-usbip:',self.run_hook('start').stderr)
        self.assertFalse(any(x.startswith('attach ') for x in self.calls()))

    def test_manual_attachment_is_not_claimed(self):
        self.run_hook('start');(self.root/'sunshine-usbip/owned').unlink()
        self.assertIn('sunshine-usbip:',self.run_hook('start').stderr)
        self.run_hook('stop')
        self.assertFalse(any(x.startswith('detach ') for x in self.calls()))

    def test_reused_port_is_not_detached(self):
        self.run_hook('start');(self.root/'usb/12-1/devnum').write_text('10')
        self.run_hook('stop')
        self.assertFalse(any(x.startswith('detach ') for x in self.calls()))

    def test_attach_error_after_kernel_success_is_owned(self):
        (self.root/'attach-error').touch()
        self.run_hook('start');self.run_hook('stop')
        self.assertTrue(any(x.startswith('detach ') for x in self.calls()))

    def test_interrupted_attachment_is_not_adopted_on_stop(self):
        self.run_hook('start')
        (self.root/'sunshine-usbip/owned').unlink()
        (self.root/'sunshine-usbip/before').write_text('')
        (self.root/'sunshine-usbip/pending').write_text('1-2\n')
        self.assertIn('interrupted',self.run_hook('stop').stderr)
        self.assertFalse(any(x.startswith('detach ') for x in self.calls()))

    def test_arguments_cannot_select_arbitrary_devices(self):
        self.assertNotEqual(self.run_hook('start','other-host',ok=False).returncode,0)


    def test_unlisted_phone_skips_discovery(self):
        self.env['SUNSHINE_CLIENT_NAME']='Pixel-10-Pro-Fold.host.tysmith.app'
        self.run_hook('start')
        self.assertEqual(self.calls(),[])

    def test_listed_client_without_controller_can_stream(self):
        (self.root/'no-controller').touch()
        self.assertIn('expected exactly one',self.run_hook('start').stderr)
        self.run_hook('stop')
        self.assertFalse(any(x.startswith(('attach ', 'detach ')) for x in self.calls()))
        self.assertEqual(self.run_hook('status').stdout.strip(),'detached')

    def test_listed_client_without_server_can_stream(self):
        (self.root/'unavailable').touch()
        self.assertIn('USB server unavailable',self.run_hook('start').stderr)
        self.run_hook('stop')
        self.assertFalse(any(x.startswith(('attach ', 'detach ')) for x in self.calls()))

    def test_client_hostname_is_used_directly(self):
        self.env['SUNSHINE_CLIENT_NAME']='another-device.example.test'
        self.env['SERVER_HOST']='another-device.example.test'
        self.env['DEVICE_ID']='054c:0ce6'
        with (self.root/'sunshine-usbip.conf').open('a') as f:
            f.write('controllers[another-device.example.test]=054c:0ce6\n')
        self.run_hook('start')
        self.assertIn('list -r another-device.example.test',self.calls())
        self.assertIn('attach -r another-device.example.test -b 1-2',self.calls())
        self.assertIn('054c:0ce6',(self.root/'sunshine-usbip/owned').read_text())

    def test_empty_client_skips_discovery(self):
        self.env.pop('SUNSHINE_CLIENT_NAME')
        self.run_hook('start')
        self.assertEqual(self.calls(),[])

    def test_friendly_label_without_hostname_does_not_attach(self):
        self.env['SUNSHINE_CLIENT_NAME']='My Shield'
        self.run_hook('start')
        self.assertEqual(self.calls(),[])

    def test_stop_uses_original_identity_after_config_change(self):
        self.run_hook('start')
        (self.root/'sunshine-usbip.conf').write_text("declare -A controllers=([different-device.example.test]=1234:5678)\n")
        self.env['SUNSHINE_CLIENT_NAME']='different-device.example.test'
        self.run_hook('stop')
        self.assertTrue(any(x.startswith('detach ') for x in self.calls()))

if __name__=='__main__':unittest.main()
