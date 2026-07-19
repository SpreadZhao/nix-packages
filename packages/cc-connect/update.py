#!/usr/bin/env python3
import copy
import http.client
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import urllib.request


NPM_REGISTRY_URL = "https://registry.npmjs.org/-/package/cc-connect/dist-tags"
GITHUB_RELEASE_URL = "https://api.github.com/repos/chenhg5/cc-connect/releases/latest"
GITEE_RELEASES_URL = (
    "https://gitee.com/api/v5/repos/cg33/cc-connect/releases?per_page=100&page=1"
)
SEMVER_PATTERN = r"[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?"
SEMVER_RE = re.compile(rf"^{SEMVER_PATTERN}$")
GITHUB_TAG_RE = re.compile(rf"^v({SEMVER_PATTERN})$")
STABLE_TAG_RE = re.compile(r"^v([0-9]+)\.([0-9]+)\.([0-9]+)$")


class UpdateError(RuntimeError):
    pass


def latest_version_from_registry(metadata):
    try:
        version = metadata["latest"]
    except (KeyError, TypeError) as error:
        raise UpdateError("npm metadata has no latest dist-tag") from error

    if not isinstance(version, str) or not SEMVER_RE.fullmatch(version):
        raise UpdateError(f"invalid npm latest version: {version!r}")
    return version


def version_from_github_release(metadata):
    tag = metadata.get("tag_name") if isinstance(metadata, dict) else None
    match = GITHUB_TAG_RE.fullmatch(tag) if isinstance(tag, str) else None
    if match is None:
        raise UpdateError(f"invalid GitHub latest release tag: {tag!r}")
    return match.group(1)


def latest_stable_gitee_release(releases):
    if not isinstance(releases, list):
        raise UpdateError("Gitee release metadata is not a list")

    stable_releases = []
    for release in releases:
        if not isinstance(release, dict) or release.get("prerelease") is not False:
            continue
        tag = release.get("tag_name")
        match = STABLE_TAG_RE.fullmatch(tag) if isinstance(tag, str) else None
        if match is None:
            continue
        version_key = tuple(int(part) for part in match.groups())
        stable_releases.append((version_key, ".".join(match.groups()), release))

    if not stable_releases:
        raise UpdateError("Gitee metadata contains no stable release")

    _, version, release = max(stable_releases, key=lambda candidate: candidate[0])
    return version, release


def synchronized_version(npm_version, github_version, gitee_version):
    if len({npm_version, github_version, gitee_version}) != 1:
        raise UpdateError(
            "upstream version mismatch: "
            f"npm={npm_version}, GitHub={github_version}, Gitee={gitee_version}"
        )
    return npm_version


def synchronized_binary_hash(github_hash, gitee_hash):
    if github_hash != gitee_hash:
        raise UpdateError(
            f"binary hash mismatch: GitHub={github_hash}, Gitee={gitee_hash}"
        )
    return github_hash


def updated_package_metadata(metadata, version):
    updated = copy.deepcopy(metadata)
    dependencies = updated.get("dependencies")
    if not isinstance(dependencies, dict) or "cc-connect" not in dependencies:
        raise UpdateError("package.json has no cc-connect dependency")

    updated["version"] = version
    dependencies["cc-connect"] = version
    return updated


def metadata_is_current(package, lock, source, version, source_hash):
    try:
        lock_root = lock["packages"][""]
        installed = lock["packages"]["node_modules/cc-connect"]
        return all(
            (
                package["version"] == version,
                package["dependencies"]["cc-connect"] == version,
                lock["version"] == version,
                lock_root["version"] == version,
                lock_root["dependencies"]["cc-connect"] == version,
                installed["version"] == version,
                source["version"] == version,
                source["hash"] == source_hash,
            )
        )
    except (KeyError, TypeError):
        return False


def read_json(path):
    try:
        with path.open(encoding="utf-8") as file:
            return json.load(file)
    except (OSError, json.JSONDecodeError) as error:
        raise UpdateError(f"failed to read {path}: {error}") from error


