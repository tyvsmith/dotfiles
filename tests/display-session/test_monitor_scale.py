"""Runtime scaling must keep Punktfunk's mode, placement and HDR metadata."""
import importlib.machinery
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

PATH = Path(__file__).resolve().parents[2]/'home/dot_local/bin/executable_hypr-monitor-scale'
loader = importlib.machinery.SourceFileLoader('monitor_scale', str(PATH))
spec = importlib.util.spec_from_loader(loader.name, loader)
scale = importlib.util.module_from_spec(spec)
loader.exec_module(scale)

class ScaleTest(unittest.TestCase):
    def monitor(self):
        return dict(name='PF-1', width=2800, height=1752, refreshRate=120,
                    x=1106, y=2160, scale=1, transform=0, currentFormat='XRGB8888',
                    colorManagementPreset='srgb', sdrBrightness=1, sdrSaturation=1,
                    sdrMinLuminance=.2, sdrMaxLuminance=80)

    def test_fractional_step_is_exact_and_reversible(self):
        m = self.monitor()
        value = scale.next_scale(m, 'up')
        self.assertAlmostEqual(value, 4/3)
        self.assertAlmostEqual(m['width']/value, 2100)
        self.assertAlmostEqual(m['height']/value, 1314)
        m['scale'] = value
        self.assertEqual(scale.next_scale(m, 'down'), 1)

    def test_coprime_dimensions_have_no_larger_clean_scale(self):
        m = self.monitor(); m.update(width=1921, height=1080)
        self.assertEqual(scale.next_scale(m, 'up'), 1)

    def test_clean_rounding_cannot_exceed_maximum(self):
        m = self.monitor(); m.update(width=2807, height=1757)
        with self.assertRaises(ValueError): scale.next_scale(m, '4')

    @patch.object(scale, 'run', return_value='ok')
    def test_changes_only_scale_without_luminance_probe(self, run):
        scale.apply_scale('PF-1', 4/3)
        self.assertEqual(run.call_count, 1)
        command = run.call_args.args
        self.assertEqual(command[:2], ('hyprctl', 'eval'))
        self.assertEqual(command[2], 'hl.monitor({output="PF-1",scale=1.3333333333333333})')

    def test_rejects_nonfinite_or_out_of_bounds_scale(self):
        for value in ['nan','inf','0','-1','100']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                scale.next_scale(self.monitor(), value)

if __name__ == '__main__': unittest.main()
