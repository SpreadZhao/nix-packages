# nix-packages

Personal Nix package definitions maintained by SpreadZhao.

`packages/` contains application derivations and source metadata, and
`modules/feilian.nix` provides optional NixOS service integration for FeiLian.
Derivations fetch upstream sources and release archives from their original URLs
with fixed hashes; binaries are not redistributed here.

## Packages

| Attribute | Version | Upstream |
| --- | --- | --- |
| `bili23-downloader` | 2.20.0 | [ScottSloan/Bili23-Downloader](https://github.com/ScottSloan/Bili23-Downloader) |
| `feilian` | 3.2.16 | [FeiLian official download](https://www.volcengine.com/product/feilian/download) |
| `micyou-cli` | 2.1.1 | [MicYou-Dev/MicYou](https://github.com/MicYou-Dev/MicYou) |
| `nyxt4` | 4.0.0 | [atlas-engineer/nyxt](https://github.com/atlas-engineer/nyxt) |
| `opentypeless` | 1.1.61 | [tover0314-w/opentypeless](https://github.com/tover0314-w/opentypeless) |
| `psst-auth` | 0.2.0 (2026-06-22 snapshot) | [phisch/psst](https://github.com/phisch/psst) |
| `shmooz` | 0.3.0 | [chmouel/shmooz](https://github.com/chmouel/shmooz) |

All package outputs target `x86_64-linux`.

Bili23 2.20.0 resets previously configured download naming rules; configure them
again after upgrading.

## Use

Build a package directly:

```bash
nix build github:SpreadZhao/nix-packages#bili23-downloader
```

Use the flake from a NixOS or Home Manager configuration:

```nix
inputs.personal-packages = {
  url = "github:SpreadZhao/nix-packages";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then install a package without applying an overlay:

```nix
home.packages = [
  inputs.personal-packages.packages.${pkgs.stdenv.hostPlatform.system}.bili23-downloader
];
```

The flake also exports `inputs.personal-packages.overlays.default`.

### FeiLian

FeiLian needs its root daemon and NetworkManager. Import the module on the
desired NixOS host; importing it alone does not enable anything:

```nix
imports = [ inputs.personal-packages.nixosModules.feilian ];
networking.networkmanager.enable = true;
services.feilian.enable = true;
```

After rebuilding, launch `feilian` or its desktop entry. Activate the client
with your company's identification code. This packages the public client;
private deployments may require a different installer supplied by the company.

The module runs `corplink.service` and installs the user helper autostart entry.
Signed vendor binaries run in an FHS environment with the host network and
system bus. The root daemon has the privileges needed to manage VPN interfaces.
It stores writable application files in `/var/lib/feilian`; package changes
refresh shipped files while retaining generated configs, certificates and logs.
Removing the module stops the service but keeps this state directory.

To upgrade FeiLian, update the version, Linux AMD64 deb URL and download hash in
`packages/feilian/source.json`.

### MicYou CLI

`micyou-cli` installs only the standalone command-line server from the upstream
Linux release, with the ALSA configuration and runtime tools needed for PipeWire
and Android USB connections. It does not install the GUI, TUI, desktop entries,
GTK/WebKit or the unused ONNX Runtime library.

Install the matching [Android APK](https://github.com/MicYou-Dev/MicYou/releases/download/v2.1.1/MicYou-Android-2.1.1.apk)
on the phone, then use either transport:

```bash
micyou-cli serve --mode usb
micyou-cli serve --mode wifi
```

USB requires a data cable, Android USB debugging and authorization of the host.
Wi-Fi requires a reachable LAN address. The default native ports in 2.1.1 are
TCP 8554 and UDP 8555; mDNS discovery uses UDP 5353. Open those ports in the host
firewall when using Wi-Fi. Browser mode (`--mode web`) uses TCP 8443.

The CLI creates `MicYouVirtualMic` in the current user's PipeWire session and
temporarily selects it as the default input. Select it in the calling or recording
application. Stop the server with Ctrl+C to clean up the virtual device and restore
the previous input. A system-wide daemon is not required.

```bash
micyou-cli mics
micyou-cli server get
micyou-cli --help
```

To upgrade MicYou CLI, edit `packages/micyou-cli/default.nix`. If upstream changes
its license, refresh `licenseFile.hash` as well. Recheck the Android version link,
runtime resource layout and default ports when upgrading.

## Update

Set the version, source URL and fixed hashes in `packages/<name>/default.nix` or
`packages/<name>/source.json`, and update the package table above when changing
a version.

From a local checkout, build the changed package without creating a result link:

```bash
nix build --no-link --no-write-lock-file "path:$PWD#bili23-downloader"
git diff --check
```

Review the diff, then commit and push the changes yourself. Consumers adopt the
new package revision by updating their flake input separately.

## Development

```bash
nix develop --no-write-lock-file "path:$PWD"
nixfmt flake.nix packages/bili23-downloader/default.nix
git diff --check
```

Entering `nix develop --no-write-lock-file "path:$PWD"` uses
[NAW](https://github.com/SpreadZhao/NAW) to generate `AGENTS.md` from
`repoWorkspace.instructions` in `flake.nix` without installing agent skill
directories. Edit `flake.nix` rather than `AGENTS.md`; Git ignores both
`AGENTS.md` and `.naw/`, and the `workspace` flake check builds the NAW output.

Keep temporary validation scripts, fixtures, caches and logs outside this
checkout, set `PYTHONDONTWRITEBYTECODE=1` when running Python, and remove
temporary files and processes before finishing. Do not commit test scaffolding
or leave `result*` links in the repository.

The packaging code is available under the MIT license. Each packaged
application retains its own upstream license.
