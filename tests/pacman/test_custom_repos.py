"""Run the repository hook against disposable pacman configurations."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

HOOK = Path(__file__).resolve().parents[2] / 'home/dot_config/omarchy/hooks/pre-refresh-pacman.d/executable_10-custom-repos.sh'


class CustomReposTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        config = self.root / '.config/pacman'
        config.mkdir(parents=True)
        self.head = config / 'custom-repos-head.conf'
        self.tail = config / 'custom-repos-tail.conf'
        self.head.write_text('[cachyos]\nServer = custom\n')
        self.tail.write_text('[warpdotdev]\nServer = warp\n')
        self.conf = self.root / 'pacman.conf'
        self.script = self.root / 'hook'
        self.script.write_text(HOOK.read_text().replace('CONF=/etc/pacman.conf', f'CONF={self.conf}'))
        # Keep real install writes inside the fixture, without privilege elevation.
        sudo = self.root / 'sudo'
        sudo.write_text('#!/bin/bash\nexec "$@"\n')
        sudo.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.root), PATH=f'{self.root}:/usr/bin:/bin')

    def run_hook(self, *args):
        return subprocess.run(['bash', str(self.script), *args], env=self.env, capture_output=True, text=True)

    def start(self, path):
        return f'# >>> {path} (inlined by pre-refresh-pacman hook) >>>\n'

    def end(self, path):
        return f'# <<< {path} <<<\n'

    def test_repositories_survive_and_second_run_is_unchanged(self):
        self.conf.write_text('[options]\nColor\n[omarchy]\nServer = distro\n[core]\nServer = arch\n')
        self.assertEqual(self.run_hook('--check').returncode, 2)
        self.assertEqual(self.run_hook().returncode, 0)
        first = self.conf.read_text()
        self.assertEqual([x for x in first.splitlines() if x.startswith('[')],
                         ['[options]', '[cachyos]', '[omarchy]', '[core]', '[warpdotdev]'])
        self.assertEqual(self.run_hook('--check').returncode, 0)
        self.assertEqual(self.run_hook().returncode, 0)
        self.assertEqual(self.conf.read_text(), first)

    def test_head_precedes_repositories_with_or_without_omarchy(self):
        for repositories in ['[core]\n[omarchy]\n', '[core]\n', ' [omarchy] \n[core]\n']:
            with self.subTest(repositories=repositories):
                self.conf.write_text('[options]\nColor\n' + repositories)
                self.assertEqual(self.run_hook().returncode, 0)
                sections = [line.strip() for line in self.conf.read_text().splitlines()
                            if line.strip().startswith('[')]
                self.assertEqual(sections[0:2], ['[options]', '[cachyos]'])
                self.assertEqual(self.run_hook('--check').returncode, 0)

    def test_rejects_damaged_blocks_without_writing(self):
        cases = {
            'migration_reordered': self.start(self.head) + '[omarchy]\nServer = distro\n' + self.start(self.tail) + self.head.read_text() + self.end(self.head) + '[core]\n' + self.tail.read_text() + self.end(self.tail),
            'nested': self.start(self.head) + self.start(self.tail) + self.end(self.head) + self.end(self.tail),
            'unclosed': self.start(self.head) + self.head.read_text(),
            'unopened': self.end(self.head) + '[core]\n',
            'mismatched': self.start(self.head) + self.head.read_text() + self.end(self.tail),
            'distro_inside': self.start(self.head) + '[omarchy]\nServer = distro\n' + self.end(self.head),
        }
        for name, content in cases.items():
            for args in [(), ('--check',)]:
                with self.subTest(case=name, args=args):
                    self.conf.write_text(content)
                    result = self.run_hook(*args)
                    self.assertEqual(result.returncode, 1, result.stderr)
                    self.assertEqual(self.conf.read_text(), content)

    def test_policy_survives_all_channel_templates(self):
        policy = self.head.parent
        (policy / 'options.conf').write_text('IgnorePkg = held-package\n')
        (policy / 'arch-mirrorlist').write_text('Server = https://live.example/$repo/os/$arch\n')
        for channel in ('stable', 'rc', 'edge'):
            with self.subTest(channel=channel):
                self.conf.write_text('[options]\nArchitecture = x86_64\nColor\nIgnorePkg = obsolete\n'
                                     f'[omarchy]\nServer = https://pkgs.example/{channel}/$arch\n'
                                     '[core]\nInclude = /etc/pacman.d/mirrorlist\n'
                                     '[extra]\nServer = https://old.example/$repo/os/$arch\n'
                                     '[multilib]\nInclude = /etc/pacman.d/mirrorlist\n')
                result = self.run_hook()
                self.assertEqual(result.returncode, 0, result.stderr)
                rendered = self.conf.read_text()
                self.assertIn(f'https://pkgs.example/{channel}/$arch', rendered)
                self.assertEqual(rendered.count(f'Include = {policy / "arch-mirrorlist"}'), 3)
                resolved = subprocess.check_output(['pacman-conf', '--config', str(self.conf), '--repo', 'core', 'Server'], text=True)
                self.assertEqual(resolved.strip(), 'https://live.example/core/os/x86_64')
                self.assertNotIn('Include = /etc/pacman.d/mirrorlist', rendered)
                self.assertNotIn('obsolete', rendered)
                self.assertNotIn('old.example', rendered)
                self.assertEqual(rendered.count('IgnorePkg = held-package'), 1)
                self.assertEqual(self.run_hook('--check').returncode, 0)

    def test_render_does_not_write_input_or_use_sudo(self):
        self.conf.write_text('[options]\nColor\n[omarchy]\nServer = distro\n')
        before = self.conf.read_text()
        output = self.root / 'rendered.conf'
        result = self.run_hook('--render', str(self.conf), str(output))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.conf.read_text(), before)
        self.assertIn('[cachyos]', output.read_text())

    def test_adopts_existing_unmarked_repository(self):
        self.conf.write_text('[options]\nColor\n[omarchy]\nServer = distro\n'
                             '[warpdotdev]\nServer = warp\n')
        self.assertEqual(self.run_hook().returncode, 0)
        self.assertEqual(self.conf.read_text().count('[warpdotdev]'), 1)
        self.assertEqual(self.run_hook('--check').returncode, 0)


if __name__ == '__main__':
    unittest.main()
