# nix-packages

Personal Nix package definitions maintained by SpreadZhao.

The repository contains packaging code only. Upstream release archives and
AppImages are fetched from their original locations with fixed hashes; they are
not redistributed here.

## Packages

| Attribute | Version | Upstream |
| --- | --- | --- |
| `bili23-downloader` | 2.20.0 | [ScottSloan/Bili23-Downloader](https://github.com/ScottSloan/Bili23-Downloader) |
| `cc-connect` | 1.5.0 | [chenhg5/cc-connect](https://github.com/chenhg5/cc-connect) |
| `docsify-cli` | 5.0.0 | [docsifyjs/docsify-cli](https://github.com/docsifyjs/docsify-cli) |
| `feilian` | 3.2.16 | [FeiLian official download](https://www.volcengine.com/product/feilian/download) |
| `gaomon-tablet` | 16.0.0.49 | [GAOMON M5 Linux driver](https://www.gaomon.cn/download/) |
| `micyou-cli` | 2.1.1 | [MicYou-Dev/MicYou](https://github.com/MicYou-Dev/MicYou) |
| `nyxt4` | 4.0.0 | [atlas-engineer/nyxt](https://github.com/atlas-engineer/nyxt) |
| `opentypeless` | 1.1.61 | [tover0314-w/opentypeless](https://github.com/tover0314-w/opentypeless) |
| `shmooz` | 0.3.0 | [chmouel/shmooz](https://github.com/chmouel/shmooz) |
| `zcode` | 3.15.3 | [ZCode](https://zcode.z.ai/en) |

All package outputs currently target `x86_64-linux`.

Bili23 2.20.0 resets previously configured download naming rules; configure them
again after upgrading. docsify-cli 5 now uses docsify 5 for generated sites.

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
  inputs.personal-packages.packages.${pkgs.stdenv.hostPlatform.system}.cc-connect
];
```

An optional overlay is also exported as
`inputs.personal-packages.overlays.default`.

### JetBrains IDE wrappers

`lib.mkJetBrainsIde` adds declaratively selected plugins to an existing Nixpkgs
IDE without repackaging its distribution or replacing its runtime environment:

```nix
inputs.personal-packages.lib.mkJetBrainsIde {
  inherit pkgs;
  package = pkgs.android-studio;
  plugins = [ /* plugin derivations, including standalone JARs */ ];
  propertiesEnv = "STUDIO_PROPERTIES";
  extraProperties."idea.config.path" = "/home/user/.config/jetbrains/android-studio";
  runtimePackages = [ ];
  environment = { }; # Optional environment variables scoped to this IDE.
}
```

Use `IDEA_PROPERTIES` for IntelliJ IDEA and `CLION_PROPERTIES` for CLion.
`plugins` must contain plugin derivations compatible with the chosen IDE;
the caller owns plugin selection and version pinning. The wrapper sets
`idea.plugins.path` to an immutable directory and preserves the upstream
desktop entries, arguments, and launch environment. Other platform properties
can be set through `extraProperties`; `runtimePackages` adds tools to the
launcher's PATH. `environment` sets variables only for the launched IDE.
The result exposes `package`, `plugins`, `pluginDirectory`,
and `properties` through passthru. Update these plugins through Nix, not the
IDE's plugin manager. `checks.x86_64-linux.jetbrains-wrapper` validates both
plugin layouts and argument/environment forwarding.

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

To upgrade FeiLian, edit the version, Linux AMD64 deb URL and download hash in
`packages/feilian/source.json`, then build and validate the package locally.

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

Packages are maintained by editing their definitions directly. Set the desired
version, source URL and fixed hashes in `packages/<name>/default.nix` or its
`source.json`. For npm packages, update `package.json` and the corresponding
`package-lock.json` together; keep cc-connect's version in `source.json` aligned
with its npm metadata. Update the package table above when changing a version.

From a local checkout, build the changed package and run the local checks:

```bash
nix build --no-link --no-write-lock-file "path:$PWD#cc-connect"
nix flake check --no-write-lock-file "path:$PWD"
```

Review the diff, then commit and push the changes yourself. Consumers adopt the
new package revision by updating their corresponding flake input separately.

## Development

```bash
nix develop --no-write-lock-file "path:$PWD"
nixfmt flake.nix packages/cc-connect/default.nix
git diff --check
nix flake check --no-write-lock-file "path:$PWD"
```

The packaging code is available under the MIT license. Each packaged
application retains its own upstream license.
