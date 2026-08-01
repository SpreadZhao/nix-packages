{
  appimageTools,
  cacert,
  fetchurl,
  lib,
  nix,
  python3,
  writeShellApplication,
}:

let
  pname = "zcode";
  sourceInfo = lib.importJSON ./source.json;
  inherit (sourceInfo) version;
  src = fetchurl {
    url = "https://cdn-zcode.z.ai/zcode/electron/releases/${version}/linux-x64/ZCode-${version}-linux-x64.AppImage";
    inherit (sourceInfo) hash;
  };
  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
  updateScript = writeShellApplication {
    name = "update-zcode";
    runtimeInputs = [
      nix
      python3
    ];
    runtimeEnv.SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    text = ''
      exec python3 ${./update.py} "$PWD/packages/zcode"
    '';
    meta.mainProgram = "update-zcode";
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  passthru = {
    inherit src;
    updateScript = lib.getExe updateScript;
  };

  extraInstallCommands = ''
    install -Dm444 "${appimageContents}/zcode.desktop" \
      "$out/share/applications/zcode.desktop"
    substituteInPlace "$out/share/applications/zcode.desktop" \
      --replace-fail "Exec=AppRun --no-sandbox %U" "Exec=zcode --no-sandbox %U"

    for size in 16 24 32 48 64 128 256 512 1024; do
      install -Dm444 "${appimageContents}/usr/share/icons/hicolor/''${size}x''${size}/apps/zcode.png" \
        "$out/share/icons/hicolor/''${size}x''${size}/apps/zcode.png"
    done
  '';

  meta = {
    description = "AI coding agent desktop application from Z.ai";
    homepage = "https://zcode.z.ai/en";
    license = lib.licenses.unfree;
    mainProgram = "zcode";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
