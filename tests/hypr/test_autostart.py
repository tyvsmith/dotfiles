"""Exercise startup identity after an app overwrites its initial environment."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class AutostartIdentity(unittest.TestCase):
    def test_startup_parent_survives_environment_rewrite(self):
        command = subprocess.check_output(
            ["lua", "-e", '''
                hl = {
                    on = function(_, callback) callback() end,
                    exec_cmd = function(command)
                        if command:match(" beeper$") then print(command) end
                    end,
                }
                dofile("home/dot_config/hypr/autostart.lua")
            '''], cwd=ROOT, text=True,
        ).strip()
        self.assertTrue(command)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            scripts = {
                "uwsm": '#!/bin/sh\nwhile [ "$1" != -- ]; do shift; done\nshift\nexec "$@"\n',
                "busctl": '#!/bin/sh\necho org.kde.StatusNotifierWatcher\n',
                "beeper": '#!/bin/sh\nexec python3 "$PROBE"\n',
            }
            for name, content in scripts.items():
                script = path / name
                script.write_text(content)
                script.chmod(0o755)
            helper = path / "wait-for-sni"
            helper.write_bytes((ROOT / "home/dot_local/bin/executable_wait-for-sni").read_bytes())
            helper.chmod(0o755)
            probe = path / "probe.py"
            probe.write_text('''import ctypes, os, sys
libc = ctypes.CDLL(None)
libc.getenv.restype = ctypes.c_void_p
marker = libc.getenv(b"HYPR_AUTOSTART")
if marker:
    ctypes.memset(marker, 0, 1)
print(os.getpid(), flush=True)
sys.stdin.readline()
sys.exit(23)
''')
            env = dict(os.environ, PATH=f"{path}:{os.defpath}", PROBE=str(probe))
            env.pop("HYPR_AUTOSTART", None)
            for launch, expected in [(command, "true"), ("wait-for-sni beeper", "false")]:
                with self.subTest(startup=expected):
                    app = subprocess.Popen(
                        ["sh", "-c", launch], env=env, text=True,
                        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                    )
                    try:
                        pid = int(app.stdout.readline())
                        self.assertNotIn(b"HYPR_AUTOSTART=1\0", Path(f"/proc/{pid}/environ").read_bytes())
                        result = subprocess.check_output(
                            ["lua", "-e", f'''
                                local launch = dofile("home/dot_config/hypr/launch_options.lua")
                                print(launch.is_startup({pid}))
                            '''], cwd=ROOT, text=True, env=env,
                        ).strip()
                        self.assertEqual(result, expected)
                    finally:
                        app.communicate("\n", timeout=5)
                    self.assertEqual(app.returncode, 23)


if __name__ == "__main__":
    unittest.main()
