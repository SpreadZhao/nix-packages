{
  description = "Personal Nix packages maintained by SpreadZhao";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      packageSet = import ./packages { inherit pkgs; };
      overlay = final: _: import ./packages { pkgs = final; };
      updateTool = pkgs.writeShellApplication {
        name = "update-personal-package";
        runtimeInputs = [
          pkgs.git
          pkgs.nix-update
        ];
        text = ''
          if (($# != 1)); then
            echo "Usage: nix run .#update -- <package>" >&2
            exit 2
          fi

          package="$1"
          case "$package" in
          bili23-downloader | cc-connect | docsify-cli | github-copilot-app | nyxt4 | zcode) ;;
          *)
            echo "Unknown package: $package" >&2
            exit 2
            ;;
          esac

          repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
            echo "Run this command from a nix-packages checkout." >&2
            exit 2
          }

          if [[ ! -d "$repo_root/packages" || ! -f "$repo_root/flake.nix" ]]; then
            echo "Run this command from a nix-packages checkout." >&2
            exit 2
          fi

          cd "$repo_root"
          exec nix-update "$package" --flake --use-update-script
        '';
      };
      updaterTests =
        pkgs.runCommand "nix-packages-updater-tests"
          {
            nativeBuildInputs = [ pkgs.python3 ];
          }
          ''
            cp -R ${./packages/cc-connect} cc-connect
            cp -R ${./packages/docsify-cli} docsify-cli
            cp -R ${./packages/zcode} zcode
            python -m unittest discover -s cc-connect/tests -p "update_test.py"
            python -m unittest discover -s docsify-cli/tests -p "update_test.py"
            python -m unittest discover -s zcode/tests -p "update_test.py"
            touch "$out"
          '';
      formattingCheck =
        pkgs.runCommand "nix-packages-formatting-check"
          {
            nativeBuildInputs = [ pkgs.nixfmt ];
          }
          ''
            cp -R ${self} source
            chmod -R u+w source
            cd source
            mapfile -d "" nix_files < <(find . -name "*.nix" -print0)
            nixfmt --check "''${nix_files[@]}"
            touch "$out"
          '';
    in
    {
      packages.${system} = packageSet;

      overlays.default = overlay;

      apps.${system}.update = {
        type = "app";
        program = pkgs.lib.getExe updateTool;
        meta.description = "Update one package in a nix-packages checkout";
      };

      checks.${system} = packageSet // {
        updater-tests = updaterTests;
        formatting = formattingCheck;
      };

      formatter.${system} = pkgs.nixfmt;

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.actionlint
          pkgs.git
          pkgs.nix-update
          pkgs.nixfmt
          pkgs.python3
        ];
      };
    };
}
