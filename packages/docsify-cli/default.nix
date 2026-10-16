{
  lib,
  buildNpmPackage,
  importNpmLock,
  makeWrapper,
}:

let
  package = lib.importJSON ./package.json;
in
buildNpmPackage {
  pname = "docsify-cli";
  inherit (package) version;

  src = ./.;

  npmDeps = importNpmLock {
    npmRoot = ./.;
  };
  npmConfigHook = importNpmLock.npmConfigHook;

  nativeBuildInputs = [ makeWrapper ];

  # The published CLI is ready to run; docsify's postinstall tries to fetch
  # development-only Git hooks, which are unnecessary for this offline build.
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  postInstall = ''
    # cp-file preserves the store's read-only modes. Generated site files must
    # be writable both for init's substitutions and for subsequent user edits.
    substituteInPlace "$out/lib/node_modules/nix-packages-docsify-cli/node_modules/docsify-cli/lib/commands/init.js" \
      --replace-fail "const cp = require('cp-file').sync" \
        "const copy = require('cp-file').sync
    const cp = (source, destination) => {
      copy(source, destination)
      fs.chmodSync(destination, fs.statSync(destination).mode | 0o200)
    }" \
      --replace-fail "pwd('../node_modules/docsify')" \
        "resolve(require.resolve('docsify/package.json'), '..')"

    mkdir -p $out/bin
    makeWrapper $out/lib/node_modules/nix-packages-docsify-cli/node_modules/docsify-cli/bin/docsify $out/bin/docsify \
      --set NO_UPDATE_NOTIFIER 1
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    cliRoot="$out/lib/node_modules/nix-packages-docsify-cli/node_modules/docsify-cli"
    # Reproduce the permissions these assets will have in the Nix store.
    chmod -R a-w "$cliRoot/lib/template" "$cliRoot/../docsify/dist"
    cd "$TMPDIR"
    "$out/bin/docsify" init "$TMPDIR/docsify-check"
    "$out/bin/docsify" init "$TMPDIR/docsify-local-check" --local
    test -w "$TMPDIR/docsify-check/index.html"
    test -w "$TMPDIR/docsify-check/README.md"
    test -w "$TMPDIR/docsify-local-check/vendor/docsify.js"
    test -w "$TMPDIR/docsify-local-check/vendor/themes/core.css"
    runHook postInstallCheck
  '';

  meta = {
    description = "A magical documentation generator.";
    homepage = "https://github.com/docsifyjs/docsify-cli";
    license = lib.licenses.mit;
    mainProgram = "docsify";
  };
}
