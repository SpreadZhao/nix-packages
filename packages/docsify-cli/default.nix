{
  lib,
  buildNpmPackage,
  importNpmLock,
  makeWrapper,
  nodejs,
  python3,
  writeShellApplication,
}:

let
  package = lib.importJSON ./package.json;
  updateScript = writeShellApplication {
    name = "update-docsify-cli";
    runtimeInputs = [
      nodejs
      python3
    ];
    text = ''
      exec python3 ${./update.py} "$PWD/packages/docsify-cli"
    '';
    meta.mainProgram = "update-docsify-cli";
  };
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

  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  postInstall = ''
    mkdir -p $out/bin
    makeWrapper $out/lib/node_modules/nix-packages-docsify-cli/node_modules/docsify-cli/bin/docsify $out/bin/docsify \
      --set NO_UPDATE_NOTIFIER 1
  '';

  passthru.updateScript = lib.getExe updateScript;

  meta = {
    description = "A magical documentation generator.";
    homepage = "https://github.com/docsifyjs/docsify-cli";
    license = lib.licenses.mit;
    mainProgram = "docsify";
  };
}
