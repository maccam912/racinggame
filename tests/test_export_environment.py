import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from export_environment import HEADER, temporary_configuration


class ExportEnvironmentTests(unittest.TestCase):
    def test_failed_export_restores_only_owned_keys_and_environment(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'editor_settings.tres'
            path.write_text(HEADER+'export/android/java_sdk_path="previous"\neditor/unrelated=1\n')
            path.chmod(0o600)
            with patch.dict(os.environ,{'PACIFIC_TEST_ENV':'previous'},clear=False):
                with self.assertRaises(RuntimeError):
                    with temporary_configuration(path,{'export/android/java_sdk_path':'temporary','export/android/debug_keystore_pass':'test-only'}, {'PACIFIC_TEST_ENV':'temporary'}):
                        self.assertIn('java_sdk_path="temporary"',path.read_text())
                        self.assertEqual(os.environ['PACIFIC_TEST_ENV'],'temporary')
                        path.write_text(path.read_text().replace('editor/unrelated=1','editor/unrelated=2')+'editor/new_setting=true\n')
                        raise RuntimeError('export failed')
                self.assertEqual(os.environ['PACIFIC_TEST_ENV'],'previous')
            text = path.read_text()
            self.assertIn('java_sdk_path="previous"',text)
            self.assertNotIn('debug_keystore_pass=',text)
            self.assertIn('editor/unrelated=2',text)
            self.assertIn('editor/new_setting=true',text)
            self.assertEqual(stat.S_IMODE(path.stat().st_mode),0o600)

    def test_missing_file_and_environment_do_not_leave_overrides(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'settings.tres'
            with patch.dict(os.environ,{},clear=True):
                with temporary_configuration(path,{'export/android/path':'x'}, {'PACIFIC_TEST_ENV':'x'}):
                    self.assertTrue(path.exists())
                self.assertFalse(path.exists())
                self.assertNotIn('PACIFIC_TEST_ENV',os.environ)
                with temporary_configuration(path,{'export/android/path':'x'}, {}):
                    path.write_text(path.read_text()+'editor/new_setting=true\n')
                self.assertIn('editor/new_setting=true',path.read_text())
                self.assertNotIn('export/android/path=',path.read_text())

    def test_subresources_crlf_and_literal_path_characters(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'settings.tres'
            path.write_bytes((HEADER.replace('\n','\r\n')+'export/android/path="old"\r\n\r\n[sub_resource type="Resource" id="x"]\r\nvalue=1\r\n').encode())
            with temporary_configuration(path,{'export/android/path':'C:\\Path\\with "quotes"'},{}):
                self.assertIn('C:\\\\Path\\\\with \\"quotes\\"',path.read_text())
            self.assertIn(b'export/android/path="old"\r\n',path.read_bytes())
            self.assertIn(b'[sub_resource type="Resource" id="x"]\r\nvalue=1',path.read_bytes())
