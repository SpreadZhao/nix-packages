import http.client
import importlib.util
import pathlib
import unittest
from unittest import mock


MODULE_PATH = pathlib.Path(__file__).parents[1] / "update.py"
SPEC = importlib.util.spec_from_file_location("docsify_cli_update", MODULE_PATH)
UPDATE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(UPDATE)


class DocsifyCliUpdateTest(unittest.TestCase):
    def test_wraps_truncated_http_metadata_as_update_error(self):
        with mock.patch.object(UPDATE.urllib.request, "urlopen") as urlopen:
            urlopen.return_value.__enter__.return_value.read.side_effect = (
                http.client.IncompleteRead(b"{}", 5)
            )
            with self.assertRaisesRegex(UPDATE.UpdateError, "failed to fetch npm"):
                UPDATE.fetch_registry_metadata()

    def test_extracts_latest_registry_version(self):
        metadata = {"latest": "4.5.0", "next": "5.0.0-rc.1"}

        self.assertEqual(UPDATE.latest_version_from_registry(metadata), "4.5.0")

    def test_rejects_missing_or_invalid_latest_version(self):
        invalid_metadata = [
            {},
            {"latest": "latest"},
            {"latest": 450},
        ]

        for metadata in invalid_metadata:
            with self.subTest(metadata=metadata):
                with self.assertRaises(UPDATE.UpdateError):
                    UPDATE.latest_version_from_registry(metadata)

    def test_updates_wrapper_and_dependency_versions_without_mutating_input(self):
        current = {
            "name": "nix-packages-docsify-cli",
            "version": "4.4.4",
            "private": True,
            "dependencies": {"docsify-cli": "4.4.4"},
        }

        updated = UPDATE.updated_package_metadata(current, "4.5.0")

        self.assertEqual(current["version"], "4.4.4")
        self.assertEqual(updated["version"], "4.5.0")
        self.assertEqual(updated["dependencies"]["docsify-cli"], "4.5.0")
        self.assertTrue(updated["private"])

    def test_detects_current_package_and_lock_metadata(self):
        package = {
            "version": "4.5.0",
            "dependencies": {"docsify-cli": "4.5.0"},
        }
        lock = {
            "version": "4.5.0",
            "packages": {
                "": {
                    "version": "4.5.0",
                    "dependencies": {"docsify-cli": "4.5.0"},
                },
                "node_modules/docsify-cli": {"version": "4.5.0"},
            },
        }

        self.assertTrue(UPDATE.metadata_is_current(package, lock, "4.5.0"))
        lock["packages"][""]["dependencies"]["docsify-cli"] = "4.4.4"
        self.assertFalse(UPDATE.metadata_is_current(package, lock, "4.5.0"))


if __name__ == "__main__":
    unittest.main()
