#!/usr/bin/env python3
"""Check source isolation without applying files, running hooks, or fetching secrets."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]
PROFILES = ('arch-desktop', 'debian-server', 'devpod', 'macos-work', 'silverblue')


class SourceRootTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-source-root-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'repo'
        self.source.mkdir()
        shutil.copytree(REPO / 'home', self.source / 'home', symlinks=True)
        shutil.copytree(REPO / 'scripts', self.source / 'scripts', symlinks=True)
        shutil.copy2(REPO / '.chezmoiroot', self.source)
        self.config = self.root / 'config.toml'
        self.config.write_text('')
        self.dest = self.root / 'destination'
        self.dest.mkdir()

    def chezmoi(self, *args, profile='debian-server', overrides=None):
        command = [
            'chezmoi', '--source', str(self.source), '--destination', str(self.dest),
            '--config', str(self.config), '--persistent-state', str(self.root / 'state.db'),
            '--cache', str(self.root / 'cache'), '--no-tty',
        ]
        if overrides:
            command += ['--override-data', json.dumps(overrides)]
        result = subprocess.run(command + list(args), check=True, capture_output=True,
                                text=True, env=os.environ | {'DOTFILES_PROFILE': profile})
        return result.stdout

    def test_worktree_data_and_templates_are_outside_source(self):
        self.chezmoi('init')
        template = '{{ .profiles | toJson }}'
        expected = self.chezmoi('execute-template', template)
        for directory in ('.claude/worktrees/probe', '.worktrees/probe'):
            nested = self.source / directory
            (nested / '.chezmoidata').mkdir(parents=True)
            (nested / '.chezmoidata/profiles.yaml').write_text('profiles: poisoned\n')
            (nested / '.chezmoitemplates').mkdir()
            (nested / '.chezmoitemplates/broken').write_text('{{ invalid template }}')
        self.assertEqual(self.chezmoi('execute-template', template), expected)
        self.assertEqual(self.chezmoi('source-path').strip(), str(self.source / 'home'))

    def test_secret_helpers_only_process_home(self):
        key = subprocess.run(['age-keygen'], capture_output=True, text=True, check=True).stdout
        recipient = subprocess.run(['age-keygen', '-y'], input=key, capture_output=True,
                                   text=True, check=True).stdout
        for name in ('.age-public-key', '.age-public-key-work'):
            (self.source / 'home' / name).write_text(recipient)
        # Remove real ciphertext from this disposable copy before using a test key.
        for encrypted in (self.source / 'home').rglob('encrypted_*.age'):
            encrypted.unlink()
        plaintext = self.source / 'home/decrypted_probe'
        plaintext.write_text('round-trip fixture\n')
        nested = self.source / '.claude/worktrees/probe'
        nested.mkdir(parents=True)
        (nested / 'decrypted_probe').write_text('must stay outside the scan\n')
        (nested / 'encrypted_invalid.age').write_text('not ciphertext\n')
        subprocess.run(['bash', str(self.source / 'scripts/encrypt-secrets.sh')],
                       capture_output=True, check=True)
        self.assertTrue((self.source / 'home/encrypted_probe.age').exists())
        self.assertFalse((nested / 'encrypted_probe.age').exists())
        plaintext.unlink()
        subprocess.run(['bash', str(self.source / 'scripts/decrypt-secrets.sh')],
                       capture_output=True, check=True, env=os.environ | {'AGE_KEY': key})
        self.assertEqual(plaintext.read_text(), 'round-trip fixture\n')
        self.assertFalse((nested / 'decrypted_invalid').exists())

    def test_all_profiles_render_and_scripts_find_libraries(self):
        for profile in PROFILES:
            with self.subTest(profile=profile):
                self.config.write_text('')
                self.chezmoi('init', profile=profile)
                # Keep secrets and external repositories out of this local render test.
                overrides = {'decrypt': False, 'backup': False}
                if profile == 'macos-work':
                    overrides['chezmoi'] = {'os': 'darwin'}
                targets = json.loads(self.chezmoi('dump', '--exclude', 'externals',
                                                '--format', 'json', overrides=overrides))
                self.assertIn('.config/fish/config.fish', targets)
                self.assertIn('.agents/AGENTS.md', targets)
                self.assertIn('.claude/CLAUDE.md', targets)
                self.assertIn('.codex/AGENTS.md', targets)
                self.assertFalse({'scripts', 'tests', 'README.md', 'home'} & targets.keys())
                for entry in targets.values():
                    if entry['type'] != 'script':
                        continue
                    content = entry['contents']
                    subprocess.run(['bash', '-n'], input=content, text=True, check=True)
                    for line in content.splitlines():
                        if line.startswith('source ') and 'scripts/lib/' in line:
                            subprocess.run(['bash', '-eu', '-c', line], check=True,
                                           env=os.environ | {
                                               'CHEZMOI_SOURCE_DIR': str(self.source / 'home')})
                if profile == 'devpod':
                    bootstrap = targets['00-devpod-bootstrap.sh']['contents']
                    fetch = next(line for line in bootstrap.splitlines() if line.startswith('FETCH='))
                    subprocess.run(['bash', '-eu', '-c', fetch + '\ntest -f "$FETCH"'],
                                   check=True, env=os.environ | {
                                       'CHEZMOI_SOURCE_DIR': str(self.source / 'home')})


if __name__ == '__main__':
    unittest.main()
