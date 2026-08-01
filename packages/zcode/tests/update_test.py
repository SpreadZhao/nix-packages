import http.client
import importlib.util
import pathlib
import unittest
from unittest import mock


MODULE_PATH = pathlib.Path(__file__).parents[1] / "update.py"
SPEC = importlib.util.spec_from_file_location("zcode_update", MODULE_PATH)
UPDATE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(UPDATE)


class ZCodeUpdateTest(unittest.TestCase):
    def test_wraps_truncated_release_page_as_update_error(self):
        with mock.patch.object(UPDATE.urllib.request, "urlopen") as urlopen:
            urlopen.return_value.__enter__.return_value.read.side_effect = (
                http.client.IncompleteRead(b"<html>", 5)
            )
            with self.assertRaisesRegex(UPDATE.UpdateError, "official release page"):
                UPDATE.fetch_release_page()

    def test_extracts_linux_x64_release_from_official_page(self):
        url = (
            "https://cdn-zcode.z.ai/zcode/electron/releases/3.3.4/linux-x64/"
            "ZCode-3.3.4-linux-x64.AppImage"
        )

        self.assertEqual(
            UPDATE.release_from_page(f'<a href="{url}">Linux</a>'),
            ("3.3.4", url),
        )

    def test_accepts_legacy_linux_x64_release_url(self):
        url = (
            "https://cdn-zcode.z.ai/zcode/electron/releases/3.3.4/"
            "ZCode-3.3.4-linux-x64.AppImage"
        )

        self.assertEqual(
            UPDATE.release_from_page(f'<a href="{url}">Linux</a>'),
            ("3.3.4", url),
        )

    def test_ignores_historical_urls_in_serialized_page_state(self):
        current_url = (
            "https://cdn-zcode.z.ai/zcode/electron/releases/3.3.4/"
            "ZCode-3.3.4-linux-x64.AppImage"
        )
        historical_url = (
            "https://cdn-zcode.z.ai/zcode/electron/releases/3.3.3/"
            "ZCode-3.3.3-linux-x64.AppImage"
        )
        page = (
            f'<a href="{current_url}">Linux</a>'
            f'<script>{{\\"installer_url\\":\\"{historical_url}\\"}}</script>'
        )

        self.assertEqual(UPDATE.release_from_page(page), ("3.3.4", current_url))

    def test_rejects_page_without_linux_x64_release(self):
        with self.assertRaisesRegex(UPDATE.UpdateError, "no Linux x64 AppImage"):
            UPDATE.release_from_page("<html>No download here</html>")

    def test_selects_latest_release_from_multiple_versions(self):
        page = "".join(
            [
                '<a href="https://cdn-zcode.z.ai/zcode/electron/releases/3.3.4/ZCode-3.3.4-linux-x64.AppImage">old</a>',
                '<a href="https://cdn-zcode.z.ai/zcode/electron/releases/3.4.0/ZCode-3.4.0-linux-x64.AppImage">new</a>',
            ]
        )

        self.assertEqual(
            UPDATE.release_from_page(page),
            (
                "3.4.0",
                "https://cdn-zcode.z.ai/zcode/electron/releases/3.4.0/ZCode-3.4.0-linux-x64.AppImage",
            ),
        )

    def test_compares_numeric_version_components(self):
        page = "".join(
            [
                '<a href="https://cdn-zcode.z.ai/zcode/electron/releases/3.9.9/ZCode-3.9.9-linux-x64.AppImage">old</a>',
                '<a href="https://cdn-zcode.z.ai/zcode/electron/releases/3.10.0/ZCode-3.10.0-linux-x64.AppImage">new</a>',
            ]
        )

        self.assertEqual(UPDATE.release_from_page(page)[0], "3.10.0")

    def test_prefers_stable_release_over_prerelease(self):
        page = "".join(
            [
                '<a href="https://cdn-zcode.z.ai/zcode/electron/releases/3.4.0-beta.2/ZCode-3.4.0-beta.2-linux-x64.AppImage">beta</a>',
                '<a href="https://cdn-zcode.z.ai/zcode/electron/releases/3.4.0/ZCode-3.4.0-linux-x64.AppImage">stable</a>',
            ]
        )

        self.assertEqual(UPDATE.release_from_page(page)[0], "3.4.0")

    def test_rejects_disagreement_between_path_and_filename_versions(self):
        page = (
            '<a href="https://cdn-zcode.z.ai/zcode/electron/releases/3.3.4/'
            'ZCode-3.4.0-linux-x64.AppImage">Linux</a>'
        )

        with self.assertRaisesRegex(UPDATE.UpdateError, "version mismatch"):
            UPDATE.release_from_page(page)

    def test_detects_current_source_metadata(self):
        source = {"version": "3.3.4", "hash": "sha256-example="}

        self.assertTrue(UPDATE.source_is_current(source, "3.3.4", "sha256-example="))
        self.assertFalse(UPDATE.source_is_current(source, "3.3.5", "sha256-example="))


if __name__ == "__main__":
    unittest.main()
