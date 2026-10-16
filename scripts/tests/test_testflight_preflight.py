import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('testflight_preflight', Path(__file__).parents[1] / 'testflight_preflight.py')
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)


class TestFlightPreflightTests(unittest.TestCase):
    def test_consistent_targets(self):
        self.assertEqual(preflight.project_version(('MARKETING_VERSION = 1.4.0; CURRENT_PROJECT_VERSION = 13;\n') * 12), ('1.4.0', '13'))

    def test_mismatched_extension_rejected(self):
        with self.assertRaises(ValueError):
            preflight.project_version('MARKETING_VERSION = 1.4.0; CURRENT_PROJECT_VERSION = 13; MARKETING_VERSION = 1.3.1; CURRENT_PROJECT_VERSION = 12;')

    def test_missing_metadata_rejected(self):
        for text in ('', 'MARKETING_VERSION = 1.4.0;'):
            with self.assertRaises(ValueError):
                preflight.project_version(text)

    def test_invalid_numbers_rejected(self):
        for version, build in [('1.4', '13'), ('1.4.0', '0'), ('1.4.0', '13;evil'), ('1.4.0-beta', '13')]:
            with self.assertRaises(ValueError):
                preflight.project_version(f'MARKETING_VERSION = "{version}"; CURRENT_PROJECT_VERSION = "{build}";')

    def test_allowed_refs(self):
        preflight.validate_ref('workflow_dispatch', 'refs/heads/main', '1.4.0', '13', 'ios')
        for event in ('push', 'workflow_dispatch'):
            preflight.validate_ref(event, 'refs/tags/testflight/v1.4.0-13', '1.4.0', '13', 'both')

    def test_rejects_unreviewed_or_mismatched_requests(self):
        for event, ref, platform in [('push', 'refs/heads/main', 'both'), ('workflow_dispatch', 'refs/heads/feature', 'ios'), ('push', 'refs/tags/testflight/v1.4.0-12', 'both'), ('push', 'refs/tags/v1.4.0', 'both'), ('pull_request', 'refs/heads/main', 'both'), ('workflow_dispatch', 'refs/heads/main', 'shell')]:
            with self.assertRaises(ValueError):
                preflight.validate_ref(event, ref, '1.4.0', '13', platform)
