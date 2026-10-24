import importlib.util
from pathlib import Path
import unittest

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


if __name__ == '__main__':
    unittest.main()
