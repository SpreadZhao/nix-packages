{
  cacert,
  lib,
  buildNpmPackage,
  fetchurl,
  importNpmLock,
  nix,
  nodejs,
  python3,
  writeShellApplication,
}:

let
  package = lib.importJSON ./package.json;
  sourceInfo = lib.importJSON ./source.json;
  version =
    if sourceInfo.version == package.version then
      package.version
    else
      throw "cc-connect package.json and source.json versions differ";

  ccConnectBinary = fetchurl {
    urls = [
      "https://github.com/chenhg5/cc-connect/releases/download/v${version}/cc-connect-v${version}-linux-amd64.tar.gz"
      "https://gitee.com/cg33/cc-connect/releases/download/v${version}/cc-connect-v${version}-linux-amd64.tar.gz"
    ];
    inherit (sourceInfo) hash;
  };
  updateScript = writeShellApplication {
    name = "update-cc-connect";
    runtimeInputs = [
      nix
      nodejs
      python3
    ];
    runtimeEnv.SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    text = ''
      exec python3 ${./update.py} "$PWD/packages/cc-connect"
    '';
    meta.mainProgram = "update-cc-connect";
  };
in
buildNpmPackage {
  pname = "cc-connect";
  inherit version;

  src = ./.;

  npmDeps = importNpmLock {
    npmRoot = ./.;
  };
  npmConfigHook = importNpmLock.npmConfigHook;

  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  postInstall = ''
    ccConnectDir="$out/lib/node_modules/nix-packages-cc-connect/node_modules/cc-connect"

    mkdir -p "$ccConnectDir/bin" "$out/bin"
    tar xzf ${ccConnectBinary} -C "$ccConnectDir/bin"
    mv "$ccConnectDir/bin/cc-connect-v${version}-linux-amd64" "$ccConnectDir/bin/cc-connect"
    chmod +x "$ccConnectDir/bin/cc-connect"

    ln -s "$ccConnectDir/bin/cc-connect" "$out/bin/cc-connect"
  '';

  passthru.updateScript = lib.getExe updateScript;

  meta = {
    description = "Bridge local AI coding agents to messaging platforms";
    homepage = "https://github.com/chenhg5/cc-connect";
    license = lib.licenses.mit;
    mainProgram = "cc-connect";
    platforms = [ "x86_64-linux" ];
  };
}
