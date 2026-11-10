"""Punktfunk's adapter must preserve probes, patched binary selection and argv."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
WRAPPER = ROOT / "home/dot_local/share/overrides/bin/executable_punktfunk-gamescope"


class PunktfunkTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.bin = Path(self.tmp.name)
        self.backend = self.bin / "punktfunk-gamescope"
        self.backend.write_text('''#!/usr/bin/python3
import json, os, sys
print(json.dumps(dict(argv=sys.argv[1:], mango=os.getenv("MANGOHUD"),
    config=os.getenv("MANGOHUD_CONFIG"), limit=os.getenv("MANGOHUD_FPS_LIMIT"),
    configfile=os.getenv("MANGOHUD_CONFIGFILE"))))
sys.exit(int(os.getenv("BACKEND_EXIT", "0")))
''')
        self.backend.chmod(0o755)
        overrides = self.bin / "overrides"
        overrides.mkdir()
        self.wrapper = overrides / "punktfunk-gamescope"
        source = WRAPPER.read_text()
        self.assertIn("backend=/usr/bin/punktfunk-gamescope", source)
        # Redirect only the absolute backend in the fixture; production bypasses PATH.
        self.wrapper.write_text(source.replace("backend=/usr/bin/punktfunk-gamescope",
                                              f"backend={self.backend}"))
        self.wrapper.chmod(0o755)
        (self.bin / "mangoapp").symlink_to("/bin/true")
        self.env = {"PATH": f"{overrides}:{self.bin}:/usr/bin:/bin", "HOME": str(self.bin), "MANGOHUD": "1",
                    "MANGOHUD_CONFIG": "position=top-right,fps_limit=30",
                    "MANGOHUD_FPS_LIMIT": "20"}

    def run_wrapper(self, args, extra_env=None):
        self.assertTrue(WRAPPER.exists(), "Punktfunk HUD integration is missing")
        result = subprocess.run(["punktfunk-gamescope", *args],
                                env=self.env | (extra_env or {}), text=True, capture_output=True, timeout=5)
        return result, json.loads(result.stdout)

    def test_launch_adds_single_hud_without_changing_pacing(self):
        args = ["--backend", "headless", "--steam", "-r", "120", "--framerate-limit", "120",
                "--pipewire-composite-external-overlay", "--", "steam", "argument with spaces"]
        result, launch = self.run_wrapper(args)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(launch["argv"], ["--mangoapp", *args])
        self.assertEqual(launch["mango"], "0")
        self.assertTrue(launch["config"].startswith("read_cfg,"))
        self.assertTrue(launch["config"].endswith("fps_limit=0"))
        self.assertIsNone(launch["limit"])
        self.assertEqual(launch["configfile"], str(self.bin / ".config/MangoHud/MangoHud.conf"))

    def test_hud_file_respects_xdg_and_explicit_override(self):
        _, launch = self.run_wrapper(["--steam", "--", "steam"], {"XDG_CONFIG_HOME": "/tmp/xdg"})
        self.assertEqual(launch["configfile"], "/tmp/xdg/MangoHud/MangoHud.conf")
        _, launch = self.run_wrapper(["--steam", "--", "steam"], {"MANGOHUD_CONFIGFILE": "/tmp/custom hud.conf"})
        self.assertEqual(launch["configfile"], "/tmp/custom hud.conf")

    def test_existing_mangoapp_is_not_duplicated(self):
        args = ["--mangoapp", "--", "steam"]
        _, launch = self.run_wrapper(args)
        self.assertEqual(launch["argv"], args)

    def test_child_options_do_not_affect_compositor_options(self):
        args = ["--", "game", "--version", "--help", "--mangoapp", "literal;$HOME"]
        _, launch = self.run_wrapper(args)
        self.assertEqual(launch["argv"], ["--mangoapp", *args])
        self.assertEqual(launch["mango"], "0")

    def test_probes_preserve_arguments_environment_and_status(self):
        for option in ("--version", "--help"):
            with self.subTest(option=option):
                result, launch = self.run_wrapper([option], {"BACKEND_EXIT": "7"})
                self.assertEqual(result.returncode, 7)
                self.assertEqual(launch["argv"], [option])
                self.assertEqual(launch["mango"], "1")
                self.assertEqual(launch["config"], self.env["MANGOHUD_CONFIG"])


if __name__ == "__main__":
    unittest.main()
