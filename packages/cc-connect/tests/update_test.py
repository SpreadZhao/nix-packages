import http.client
import importlib.util
import pathlib
import unittest
from unittest import mock


MODULE_PATH = pathlib.Path(__file__).parents[1] / "update.py"
SPEC = importlib.util.spec_from_file_location("cc_connect_update", MODULE_PATH)
UPDATE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(UPDATE)


class CcConnectUpdateTest(unittest.TestCase):
    def test_wraps_truncated_http_metadata_as_update_error(self):
        with mock.patch.object(UPDATE.urllib.request, "urlopen") as urlopen:
            urlopen.return_value.__enter__.return_value.read.side_effect = (
                http.client.IncompleteRead(b"{}", 5)
            )
            with self.assertRaisesRegex(UPDATE.UpdateError, "failed to fetch npm"):
                UPDATE.fetch_json(UPDATE.NPM_REGISTRY_URL, "npm")

    def test_extracts_latest_npm_version(self):
        metadata = {"latest": "1.4.0", "beta": "1.5.0-beta.1"}

        self.assertEqual(UPDATE.latest_version_from_registry(metadata), "1.4.0")

    def test_normalizes_github_release_tag(self):
        self.assertEqual(
            UPDATE.version_from_github_release({"tag_name": "v1.4.0"}),
            "1.4.0",
        )

    def test_selects_latest_stable_gitee_release(self):
        releases = [
            {"tag_name": "v1.4.0", "prerelease": False, "assets": []},
            {"tag_name": "v1.5.0-beta.1", "prerelease": True, "assets": []},
            {"tag_name": "v1.4.1", "prerelease": False, "assets": []},
        ]

        version, release = UPDATE.latest_stable_gitee_release(releases)

        self.assertEqual(version, "1.4.1")
        self.assertEqual(release["tag_name"], "v1.4.1")

    def test_rejects_gitee_release_list_without_a_stable_version(self):
        releases = [
            {"tag_name": "v1.5.0-beta.1", "prerelease": True, "assets": []}
        ]

        with self.assertRaisesRegex(UPDATE.UpdateError, "no stable release"):
            UPDATE.latest_stable_gitee_release(releases)

    def test_rejects_invalid_upstream_versions(self):
        invalid_npm = [{}, {"latest": "latest"}]
        invalid_github = [{}, {"tag_name": "release-1.4.0"}]

        for metadata in invalid_npm:
            with self.subTest(source="npm", metadata=metadata):
                with self.assertRaises(UPDATE.UpdateError):
                    UPDATE.latest_version_from_registry(metadata)
        for metadata in invalid_github:
            with self.subTest(source="github", metadata=metadata):
                with self.assertRaises(UPDATE.UpdateError):
                    UPDATE.version_from_github_release(metadata)

    def test_rejects_npm_and_github_version_disagreement(self):
        with self.assertRaisesRegex(UPDATE.UpdateError, "upstream version mismatch"):
            UPDATE.synchronized_version("1.4.0", "1.3.9", "1.4.0")

    def test_accepts_only_matching_npm_github_and_gitee_versions(self):
        self.assertEqual(
            UPDATE.synchronized_version("1.4.1", "1.4.1", "1.4.1"),
            "1.4.1",
        )

    def test_rejects_different_github_and_gitee_archive_hashes(self):
        with self.assertRaisesRegex(UPDATE.UpdateError, "binary hash mismatch"):
            UPDATE.synchronized_binary_hash("sha256-github=", "sha256-gitee=")

    def test_updates_wrapper_and_dependency_versions(self):
        current = {
            "name": "nix-packages-cc-connect",
            "version": "1.3.4",
            "private": True,
            "dependencies": {"cc-connect": "1.3.4"},
        }

        updated = UPDATE.updated_package_metadata(current, "1.4.0")

        self.assertEqual(current["version"], "1.3.4")
        self.assertEqual(updated["version"], "1.4.0")
        self.assertEqual(updated["dependencies"]["cc-connect"], "1.4.0")

    def test_detects_fully_current_metadata(self):
        package = {
            "version": "1.4.0",
            "dependencies": {"cc-connect": "1.4.0"},
        }
        lock = {
            "version": "1.4.0",
            "packages": {
                "": {
                    "version": "1.4.0",
                    "dependencies": {"cc-connect": "1.4.0"},
                },
                "node_modules/cc-connect": {"version": "1.4.0"},
            },
        }
        source = {"version": "1.4.0", "hash": "sha256-example="}

        self.assertTrue(
            UPDATE.metadata_is_current(
                package, lock, source, "1.4.0", "sha256-example="
            )
        )
        source["hash"] = "sha256-old="
        self.assertFalse(
            UPDATE.metadata_is_current(
                package, lock, source, "1.4.0", "sha256-example="
            )
        )


if __name__ == "__main__":
    unittest.main()
