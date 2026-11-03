"""Read-only display discovery; no games, compositor changes or live sessions."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
LIBRARY = ROOT / 'home/dot_config/scopebuddy/common.sh'
XRANDR = '''Screen 0: minimum 16 x 16, current 1920 x 1080, maximum 32767 x 32767
XWAYLAND0 connected primary 1920x1080+0+0 (normal left inverted right x axis y axis)
   3840x2160     60.00 +
   1920x1080     60.00  59.94*+
'''


class DisplaySnapshotTest(unittest.TestCase):
    def snapshot(self, *, session=False, streaming=False, xrandr=XRANDR,
                 local_mode=(3440, 1440, 143.97), missing_local=False):
        with tempfile.TemporaryDirectory(prefix='scb-display-') as temporary:
            root = Path(temporary)
            binary = root / 'bin'
            binary.mkdir()
            monitors = [dict(name='PF-tablet', width=2364, height=1080,
                             refreshRate=120, focused=streaming, scale=2)]
            if not missing_local:
                monitors.append(dict(name='DP-1', width=local_mode[0],
                                     height=local_mode[1], refreshRate=local_mode[2],
                                     focused=not streaming, scale=1.5))
            (root / 'monitors').write_text(json.dumps(monitors))
            (root / 'xrandr').write_text(xrandr)
            (root / 'punktfunk-gamescope-ei').write_text(
                'gamescope-test-ei' if streaming else 'another-session-ei')
            for name, body in {
                'hyprctl': 'cat "$TEST_ROOT/monitors"',
                'punktfunk-host': 'printf \'{"data":{"active_sessions":1}}\\n\'',
                'xrandr': 'test -s "$TEST_ROOT/xrandr" && cat "$TEST_ROOT/xrandr"',
            }.items():
                path = binary / name
                path.write_text('#!/bin/sh\necho "'+name+' $*" >> "$TEST_ROOT/queries"\n'+body+'\n')
                path.chmod(0o755)
            env = os.environ | dict(TEST_ROOT=str(root), PATH=str(binary)+':/usr/bin:/bin',
                XDG_RUNTIME_DIR=str(root), HYPRLAND_INSTANCE_SIGNATURE='test', DISPLAY=':42',
                XDG_CURRENT_DESKTOP='gamescope' if session else 'Hyprland',
                GAMESCOPE_WAYLAND_DISPLAY='gamescope-test' if session else '',
                LIBEI_SOCKET='gamescope-test-ei' if session else '')
            result = subprocess.run(['bash', '-c', '''
source "$1"
display_init || exit 1
printf '%s|%s|%s|%s|%s\\n' "$(get_display_context)" "$(get_display_width)" \
    "$(get_display_height)" "$(get_display_fps)" "$(get_display_fps_cap 4)"
get_display_width >/dev/null
get_display_height >/dev/null
get_display_fps >/dev/null
''', 'snapshot', str(LIBRARY)], env=env, text=True, capture_output=True)
            queries = root / 'queries'
            return result, queries.read_text().splitlines() if queries.exists() else []

    def test_local_active_pixels_and_fractional_refresh_are_cached(self):
        result, queries = self.snapshot()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'local|3440|1440|143.97|140')
        self.assertEqual(queries.count('hyprctl -j monitors'), 1)

    def test_streaming_virtual_output_is_selected(self):
        result, queries = self.snapshot(streaming=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'streaming|2364|1080|120|116')
        self.assertEqual(queries.count('hyprctl -j monitors'), 1)

    def test_existing_local_and_streamed_sessions_use_active_xrandr_mode(self):
        for streaming in [False, True]:
            with self.subTest(streaming=streaming):
                result, queries = self.snapshot(session=True, streaming=streaming)
                self.assertEqual(result.returncode, 0, result.stderr)
                context = 'streaming' if streaming else 'local'
                self.assertEqual(result.stdout.strip(), context+'|1920|1080|59.94|56')
                self.assertEqual(queries, ['xrandr --current'])

    def test_missing_session_metadata_remains_unknown_and_does_not_block_reuse(self):
        result, queries = self.snapshot(session=True, streaming=True, xrandr='')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'streaming||||')
        self.assertEqual(queries, ['xrandr --current'])

    def test_multiple_active_xrandr_outputs_are_not_guessed(self):
        result, _ = self.snapshot(session=True, xrandr=XRANDR+'''
XWAYLAND1 connected 1280x720+1920+0
   1280x720 60.00*
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'local||||')

    def test_missing_local_target_aborts_instead_of_selecting_tablet(self):
        result, _ = self.snapshot(missing_local=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('DP-1', result.stderr)
