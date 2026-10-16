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

      nixosModules.feilian = import ./modules/feilian.nix;

      checks.${system} = packageSet // {
        formatting = formattingCheck;
      };

      formatter.${system} = pkgs.nixfmt;

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.actionlint
          pkgs.git
          pkgs.nixfmt
        ];
      };
    };
}
