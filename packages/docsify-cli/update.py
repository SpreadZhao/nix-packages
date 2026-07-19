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


REGISTRY_URL = "https://registry.npmjs.org/-/package/docsify-cli/dist-tags"
SEMVER_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$")


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


def updated_package_metadata(metadata, version):
    updated = copy.deepcopy(metadata)
    dependencies = updated.get("dependencies")
    if not isinstance(dependencies, dict) or "docsify-cli" not in dependencies:
        raise UpdateError("package.json has no docsify-cli dependency")

    updated["version"] = version
    dependencies["docsify-cli"] = version
    return updated


def metadata_is_current(package, lock, version):
    try:
        lock_root = lock["packages"][""]
        installed = lock["packages"]["node_modules/docsify-cli"]
        return all(
            (
                package["version"] == version,
                package["dependencies"]["docsify-cli"] == version,
                lock["version"] == version,
                lock_root["version"] == version,
                lock_root["dependencies"]["docsify-cli"] == version,
                installed["version"] == version,
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


def fetch_registry_metadata():
    request = urllib.request.Request(
        REGISTRY_URL,
        headers={"Accept": "application/json", "User-Agent": "nix-packages-updater"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except (OSError, http.client.HTTPException, json.JSONDecodeError) as error:
        raise UpdateError(f"failed to fetch npm metadata: {error}") from error


def generate_lockfile(package_metadata):
    with tempfile.TemporaryDirectory(prefix="docsify-cli-update-") as temp_dir:
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
    package = read_json(package_path)
    lock = read_json(lock_path)
    latest = latest_version_from_registry(fetch_registry_metadata())

    if metadata_is_current(package, lock, latest):
        print(f"docsify-cli is already current at {latest}")
        return

    current = package.get("version", "unknown")
    updated_package = updated_package_metadata(package, latest)
    updated_lock = generate_lockfile(updated_package)
    if not metadata_is_current(updated_package, updated_lock, latest):
        raise UpdateError("generated npm metadata is not internally consistent")

    replace_json_files(
        [(package_path, updated_package), (lock_path, updated_lock)]
    )
    print(f"updated docsify-cli from {current} to {latest}")


def main(argv):
    if len(argv) != 2:
        print("Usage: update.py PACKAGE_DIR", file=sys.stderr)
        return 2

    try:
        update(pathlib.Path(argv[1]).resolve())
    except UpdateError as error:
        print(f"update-docsify-cli: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
