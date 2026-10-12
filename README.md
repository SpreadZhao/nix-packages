# nix-packages

Personal Nix package definitions maintained by SpreadZhao.

The repository contains packaging code only. Upstream release archives and
AppImages are fetched from their original locations with fixed hashes; they are
not redistributed here.

## Packages

| Attribute | Version | Upstream |
| --- | --- | --- |
| `bili23-downloader` | 2.10.4 | [ScottSloan/Bili23-Downloader](https://github.com/ScottSloan/Bili23-Downloader) |
| `cc-connect` | 1.4.1 | [chenhg5/cc-connect](https://github.com/chenhg5/cc-connect) |
| `docsify-cli` | 4.4.4 | [docsifyjs/docsify-cli](https://github.com/docsifyjs/docsify-cli) |
| `feilian` | 3.2.16 | [FeiLian official download](https://www.volcengine.com/product/feilian/download) |
| `gaomon-tablet` | 16.0.0.49 | [GAOMON M5 Linux driver](https://www.gaomon.cn/download/) |
| `github-copilot-app` | 1.0.22 | [github/app](https://github.com/github/app) |
| `nyxt4` | 4.0.0 | [atlas-engineer/nyxt](https://github.com/atlas-engineer/nyxt) |
| `opentypeless` | 1.1.57 | [tover0314-w/opentypeless](https://github.com/tover0314-w/opentypeless) |
| `zcode` | 3.3.5 | [ZCode](https://zcode.z.ai/en) |

All package outputs currently target `x86_64-linux`.

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

Update with `nix run .#update -- feilian`. The updater discovers the official
page's production release feed, selects the Linux AMD64 deb, verifies its
version, and refreshes `source.json` only after the download hash succeeds.
It fails explicitly if the upstream page format changes. Package builds and
configuration evaluation do not contact the release feed.

## Update

Updates are explicit and package-scoped. From a local checkout, run:

```bash
nix run .#update -- cc-connect
nix flake check
```

## Development

```bash
nix develop
nix flake check
actionlint
```

The packaging code is available under the MIT license. Each packaged
application retains its own upstream license.
