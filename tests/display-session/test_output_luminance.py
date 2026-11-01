"""Parse wayland-info 1.3's output without confusing registry IDs or color fields."""
import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

HELPER = Path(__file__).resolve().parents[2]/'home/dot_local/bin/executable_scb-output-luminance'
loader = importlib.machinery.SourceFileLoader('luminance', str(HELPER))
spec = importlib.util.spec_from_loader(loader.name, loader)
luminance = importlib.util.module_from_spec(spec)
loader.exec_module(luminance)

# Same structure as wayland-info 1.3; color blocks precede wl_output globals.
INFO = """interface: 'wp_color_manager_v1', version: 3, name: 66
\toutput: 286
\t\timage description id: 9
\t\tluminances (cd/m²): min 0.2000 max 80 reference 203
\t\ttarget_luminances (cd/m²): min 0.2000 max 4000
\t\tmax_cll (cd/m²): 5000
\toutput: 262
\t\timage description id: 8
\t\tluminances (cd/m²): min 0.2000 max 1600 reference 203
interface: 'zxdg_output_manager_v1', version: 3, name: 7
\toutput: 286
\t\tname: PF-test
interface: 'wl_output', version:  4, name: 262
\tname: DP-1
interface: 'wl_output', version:  4, name: 286
\tname: PF-test
"""

class OutputLuminanceTest(unittest.TestCase):
    def test_exact_connector_and_primary_luminance(self):
        self.assertEqual(luminance.parse(INFO, 'PF-test'),
                         dict(output='PF-test', max_luminance=80, reference_luminance=203))
        self.assertEqual(luminance.parse(INFO, 'DP-1')['max_luminance'], 1600)

    def test_explicit_icc_has_no_parametric_luminance(self):
        text = INFO.replace('luminances (cd/m²): min 0.2000 max 80 reference 203', 'icc file: size 512')
        self.assertEqual(luminance.parse(text, 'PF-test'),
                         dict(output='PF-test', max_luminance=None, reference_luminance=None))

    def test_failed_or_malformed_description_is_an_error(self):
        for text in (INFO.replace('image description id: 9', 'description failed'),
                     INFO.replace('max 80 reference 203', 'unrecognized fields'),
                     INFO.replace('wp_color_manager_v1', 'unrelated_interface')):
            with self.subTest(text=text), self.assertRaises(RuntimeError):
                luminance.parse(text, 'PF-test')

    def test_missing_or_duplicate_output_is_an_error(self):
        with self.assertRaises(RuntimeError): luminance.parse(INFO, 'PF-other')
        with self.assertRaises(RuntimeError): luminance.parse(INFO.replace('name: DP-1', 'name: PF-test'), 'PF-test')

    def test_zero_reference_is_not_disguised_as_missing(self):
        text = INFO.replace('max 80 reference 203', 'max 0 reference 0')
        self.assertEqual(luminance.parse(text, 'PF-test')['reference_luminance'], 0)

    @patch.object(luminance.subprocess, 'check_output', side_effect=subprocess.TimeoutExpired('wayland-info', 2))
    def test_timeout_is_not_missing_metadata(self, run):
        with self.assertRaises(subprocess.TimeoutExpired): luminance.query('PF-test')

if __name__ == '__main__': unittest.main()
