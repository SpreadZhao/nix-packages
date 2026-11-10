{
  description = "Personal Nix packages maintained by SpreadZhao";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.naw = {
    url = "github:SpreadZhao/NAW";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      nixpkgs,
      naw,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      repoWorkspace = naw.lib.mkWorkspace {
        systems = [ system ];
        skills = { };
        # NAW always generates AGENTS.md; targets only selects skill directories.
        targets = [ ];
        instructions = ''
          # Repository scope

          - `packages/` contains application derivations and source metadata.
          - `modules/` contains optional NixOS integration. FeiLian's module configures its
            system service and networking; its application derivation remains in
            `packages/feilian/`.
          - Check `git status --short` before editing. Preserve unrelated changes and
            in-progress work. Do not commit or push unless the user requests it.

          ## Nix Switch Policy

          - For any Nix-related work in this repository, never execute `switch`; the user performs that step manually.
          - This includes `nixos-rebuild switch`, `home-manager switch`, `nh os switch`, `nh home switch`, and any wrapper or update script that invokes `switch`, including through its default arguments.
          - Evaluation, builds, formatting, and other checks that do not activate the configuration are allowed. When a switch is needed, provide the command for the user to run instead of executing it.
          - Requests to change, update, fix, or rebuild Nix configuration do not authorize an automatic switch. This repository-wide rule takes precedence over any skill or workflow that recommends running `switch`.

          ## Clean Delivery Policy

          - Deliver only the files, dependencies, configuration, and behavior needed for the requested result. Before finishing, actively review the working tree and clean up this task's temporary tests, fixtures, validation reports, logs, caches, intermediate outputs, and debug code or settings. Do not leave cleanup for the user.
          - Testing during development is encouraged, but temporary unit tests and other verification scripts belong outside the repository and must be removed after use. Keep tests in the delivered project only when the user explicitly asks to retain them. Remove test-only helpers, command-line options, and documentation references as well.
          - Prefer temporary, isolated environments such as `nix shell` or `nix develop` for tools needed only for testing. Remove packages and dependencies added solely for development, testing, or debugging from persistent configuration and profiles when they are not needed by the delivered result.
          - Stop temporary processes and services, undo temporary environment or configuration changes, and remove temporary files created for this task, including those outside the repository. Preserve anything that is part of the requested result.
          - Limit cleanup to changes and resources introduced by this task or explicitly authorized by the user. Preserve the user's existing tools, data, and unrelated modifications. Do not delete shared Nix Store contents or run broad garbage collection as a cleanup shortcut.
          - Cleanup must respect the Nix Switch Policy. If removing a live dependency or other temporary state requires a prohibited action, prepare the configuration change, report exactly what remains, and provide the manual command; do not execute `switch` or claim cleanup is complete.

          ## Validation

          - Format changed Nix files with `nixfmt` and run `git diff --check`.
          - Build packages with `nix build --no-link --no-write-lock-file "path:$PWD#<package>"`.
            Do not create `result`, `result-1`, or other build-output symlinks in the checkout.
          - Set `PYTHONDONTWRITEBYTECODE=1` when running Python during temporary validation.
          - Do not introduce custom test phases, test-only flake checks, or CI scaffolding
            unless the user asks to retain them. Preserve upstream build flags and runtime
            dependencies required to build or run a package.
          - Check ignored as well as tracked files before finishing; `.gitignore` prevents
            accidental commits, not leftover files in the working tree.
        '';
        packages = pkgs: [
          pkgs.git
          pkgs.nixfmt
        ];
      };
    in
    {
      packages.${system} = import ./packages { inherit pkgs; };

      overlays.default = final: _: import ./packages { pkgs = final; };

      nixosModules.feilian = import ./modules/feilian.nix;

      formatter.${system} = pkgs.nixfmt;

      checks = repoWorkspace.checks;
      devShells = repoWorkspace.devShells;
    };
}
