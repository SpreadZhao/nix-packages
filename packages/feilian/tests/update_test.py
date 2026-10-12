import copy
import http.client
import importlib.util
import json
import pathlib
import tempfile
import unittest
from unittest import mock


MODULE_PATH = pathlib.Path(__file__).parents[1] / "update.py"
SPEC = importlib.util.spec_from_file_location("feilian_update", MODULE_PATH)
UPDATE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(UPDATE)

SCRIPT = "https://portal.volccdn.com/obj/volcfe-scm/web-feilian/static/js/main.abc123.js"
PRODUCTION = "https://lf3-beecdn.bytetos.com/obj/ies-fe-bee/bee_prod/biz_950/bee_prod_950_bee_publish_12983.json"
STAGING = PRODUCTION.replace("12983", "15647")
URL = "https://cdn.isealsuite.com/linux/FeiLian_Linux_amd64_v3.2.16_r8362_0d182a.deb"
METADATA = [{"key": "linux", "version": "V3.2.16", "config": [{"cpu": "AMD64", "deb": URL}]}]


class FeilianUpdateTest(unittest.TestCase):
    def test_extracts_main_script_and_ignores_other_scripts(self):
        page = f'<script src="//unrelated.test/a.js"></script><script src="{SCRIPT[6:]}"></script>'
        self.assertEqual(UPDATE.main_script_from_page(page), SCRIPT)

    def test_rejects_missing_main_script(self):
        with self.assertRaises(UPDATE.UpdateError):
            UPDATE.main_script_from_page("<html></html>")

    def test_selects_production_feed_instead_of_staging(self):
        self.assertEqual(
            UPDATE.production_config_from_script(f't=M?"{PRODUCTION}":"{STAGING}"'),
            PRODUCTION,
        )

    def test_rejects_changed_feed_selection_format(self):
        with self.assertRaises(UPDATE.UpdateError):
            UPDATE.production_config_from_script(f'config="{STAGING}"')

    def test_selects_amd64_deb_from_mixed_architectures(self):
        metadata = copy.deepcopy(METADATA)
        metadata[0]["config"].insert(0, {"cpu": "ARM64", "deb": URL.replace("amd64", "arm64")})
        self.assertEqual(UPDATE.release_from_metadata(metadata), ("3.2.16", URL))

    def test_rejects_version_mismatch(self):
        metadata = copy.deepcopy(METADATA)
        metadata[0]["version"] = "V3.3.15"
        with self.assertRaisesRegex(UPDATE.UpdateError, "disagree"):
            UPDATE.release_from_metadata(metadata)

    def test_rejects_unofficial_installer_url(self):
        metadata = copy.deepcopy(METADATA)
        metadata[0]["config"][0]["deb"] = URL.replace("cdn.isealsuite.com", "unrelated.test")
        with self.assertRaisesRegex(UPDATE.UpdateError, "invalid official"):
            UPDATE.release_from_metadata(metadata)

    def test_rejects_ambiguous_architecture(self):
        metadata = copy.deepcopy(METADATA)
        metadata[0]["config"] *= 2
        with self.assertRaisesRegex(UPDATE.UpdateError, "one AMD64"):
            UPDATE.release_from_metadata(metadata)

    def test_wraps_truncated_response(self):
        with mock.patch.object(UPDATE.urllib.request, "urlopen") as urlopen:
            urlopen.return_value.__enter__.return_value.read.side_effect = http.client.IncompleteRead(b"<html>", 4)
            with self.assertRaises(UPDATE.UpdateError):
                UPDATE.fetch_text(UPDATE.RELEASE_PAGE)

    def test_prefetch_failure_preserves_source(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory)
            source = path / "source.json"
            original = '{"version": "old", "hash": "old"}\n'
            source.write_text(original)
            with mock.patch.object(UPDATE, "fetch_text", side_effect=[
                f'<script src="{SCRIPT}"></script>',
                f't=M?"{PRODUCTION}":"{STAGING}"',
                json.dumps(METADATA),
            ]), mock.patch.object(UPDATE, "prefetch_hash", side_effect=UPDATE.UpdateError("prefetch failed")):
                with self.assertRaises(UPDATE.UpdateError):
                    UPDATE.update(path)
            self.assertEqual(source.read_text(), original)

    def test_updates_rebuilt_installer_without_version_change(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory)
            source = path / "source.json"
            source.write_text(json.dumps({"version": "3.2.16", "url": URL, "hash": "sha256-old="}))
            with mock.patch.object(UPDATE, "fetch_text", side_effect=[
                f'<script src="{SCRIPT}"></script>',
                f't=M?"{PRODUCTION}":"{STAGING}"',
                json.dumps(METADATA),
            ]), mock.patch.object(UPDATE, "prefetch_hash", return_value="sha256-new="):
                UPDATE.update(path)
            self.assertEqual(json.loads(source.read_text())["hash"], "sha256-new=")


if __name__ == "__main__":
    unittest.main()