def fetch_json(url, source):
    request = urllib.request.Request(
        url,
        headers={"Accept": "application/json", "User-Agent": "nix-packages-updater"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except (OSError, http.client.HTTPException, json.JSONDecodeError) as error:
        raise UpdateError(f"failed to fetch {source} metadata: {error}") from error


def github_archive_url(version):
    return (
        f"https://github.com/chenhg5/cc-connect/releases/download/v{version}/"
        f"cc-connect-v{version}-linux-amd64.tar.gz"
    )


def gitee_archive_url(version):
    return (
        f"https://gitee.com/cg33/cc-connect/releases/download/v{version}/"
        f"cc-connect-v{version}-linux-amd64.tar.gz"
    )


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


def generate_lockfile(package_metadata):
    with tempfile.TemporaryDirectory(prefix="cc-connect-update-") as temp_dir:
        temp_path = pathlib.Path(temp_dir)
        write_json(temp_path / "package.json", package_metadata)
        try:
            subprocess.run(
                [
                    "npm",
                    "install",
                    "--package-lock-only",
                    "--ignore-scripts",
                    "--no-audit",
                    "--no-fund",
                ],
                cwd=temp_path,
                check=True,
            )
        except (OSError, subprocess.CalledProcessError) as error:
            raise UpdateError(f"failed to generate npm lockfile: {error}") from error
        return read_json(temp_path / "package-lock.json")


def write_json(path, value):
    with path.open("w", encoding="utf-8") as file:
        json.dump(value, file, indent=2, ensure_ascii=True)
        file.write("\n")


def replace_json_files(replacements):
    staged = []
    try:
        for path, value in replacements:
            descriptor, temp_name = tempfile.mkstemp(
                prefix=f".{path.name}.", dir=path.parent
            )
            temp_path = pathlib.Path(temp_name)
            with os.fdopen(descriptor, "w", encoding="utf-8") as file:
                json.dump(value, file, indent=2, ensure_ascii=True)
                file.write("\n")
            staged.append((temp_path, path))

        for temp_path, path in staged:
            os.replace(temp_path, path)
    finally:
        for temp_path, _ in staged:
            temp_path.unlink(missing_ok=True)


def update(package_dir):
    package_path = package_dir / "package.json"
    lock_path = package_dir / "package-lock.json"
    source_path = package_dir / "source.json"
    package = read_json(package_path)
    lock = read_json(lock_path)
    source = read_json(source_path)

    npm_version = latest_version_from_registry(
        fetch_json(NPM_REGISTRY_URL, "npm")
    )
    github_version = version_from_github_release(
        fetch_json(GITHUB_RELEASE_URL, "GitHub")
    )
    gitee_version, _ = latest_stable_gitee_release(
        fetch_json(GITEE_RELEASES_URL, "Gitee")
    )
    version = synchronized_version(npm_version, github_version, gitee_version)
    source_hash = synchronized_binary_hash(
        prefetch_hash(github_archive_url(version)),
        prefetch_hash(gitee_archive_url(version)),
    )

    if metadata_is_current(package, lock, source, version, source_hash):
        print(f"cc-connect is already current at {version}")
        return

    old_version = package.get("version", "unknown")
    updated_package = updated_package_metadata(package, version)
    updated_lock = generate_lockfile(updated_package)
    updated_source = {"version": version, "hash": source_hash}
    if not metadata_is_current(
        updated_package, updated_lock, updated_source, version, source_hash
    ):
        raise UpdateError("generated package metadata is not internally consistent")

    replace_json_files(
        [
            (package_path, updated_package),
            (lock_path, updated_lock),
            (source_path, updated_source),
        ]
    )
    print(f"updated cc-connect from {old_version} to {version}")


def main(argv):
    if len(argv) != 2:
        print("Usage: update.py PACKAGE_DIR", file=sys.stderr)
        return 2

    try:
        update(pathlib.Path(argv[1]).resolve())
    except UpdateError as error:
        print(f"update-cc-connect: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
