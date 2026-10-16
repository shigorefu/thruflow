import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'platform_review.py'
spec = importlib.util.spec_from_file_location('platform_review', SCRIPT)
review = importlib.util.module_from_spec(spec)
spec.loader.exec_module(review)


class RoutingTests(unittest.TestCase):
    def setUp(self):
        self.mapping = review.load_map()

    def ids(self, paths):
        return {group['id'] for group in review.classify(paths, self.mapping)[0]}

    def test_known_features_and_union(self):
        self.assertEqual(self.ids(['ThruFlow/Platforms/iOS/Features/Settings/IOSSettingsView.swift']), {'settings'})
        self.assertEqual(self.ids(['ThruFlow/Platforms/macOS/Features/Todos/TodoFormView.swift',
                                   'ThruFlow/Platforms/iOS/Features/History/IOSHistoryView.swift']), {'tasks', 'history'})

    def test_unknown_shared_app_and_test_paths_review_every_group(self):
        all_ids = {group['id'] for group in self.mapping['groups']}
        for path in ['ThruFlow/Shared/New.swift', 'ThruFlow/Platforms/iOS/New.swift',
                     'ThruFlowTests/NewTests.swift', 'ThruFlow/Localisation/Localizable.xcstrings',
                     'ThruFlow.xcodeproj/project.pbxproj']:
            with self.subTest(path=path):
                self.assertEqual(self.ids([path]), all_ids)
                self.assertIn('Watch', review.render([path], self.mapping))

    def test_docs_and_tooling_are_not_runtime_approvals(self):
        self.assertEqual(self.ids(['docs/ARCHITECTURE.md', 'AGENTS.md', 'scripts/platform_review.py']), set())
        self.assertIn('not a parity approval', review.render([], self.mapping))

    def test_deleted_paths_do_not_need_to_exist(self):
        self.assertEqual(self.ids(['ThruFlow/Platforms/macOS/Features/Settings/Removed.swift']), {'settings'})

    def test_map_paths_exist(self):
        self.assertEqual(review.validate_map(self.mapping), [])

    def test_invalid_map_path_rejected(self):
        self.mapping['groups'][0]['review'].append('../outside')
        self.assertTrue(review.validate_map(self.mapping))

    def test_report_escapes_path_markup(self):
        self.assertIn('&lt;input&gt;', review.render(['<input>'], self.mapping))


class GitDiffTests(unittest.TestCase):
    def test_local_range_rename_delete_and_untracked(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            def git(*args):
                return subprocess.run(['git', '-C', str(root), *args], check=True,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout
            git('init')
            git('config', 'user.email', 'test@example.invalid')
            git('config', 'user.name', 'Test')
            old = 'ThruFlow/Platforms/macOS/Features/Settings/Old.swift'
            new = 'ThruFlow/Platforms/iOS/Features/Tasks/新しい file.swift'
            for name in [old, 'removed.swift', '.gitignore']:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('ignored\n' if name == '.gitignore' else 'original\n')
            git('add', '.')
            git('commit', '-m', 'base')
            base = git('rev-parse', 'HEAD').decode().strip()
            (root / new).parent.mkdir(parents=True, exist_ok=True)
            (root / old).rename(root / new)
            (root / 'removed.swift').unlink()
            git('add', '-A')
            (root / new).write_text('unstaged change\n')
            (root / 'untracked.swift').write_text('new\n')
            (root / 'ignored').write_text('ignored\n')
            self.assertEqual(set(review.changed_paths(root, base)), {old, new, 'removed.swift', 'untracked.swift'})
            self.assertEqual({group['id'] for group in review.classify([old, new], review.load_map())[0]}, {'settings', 'tasks'})
            git('commit', '-m', 'rename and delete')
            self.assertEqual(set(review.changed_paths(root, base, 'HEAD')), {old, new, 'removed.swift'})


if __name__ == '__main__':
    unittest.main()
