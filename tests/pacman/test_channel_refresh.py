"""Channel preflight must fail before touching the system configuration."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

WRAPPER = Path(__file__).resolve().parents[2] / 'home/dot_local/share/overrides/bin/executable_omarchy-refresh-pacman'


class RefreshTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        hooks = self.root / '.config/omarchy/hooks/pre-refresh-pacman.d'
        hooks.mkdir(parents=True)
        hook = hooks / '10-custom-repos.sh'
        hook.write_text('#!/bin/bash\ncp "$2" "$3"\n')
        hook.chmod(0o755)
        policy = self.root / '.config/pacman'
        policy.mkdir()
        for name in ('custom-repos-head.conf', 'custom-repos-tail.conf', 'options.conf', 'arch-mirrorlist'):
            (policy / name).write_text('# fixture\n')
        lib = self.root / '.local/lib'
        lib.mkdir(parents=True)
        (lib / 'pacman-preflight.py').write_text((WRAPPER.parents[3] / 'lib/pacman-preflight.py').read_text())
        self.log = self.root / 'calls'
        self.env = dict(os.environ, HOME=str(self.root), PATH=f'{self.bin}:/usr/bin:/bin',
                        OMARCHY_PATH=str(self.root), CALLS=str(self.log))
        self.command('omarchy-apply-pacman', 'printf "[options]\\n[omarchy]\\nServer = https://example/$2\\n" > "$3/pacman.conf"\nprintf "Server = https://arch.example\\n" > "$3/mirrorlist"')
        self.command('pacman-conf', 'echo /var/lib/pacman')
        self.command('fakeroot', 'shift; exec "$@"')
        self.command('pacman', 'if [[ " $* " == *" -Sy "* ]]; then echo sync >> "$CALLS"; exit "${SYNC_STATUS:-0}"; fi\n'
                     'echo resolve >> "$CALLS"; if [[ ${RESOLVE_STATUS:-0} == 1 ]]; then echo "error: dependencies"; exit 1; fi\n'
                     'printf ":: Proceed with installation? [Y/n] "; read -r answer; [[ $answer == n ]] || exit 99; exit 1')
        self.command('sudo', 'echo sudo >> "$CALLS"; exit 1')

    def command(self, name, code):
        f = self.bin / name
        f.write_text('#!/bin/bash\n' + code + '\n')
        f.chmod(0o755)

    def run_refresh(self, *args):
        return subprocess.run(['bash', str(WRAPPER), *args], env=self.env, text=True, capture_output=True)

    def test_dependency_failure_never_escalates(self):
        self.env['RESOLVE_STATUS'] = '1'
        result = self.run_refresh('stable')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.log.read_text().splitlines(), ['sync', 'resolve'])

    def test_preview_never_escalates(self):
        result = self.run_refresh('--preview', 'rc')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), ['sync', 'resolve', 'resolve'])

    def test_sync_failure_stops_before_resolution(self):
        self.env['SYNC_STATUS'] = '1'
        self.assertNotEqual(self.run_refresh('stable').returncode, 0)
        self.assertEqual(self.log.read_text().splitlines(), ['sync'])

    def test_unstaged_hook_blocks_switch(self):
        other = self.root / '.config/omarchy/hooks/pre-refresh-pacman.d/20-other.sh'
        other.write_text('exit 0\n')
        self.assertNotEqual(self.run_refresh('stable').returncode, 0)
        self.assertFalse(self.log.exists())
