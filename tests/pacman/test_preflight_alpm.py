"""Pin the real pacman preparation contract without root or network access."""
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest


HELPER = Path(__file__).resolve().parents[2] / 'home/dot_local/lib/pacman-preflight.py'


@unittest.skipUnless(shutil.which('pacman') and shutil.which('fakeroot'),
                     'requires pacman and fakeroot')
class PreflightAlpmTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='pacman-preflight-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.db = self.root / 'db'
        (self.db / 'local').mkdir(parents=True)
        (self.db / 'sync').mkdir()
        (self.db / 'local/ALPM_DB_VERSION').write_text('9\n')
        (self.root / 'cache').mkdir()
        (self.root / 'system').mkdir()
        (self.root / 'packages').mkdir()
        self.conf = self.root / 'pacman.conf'
        self.conf.write_text(
            '[options]\nArchitecture = x86_64\nSigLevel = Never\n'
            f'DBPath = {self.db}\nCacheDir = {self.root}/cache\n'
            f'RootDir = {self.root}/system\nLogFile = {self.root}/pacman.log\n'
            '[fixture]\n'
            f'Server = file://{self.root}/packages\n')

    @staticmethod
    def description(name, version, **fields):
        data = dict(NAME=name, VERSION=version, DESC='test fixture', ARCH='x86_64',
                    **fields)
        return ''.join(f'%{key}%\n{value}\n\n' for key, value in data.items())

    def installed(self, name, version='1-1', **fields):
        directory = self.db / 'local' / f'{name}-{version}'
        directory.mkdir()
        (directory / 'desc').write_text(self.description(name, version, **fields))
        (directory / 'files').write_text('%FILES%\n\n')

    def repository(self, *packages):
        with tarfile.open(self.db / 'sync/fixture.db', 'w:gz') as archive:
            for name, version, fields in packages:
                contents = self.description(
                    name, version, FILENAME=f'{name}-{version}-x86_64.pkg.tar.zst',
                    CSIZE='1', ISIZE='1', **fields).encode()
                member = tarfile.TarInfo(f'{name}-{version}/desc')
                member.size = len(contents)
                archive.addfile(member, io.BytesIO(contents))

    def prepare(self, *args, answers=None, expect_download=False, helper=False):
        before = {str(p.relative_to(self.db)): p.read_bytes()
                  for p in (self.db / 'local').rglob('*') if p.is_file()}
        command = ['fakeroot', '--', 'pacman', '--config', str(self.conf),
                   '-Suu', *args, '--confirm']
        if helper:
            command = [sys.executable, str(HELPER), *command]
        result = subprocess.run(
            command,
            stdin=subprocess.DEVNULL if answers is None else None,
            input=answers, capture_output=True, text=True,
            env=dict(os.environ, LC_ALL='C'), timeout=10)
        after = {str(p.relative_to(self.db)): p.read_bytes()
                 for p in (self.db / 'local').rglob('*') if p.is_file()}
        self.assertEqual(before, after, result.stdout + result.stderr)
        self.assertEqual(list((self.root / 'cache').iterdir()), [])
        self.assertEqual(list((self.root / 'system').iterdir()), [])
        if not expect_download:
            self.assertNotIn('Retrieving packages', result.stdout + result.stderr)
        return result, result.stdout + result.stderr

    def test_eof_declines_successfully_prepared_upgrade(self):
        self.installed('fixture-app')
        self.repository(('fixture-app', '2-1', {}))
        result, output = self.prepare()
        self.assertIn('Proceed with installation? [Y/n]', output)
        self.assertNotIn('error:', output)

    def test_package_conflict_fails_before_install_prompt(self):
        self.installed('fixture-old')
        self.repository(('fixture-new', '1-1', {'CONFLICTS': 'fixture-old'}))
        result, output = self.prepare('fixture-new')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('conflicting dependencies', output)
        self.assertNotIn('Proceed with installation?', output)

    def test_exact_dependency_blocks_downgrade(self):
        self.installed('fixture-compositor', '2-1')
        self.installed('fixture-plugin', DEPENDS='fixture-compositor=2-1')
        self.repository(('fixture-compositor', '1-1', {}))
        result, output = self.prepare()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('breaks dependency', output)
        self.assertIn('fixture-compositor=2-1', output)
        self.assertNotIn('Proceed with installation?', output)

    def test_explicit_answers_prepare_swap_but_decline_install(self):
        self.installed('fixture-dev')
        self.repository(('fixture-release', '1-1', {'CONFLICTS': 'fixture-dev'}))
        result, output = self.prepare('fixture-release', answers='y\nn\n')
        self.assertIn('Proceed with installation? [Y/n]', output)
        self.assertIn('fixture-dev', output)
        self.assertNotIn('error:', output)

    def test_ask_four_overrides_confirm_and_is_unsafe_for_preflight(self):
        self.installed('fixture-dev')
        self.repository(('fixture-release', '1-1', {'CONFLICTS': 'fixture-dev'}))
        # --ask forces noconfirm even when --confirm follows it. Missing
        # archives under file:// keep this contract test offline and harmless.
        result, output = self.prepare('--ask', '4', 'fixture-release',
                                      expect_download=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Retrieving packages', output)
        self.assertIn('failed retrieving file', output)

    def test_helper_accepts_prepared_upgrade_without_installing(self):
        self.installed('fixture-app')
        self.repository(('fixture-app', '2-1', {}))
        result, output = self.prepare(helper=True)
        self.assertEqual(result.returncode, 0, output)
        self.assertIn('Proceed with installation?', output)

    def test_helper_accepts_no_changes(self):
        self.installed('fixture-app')
        self.repository(('fixture-app', '1-1', {}))
        result, output = self.prepare(helper=True)
        self.assertEqual(result.returncode, 0, output)
        self.assertIn('there is nothing to do', output)

    def test_helper_handles_only_known_release_dev_swap(self):
        self.installed('omarchy-dev')
        self.installed('omarchy-settings-dev')
        self.repository(
            ('omarchy', '1-1', {'CONFLICTS': 'omarchy-dev'}),
            ('omarchy-settings', '1-1', {'CONFLICTS': 'omarchy-settings-dev'}))
        result, output = self.prepare('omarchy', 'omarchy-settings', helper=True)
        self.assertEqual(result.returncode, 0, output)
        self.assertIn('Proceed with installation?', output)

    def test_helper_refuses_unknown_removal_prompt(self):
        self.installed('fixture-old')
        self.repository(('fixture-new', '1-1', {'CONFLICTS': 'fixture-old'}))
        result, output = self.prepare('fixture-new', helper=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('Proceed with installation?', output)

    def test_helper_refuses_package_with_allowed_name_prefix(self):
        self.installed('omarchy-dev')
        self.repository(('omarchy-addon', '1-1', {'CONFLICTS': 'omarchy-dev'}))
        result, output = self.prepare('omarchy-addon', helper=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('Proceed with installation?', output)

    def test_helper_refuses_exact_dependency_breakage(self):
        self.installed('fixture-compositor', '2-1')
        self.installed('fixture-plugin', DEPENDS='fixture-compositor=2-1')
        self.repository(('fixture-compositor', '1-1', {}))
        result, output = self.prepare(helper=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('breaks dependency', output)
        self.assertNotIn('Proceed with installation?', output)


if __name__ == '__main__':
    unittest.main()
