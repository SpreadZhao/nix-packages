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


RELEASE_PAGE = "https://zcode.z.ai/en"
VERSION_PATTERN = r"[0-9]+(?:\.[0-9]+){2}(?:[-+][0-9A-Za-z.-]+)?"
APPIMAGE_PATTERN = re.compile(
    r"https://cdn-zcode\.z\.ai/zcode/electron/releases/"
    rf"(?P<path_version>{VERSION_PATTERN})/"
    r"(?:linux-x64/)?"
    rf"ZCode-(?P<file_version>{VERSION_PATTERN})-linux-x64\.AppImage"
)


class UpdateError(RuntimeError):
    pass


class DownloadLinkParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.hrefs = []

    def handle_starttag(self, tag, attrs):
        if tag != "a":
            return
        href = dict(attrs).get("href")
        if href is not None:
            self.hrefs.append(href)


def version_key(version):
    version_without_build = version.split("+", 1)[0]
    release, separator, prerelease = version_without_build.partition("-")
    release_key = tuple(int(part) for part in release.split("."))
    prerelease_key = (
        tuple(
            (0, int(part), "") if part.isdigit() else (1, 0, part)
            for part in prerelease.split(".")
        )
        if separator
        else ()
    )
    return release_key, not separator, prerelease_key


def release_from_page(page):
    parser = DownloadLinkParser()
    parser.feed(page)
    releases = set()

    for href in parser.hrefs:
        match = APPIMAGE_PATTERN.fullmatch(href)
        if match is None:
            continue
        path_version = match.group("path_version")
        file_version = match.group("file_version")
        if path_version != file_version:
            raise UpdateError(
                "Linux x64 AppImage version mismatch between URL path and filename: "
                f"{path_version} != {file_version}"
            )
        releases.add((path_version, match.group(0)))

    if not releases:
        raise UpdateError("official release page contains no Linux x64 AppImage")

    return max(releases, key=lambda release: version_key(release[0]))


def source_is_current(source, version, source_hash):
    return source.get("version") == version and source.get("hash") == source_hash


def read_json(path):
    try:
        with path.open(encoding="utf-8") as file:
            return json.load(file)
    except (OSError, json.JSONDecodeError) as error:
        raise UpdateError(f"failed to read {path}: {error}") from error


def fetch_release_page():
    request = urllib.request.Request(
        RELEASE_PAGE,
        headers={"Accept": "text/html", "User-Agent": "nix-packages-updater"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.read().decode("utf-8")
    except (OSError, http.client.HTTPException, UnicodeDecodeError) as error:
        raise UpdateError(f"failed to fetch the official release page: {error}") from error


def prefetch_hash(url):
    try:
        result = subprocess.run(
            ["nix", "store", "prefetch-file", "--json", url],
            check=True,
            capture_output=True,
            text=True,
        )
        metadata = json.loads(result.stdout)
        source_hash = metadata["hash"]
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
    current = read_json(source_path)
    version, url = release_from_page(fetch_release_page())
    source_hash = prefetch_hash(url)

    if source_is_current(current, version, source_hash):
        print(f"zcode is already current at {version}")
        return

    old_version = current.get("version", "unknown")
    write_source(source_path, {"version": version, "hash": source_hash})
    print(f"updated zcode from {old_version} to {version}")


def main(argv):
    if len(argv) != 2:
        print("Usage: update.py PACKAGE_DIR", file=sys.stderr)
        return 2

    try:
        update(pathlib.Path(argv[1]).resolve())
    except UpdateError as error:
        print(f"update-zcode: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
