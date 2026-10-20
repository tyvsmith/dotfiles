"""Check the real systemd parser and dependency graph without starting units."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_session import ROOT, SCRIPT


@unittest.skipUnless(shutil.which('systemd-analyze') and Path('/usr/lib/systemd/user/hyprmoncfgd.service').exists(),
                     'installed systemd and hyprmoncfg unit required')
class UnitsTest(unittest.TestCase):
    def test_graphical_session_units_verify(self):
        with tempfile.TemporaryDirectory(prefix='hypr-session-units-') as tmp:
            root = Path(tmp)
            runtime = root/'runtime'
            runtime.mkdir(mode=0o700)
            source = ROOT/'home/dot_config/systemd/user'
            unit = root/'hypr-display-session.service'
            unit.write_text((source/unit.name).read_text().replace(
                '%h/.local/bin/hypr-display-session', str(SCRIPT)))
            daemon = root/'hyprmoncfgd.service'
            shutil.copy2('/usr/lib/systemd/user/hyprmoncfgd.service', daemon)
            shutil.copytree(source/'hyprmoncfgd.service.d', root/'hyprmoncfgd.service.d')
            sunshine = root/'app-dev.lizardbyte.app.Sunshine.service'
            shutil.copy2(Path('/usr/lib/systemd/user')/sunshine.name,sunshine)
            dropin = root/(sunshine.name+'.d')
            dropin.mkdir()
            (dropin/'cleanup.conf').write_text((source/(sunshine.name+'.d/cleanup.conf')).read_text().replace(
                '%h/.local/bin/sunshine-usbip',str(ROOT/'home/dot_local/bin/executable_sunshine-usbip')).replace(
                '%h/.local/bin/hypr-display-session',str(SCRIPT)))
            result = subprocess.run(['systemd-analyze','--user','verify','--man=no',str(unit),str(daemon),str(sunshine)],
                env=os.environ | {'XDG_RUNTIME_DIR':str(runtime)},capture_output=True,text=True,timeout=15)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)


if __name__ == '__main__':
    unittest.main()
