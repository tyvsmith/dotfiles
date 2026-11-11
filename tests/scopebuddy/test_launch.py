"""Evaluate launch configs and execute their commands without starting a desktop."""
import json
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "home/dot_config/scopebuddy"
KEYS = ["MANGOHUD", "MANGOHUD_CONFIG", "MANGOHUD_FPS_LIMIT",
        "MANGOHUD_CONFIGFILE", "NVPRESENT_ENABLE_SMOOTH_MOTION", "HYPR_HDR", "HYPR_WORKSPACE",
        "PROTON_DLSS_UPGRADE", "PROTON_LOG_DIR", "PROTON_ENABLE_WAYLAND", "DXVK_HDR",
        "VKD3D_CONFIG", "TRIAL_VALUE", "TRIAL_EMPTY"]
RECORDER = """#!/usr/bin/env python3
import json, os, sys
print(json.dumps(dict(argv=sys.argv[1:], env={k: os.environ.get(k) for k in %r})), flush=True)
""" % KEYS


class LaunchTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root / "scopebuddy"
        shutil.copytree(SOURCE, self.config)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = {"HOME": str(self.root), "PATH": f"{self.bin}:/usr/bin:/bin",
                    "SCB_CONFIGDIR": str(self.config), "SCB_APPID": "123",
                    "HYPRLAND_INSTANCE_SIGNATURE": "test"}
        self.write_bin("record", RECORDER)
        self.write_bin("gamescope", RECORDER + '''
import subprocess
sys.exit(subprocess.call(sys.argv[sys.argv.index("--") + 1:]))
''')
        for name in ("game-performance", "gamemoderun"):
            self.write_bin(name, '#!/bin/sh\nexec "$@"\n')
        self.display()

    def write_bin(self, name, body):
        path = self.bin / name
        path.write_text(body)
        path.chmod(0o755)

    def display(self, stream=False):
        monitors = [dict(name="PF-1" if stream else "DP-1", focused=True,
                         disabled=False, width=5120, height=2160,
                         refreshRate=120 if stream else 165.0)]
        self.write_bin("hyprctl", "#!/bin/sh\ncat <<'JSON'\n" + json.dumps(monitors) + "\nJSON\n")
        self.write_bin("punktfunk-host", '#!/bin/sh\nprintf \'{"data":{"active_sessions":1}}\\n\'\n')

    def launch(self, config="", extra_env=None, expect_ok=True):
        (self.config / "games/test.conf").write_text("APP_ID=123\n" + config)
        env = self.env | (extra_env or {}) | {"GAME_COMMAND": shlex.join(["record", "argument with spaces", "literal;$HOME"])}
        result = subprocess.run(["bash", "-c", '''
command="$GAME_COMMAND"
source "$SCB_CONFIGDIR/scb.conf" || exit
export CAP="$fps_cap" ARGS="$SCB_GAMESCOPE_ARGS" MODE="$mode"
python3 -c 'import json,os; print(json.dumps({k:os.environ.get(k) for k in ["CAP","ARGS","MODE"] + ''' + json.dumps(KEYS) + '''}))' || exit
pre_command() { :; }
if [[ $mode == gamescope ]]; then
    eval "gamescope $SCB_GAMESCOPE_ARGS -- $command"
else
    eval "$command"
fi
'''], env=env, text=True, capture_output=True)
        self.stderr = result.stderr
        if not expect_ok:
            self.assertNotEqual(result.returncode, 0, result.stdout)
            return result
        self.assertEqual(result.returncode, 0, result.stderr)
        records = [json.loads(line) for line in result.stdout.splitlines()]
        self.compositor = records[1] if len(records) == 3 else None
        return records[0], records[-1]

    def test_nested_has_one_hud_and_game_only_smooth_motion(self):
        parent, child = self.launch()
        self.assertEqual(parent["MANGOHUD"], "0")
        self.assertIsNone(parent["NVPRESENT_ENABLE_SMOOTH_MOTION"])
        self.assertIn("-r 165", parent["ARGS"])
        self.assertNotIn("--framerate-limit", parent["ARGS"])
        self.assertEqual(parent["ARGS"].count("--mangoapp"), 1)
        self.assertEqual(self.compositor["env"]["MANGOHUD"], "0")
        self.assertIsNone(self.compositor["env"]["NVPRESENT_ENABLE_SMOOTH_MOTION"])
        self.assertEqual(child["env"]["MANGOHUD"], "1")
        self.assertIsNone(child["env"]["NVPRESENT_ENABLE_SMOOTH_MOTION"])
        self.assertEqual(child["argv"][0], "argument with spaces")
        self.assertEqual(child["argv"][1], "literal;$HOME")

    def test_native_reads_appearance_and_owns_cap(self):
        parent, child = self.launch("mode=native\n", {"MANGOHUD_CONFIG": "position=top-right", "MANGOHUD_FPS_LIMIT": "30"})
        self.assertEqual(parent["ARGS"], "")
        self.assertEqual(child["env"]["MANGOHUD"], "1")
        self.assertEqual(child["env"]["MANGOHUD_CONFIG"], "read_cfg,position=top-right,fps_limit=161")
        self.assertIsNone(child["env"]["MANGOHUD_FPS_LIMIT"])

    def test_game_environment_is_quoted_and_later_values_win(self):
        value = "spaces 'quotes' \"double\" ; $HOME $(touch bad) `touch bad`\nsecond line"
        config = ("game_env TRIAL_VALUE first\n" +
                  "game_env TRIAL_VALUE " + shlex.quote(value) + "\n" +
                  "game_env TRIAL_EMPTY ''\n")
        parent, child = self.launch(config, {"TRIAL_VALUE": "inherited"})
        self.assertIsNone(parent["TRIAL_VALUE"])
        self.assertIsNone(self.compositor["env"]["TRIAL_VALUE"])
        self.assertEqual(child["env"]["TRIAL_VALUE"], value)
        self.assertEqual(child["env"]["TRIAL_EMPTY"], "")

    def test_game_defaults_preserve_inherited_and_explicit_overrides(self):
        _, child = self.launch("game_env NVPRESENT_ENABLE_SMOOTH_MOTION 1\n", {"NVPRESENT_ENABLE_SMOOTH_MOTION": "0"})
        self.assertEqual(child["env"]["NVPRESENT_ENABLE_SMOOTH_MOTION"], "1")
        parent, child = self.launch("mode=native\ngame_env DXVK_HDR 0\n", {"PROTON_ENABLE_WAYLAND": "0"})
        self.assertEqual(child["env"]["DXVK_HDR"], "0")
        self.assertEqual(child["env"]["PROTON_ENABLE_WAYLAND"], "0")
        self.assertIsNone(parent["PROTON_ENABLE_WAYLAND"])

    def test_proton_and_driver_settings_do_not_reach_compositor(self):
        parent, child = self.launch("game_env VKD3D_CONFIG descriptor_heap\n")
        for key in ("PROTON_DLSS_UPGRADE", "PROTON_LOG_DIR", "VKD3D_CONFIG"):
            self.assertIsNone(parent[key])
            self.assertIsNone(self.compositor["env"][key])
            self.assertIsNotNone(child["env"][key])

    def test_game_environment_rejects_invalid_names_and_arity(self):
        for config in ("game_env 'BAD=NAME' value", "game_env ONE", "game_env ONE two three"):
            with self.subTest(config=config):
                self.launch(config + " && exit 99\nstatus=$?\n[[ $status == 1 ]] || exit 99\n")

    def test_game_only_mangohud_opt_out_is_respected_by_policy(self):
        _, child = self.launch("mode=native\ngame_env MANGOHUD 0\n")
        self.assertEqual(child["env"]["MANGOHUD"], "0")
        self.assertIn("fps_limiter=game", self.stderr)

    def test_stream_nested_targets_client_rate(self):
        self.display(stream=True)
        parent, child = self.launch()
        self.assertEqual(parent["CAP"], "120")
        self.assertNotIn("--framerate-limit", parent["ARGS"])
        self.assertIn("fps_limit=120", child["env"]["MANGOHUD_CONFIG"])
        self.assertEqual(parent["HYPR_HDR"], "0")

    def test_overrides_precede_default_cap(self):
        parent, _ = self.launch("refresh=144\nfps_margin=3\n")
        self.assertEqual(parent["CAP"], "141")

    def test_profile_lookup_does_not_require_ripgrep(self):
        self.write_bin("rg", "#!/bin/sh\nexit 127\n")
        parent, _ = self.launch("mode=native\nrefresh=144\nfps_margin=3\n")
        self.assertEqual(parent["MODE"], "native")
        self.assertEqual(parent["CAP"], "141")

    def test_zero_cap_disables_external_limiter(self):
        parent, _ = self.launch("fps_cap=0\n")
        self.assertIn("-r 165", parent["ARGS"])
        self.assertNotIn("--framerate-limit", parent["ARGS"])
        _, child = self.launch("mode=native\nfps_cap=0\n")
        self.assertTrue(child["env"]["MANGOHUD_CONFIG"].endswith("fps_limit=0"))

    def test_explicit_cap_and_smooth_motion_opt_out(self):
        parent, child = self.launch("fps_cap=90\n", {"NVPRESENT_ENABLE_SMOOTH_MOTION": "0"})
        self.assertEqual(parent["CAP"], "90")
        self.assertEqual(child["env"]["NVPRESENT_ENABLE_SMOOTH_MOTION"], "0")

    def test_default_hidden_limiter_has_no_interactive_controls(self):
        parent, child = self.launch()
        self.assertIn("-r 165", parent["ARGS"])
        self.assertNotIn("--framerate-limit", parent["ARGS"])
        self.assertEqual(child["env"]["MANGOHUD"], "1")
        options = child["env"]["MANGOHUD_CONFIG"].split(",")
        self.assertIn("no_display", options)
        self.assertIn("fps_limit=161", options)
        for key in ("toggle_hud", "toggle_preset", "toggle_fps_limit", "toggle_logging", "reload_cfg"):
            self.assertIn(key + "=", options)

    def test_gamescope_limiter_requires_explicit_selection(self):
        parent, child = self.launch("fps_limiter=gamescope\n")
        self.assertIn("-r 161", parent["ARGS"])
        self.assertIn("--framerate-limit 161", parent["ARGS"])
        self.assertEqual(child["env"]["MANGOHUD"], "0")

    def test_native_injection_opt_out_reports_missing_limiter(self):
        _, child = self.launch("mode=native\nexport MANGOHUD=0\n")
        self.assertEqual(child["env"]["MANGOHUD"], "0")
        self.assertIn("fps_limiter=game", self.stderr)
        _, child = self.launch("mode=native\nexport MANGOHUD=0\nfps_limiter=game\n")
        self.assertEqual(child["env"]["MANGOHUD"], "0")

    def test_game_limiter_does_not_also_cap_in_mangohud(self):
        _, child = self.launch("mode=native\nfps_limiter=game\n")
        self.assertTrue(child["env"]["MANGOHUD_CONFIG"].endswith("fps_limit=0"))

    def test_invalid_caps_and_limiters_fail_before_launch(self):
        for config in ("fps_cap=-1", "fps_cap=garbage", "fps_cap=60.5",
                       'fps_cap=""',
                       "fps_limiter=typo", "mode=native\nfps_limiter=gamescope",
                       "fps_limiter=mangohud\nexport MANGOHUD=0"):
            with self.subTest(config=config):
                self.launch(config + "\n", expect_ok=False)

    def test_full_gamescope_override_is_preserved(self):
        args = "-w 1920 -h 1080 -r 60 --steam --mangoapp --framerate-limit 60"
        parent, _ = self.launch(f'SCB_GAMESCOPE_ARGS="{args}"\n')
        self.assertEqual(parent["ARGS"], args)
        self.assertEqual(self.compositor["env"]["MANGOHUD_CONFIGFILE"], str(self.root / ".config/MangoHud/MangoHud.conf"))

    def test_explicit_hud_file_survives_mode_policy(self):
        _, child = self.launch(extra_env={"MANGOHUD_CONFIGFILE": "/tmp/custom hud.conf"})
        self.assertEqual(child["env"]["MANGOHUD_CONFIGFILE"], "/tmp/custom hud.conf")

    def test_existing_session_keeps_outer_policy_without_metadata(self):
        self.write_bin("xrandr", "#!/bin/sh\nexit 1\n")
        parent, child = self.launch(extra_env={"XDG_CURRENT_DESKTOP": "gamescope", "MANGOHUD_CONFIG": "read_cfg,fps_limit=0", "HYPR_HDR": "0"})
        self.assertEqual(parent["MODE"], "session")
        self.assertEqual(parent["MANGOHUD_CONFIG"], "read_cfg,fps_limit=0")
        self.assertEqual(child["env"]["HYPR_HDR"], "0")

    def test_existing_session_overrides_queued_game_hud(self):
        _, child = self.launch("game_env MANGOHUD 1\ngame_env MANGOHUD_CONFIG fps_limit=30\n",
                               {"XDG_CURRENT_DESKTOP": "gamescope"})
        self.assertEqual(child["env"]["MANGOHUD"], "0")


if __name__ == "__main__":
    unittest.main()
