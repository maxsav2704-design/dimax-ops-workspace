import importlib.util
from pathlib import Path
import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location('restore_browser_runner', Path(__file__).with_name('run.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class SafetyTests(unittest.TestCase):
    def setUp(self):
        self.env = {'GITHUB_ACTIONS': 'true', 'DIMAX_RESTORE_BROWSER': 'synthetic-only'}
        self.refs = [runner.BACKEND_REV, runner.FRONTEND_REV]
        self.images = ['sha256:' + str(i) * 64 for i in (1, 2, 3)]

    def test_known_isolated_inputs(self):
        runner.validate_inputs(self.env, self.refs, self.images, 4096)

    def test_local_host_and_missing_opt_in_rejected(self):
        for env in ({}, {'GITHUB_ACTIONS': 'true'}, {'DIMAX_RESTORE_BROWSER': 'synthetic-only'}):
            with self.subTest(env=env), self.assertRaises(ValueError):
                runner.validate_inputs(env, self.refs, self.images, 8192)

    def test_other_revisions_rejected(self):
        for refs in (['main', runner.FRONTEND_REV], [runner.BACKEND_REV, 'HEAD'], []):
            with self.subTest(refs=refs), self.assertRaises(ValueError):
                runner.validate_inputs(self.env, refs, self.images, 8192)

    def test_mutable_or_missing_images_rejected(self):
        for images in (['postgres:latest', *self.images[1:]], self.images[:2], ['sha256:123'] * 3):
            with self.subTest(images=images), self.assertRaises(ValueError):
                runner.validate_inputs(self.env, self.refs, images, 8192)

    def test_low_memory_rejected_without_touching_services(self):
        with self.assertRaises(ValueError):
            runner.validate_inputs(self.env, self.refs, self.images, 508)

    def test_database_readiness_waits_for_tcp_not_initdb_socket(self):
        docker = Mock(side_effect=[SimpleNamespace(returncode=1), SimpleNamespace(returncode=0)])
        with patch.object(runner.time, 'sleep') as sleep:
            runner.wait_database(docker, 'owned-test-db', 'dimax_full_restored')
        self.assertEqual(docker.call_count, 2)
        docker.assert_called_with('exec', 'owned-test-db', 'pg_isready', '-h', '127.0.0.1',
                                  '-U', 'postgres', '-d', 'dimax_full_restored', check=False)
        sleep.assert_called_once_with(1)

    def test_database_readiness_has_bounded_timeout(self):
        docker = Mock(return_value=SimpleNamespace(returncode=1))
        with patch.object(runner.time, 'sleep'), self.assertRaises(RuntimeError):
            runner.wait_database(docker, 'owned-test-db', 'dimax_full_restored')
        self.assertEqual(docker.call_count, 60)


if __name__ == '__main__':
    unittest.main()
