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
| `gaomon-tablet` | 16.0.0.49 | [GAOMON M5 Linux driver](https://www.gaomon.cn/download/) |
| `github-copilot-app` | 1.0.22 | [github/app](https://github.com/github/app) |
| `nyxt4` | 4.0.0 | [atlas-engineer/nyxt](https://github.com/atlas-engineer/nyxt) |
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
