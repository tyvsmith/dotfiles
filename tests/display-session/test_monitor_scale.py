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

    def test_keeps_actual_mode_and_position(self):
        rule = scale.monitor_rule(self.monitor(), 4/3)
        self.assertEqual(rule['mode'], '2800x1752@120.000000')
        self.assertEqual(rule['position'], '1106x2160')
        self.assertEqual(rule['cm'], 'srgb')
        self.assertEqual(rule['bitdepth'], 8)

    @patch.object(scale, 'read_luminance', return_value={'max_luminance':1000,'reference_luminance':203})
    def test_hdr_metadata_survives_scale_change(self, read):
        m = self.monitor(); m.update(colorManagementPreset='hdr',currentFormat='XBGR2101010',sdrMaxLuminance=203)
        rule = scale.monitor_rule(m, 4/3)
        self.assertEqual(rule['max_luminance'], 1000)
        self.assertEqual(rule['sdr_max_luminance'], 203)
        self.assertEqual(rule['bitdepth'], 10)

    @patch.object(scale, 'read_luminance', side_effect=RuntimeError('timeout'))
    def test_failed_hdr_probe_prevents_change(self, read):
        m = self.monitor(); m['colorManagementPreset']='hdr'
        with self.assertRaises(RuntimeError): scale.monitor_rule(m, 2)

    def test_rejects_nonfinite_or_out_of_bounds_scale(self):
        for value in ['nan','inf','0','-1','100']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                scale.next_scale(self.monitor(), value)

if __name__ == '__main__': unittest.main()
