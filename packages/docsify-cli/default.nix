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

  dontNpmBuild = true;

  postInstall = ''
    mkdir -p $out/bin
    makeWrapper $out/lib/node_modules/nix-packages-docsify-cli/node_modules/docsify-cli/bin/docsify $out/bin/docsify \
      --set NO_UPDATE_NOTIFIER 1
  '';

  meta = {
    description = "A magical documentation generator.";
    homepage = "https://github.com/docsifyjs/docsify-cli";
    license = lib.licenses.mit;
    mainProgram = "docsify";
  };
}
