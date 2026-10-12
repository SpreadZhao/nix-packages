#!/usr/bin/env python3
import http.client
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import urllib.request
from html.parser import HTMLParser


RELEASE_PAGE = "https://www.volcengine.com/product/feilian/download"
MAIN_SCRIPT_RE = re.compile(
    r"https://portal\.volccdn\.com/obj/volcfe-scm/web-feilian/static/js/main\.[\w-]+\.js"
)
CONFIG_URL_PATTERN = (
    r"https://lf3-beecdn\.bytetos\.com/obj/ies-fe-bee/bee_prod/biz_950/"
    r"bee_prod_950_bee_publish_[0-9]+\.json"
)
# The download page selects the production feed before the staging feed.
CONFIG_PAIR_RE = re.compile(
    rf'\?\s*"(?P<production>{CONFIG_URL_PATTERN})"\s*:\s*"{CONFIG_URL_PATTERN}"'
)
DEB_RE = re.compile(
    r"https://cdn\.isealsuite\.com/linux/FeiLian_Linux_amd64_"
    r"v(?P<version>[0-9]+\.[0-9]+\.[0-9]+)_r[0-9]+_[0-9a-f]+\.deb"
)


class UpdateError(RuntimeError):
    pass


class ScriptParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.sources = []

    def handle_starttag(self, tag, attrs):
        if tag == "script":
            source = dict(attrs).get("src", "")
            if source.startswith("//"):
                source = "https:" + source
            if MAIN_SCRIPT_RE.fullmatch(source):
                self.sources.append(source)


def main_script_from_page(page):
    parser = ScriptParser()
    parser.feed(page)
    sources = set(parser.sources)
    if len(sources) != 1:
        raise UpdateError("official download page must contain one main script")
    return sources.pop()


def production_config_from_script(script):
    urls = {match.group("production") for match in CONFIG_PAIR_RE.finditer(script)}
    if len(urls) != 1:
        raise UpdateError("download script must contain one production/staging feed pair")
    return urls.pop()


def release_from_metadata(metadata):
    if not isinstance(metadata, list):
        raise UpdateError("release metadata is not a list")
    linux = [item for item in metadata if isinstance(item, dict) and item.get("key") == "linux"]
    if len(linux) != 1:
        raise UpdateError("release metadata must contain one Linux release")
    configs = linux[0].get("config")
    if not isinstance(configs, list):
        raise UpdateError("Linux release has no architecture list")
    amd64 = [item for item in configs if isinstance(item, dict) and item.get("cpu") == "AMD64"]
    if len(amd64) != 1:
        raise UpdateError("Linux release must contain one AMD64 installer")
    url = amd64[0].get("deb")
    match = DEB_RE.fullmatch(url) if isinstance(url, str) else None
    if match is None:
        raise UpdateError(f"invalid official Linux AMD64 deb URL: {url!r}")
    version = match.group("version")
    if linux[0].get("version") != f"V{version}":
        raise UpdateError("Linux release version and installer filename disagree")
    return version, url


def fetch_text(url):
    request = urllib.request.Request(url, headers={"User-Agent": "nix-packages-updater"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.read().decode("utf-8")
    except (OSError, http.client.HTTPException, UnicodeDecodeError) as error:
        raise UpdateError(f"failed to fetch {url}: {error}") from error


def prefetch_hash(url):
    try:
        result = subprocess.run(
            ["nix", "store", "prefetch-file", "--json", url],
            check=True,
            capture_output=True,
            text=True,
        )
        source_hash = json.loads(result.stdout)["hash"]
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError, KeyError) as error:
        raise UpdateError(f"failed to prefetch {url}: {error}") from error
    if not isinstance(source_hash, str) or not source_hash.startswith("sha256-"):
        raise UpdateError(f"prefetch returned an invalid hash: {source_hash!r}")
    return source_hash


def write_source(path, source):
    descriptor, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temp_path = pathlib.Path(temp_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as file:
            json.dump(source, file, indent=2, ensure_ascii=True)
            file.write("\n")
        os.replace(temp_path, path)
    finally:
        temp_path.unlink(missing_ok=True)


def update(package_dir):
    source_path = package_dir / "source.json"
    try:
        current = json.loads(source_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise UpdateError(f"failed to read {source_path}: {error}") from error
    script_url = main_script_from_page(fetch_text(RELEASE_PAGE))
    config_url = production_config_from_script(fetch_text(script_url))
    try:
        metadata = json.loads(fetch_text(config_url))
    except json.JSONDecodeError as error:
        raise UpdateError(f"invalid release metadata: {error}") from error
    version, url = release_from_metadata(metadata)
    source = {"version": version, "url": url, "hash": prefetch_hash(url)}
    if current == source:
        print(f"feilian is already current at {version}")
        return
    write_source(source_path, source)
    print(f"updated feilian from {current.get('version', 'unknown')} to {version}")


def main(argv):
    if len(argv) != 2:
        print("Usage: update.py PACKAGE_DIR", file=sys.stderr)
        return 2
    try:
        update(pathlib.Path(argv[1]).resolve())
    except UpdateError as error:
        print(f"update-feilian: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
