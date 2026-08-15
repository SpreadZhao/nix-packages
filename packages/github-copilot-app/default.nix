{
  appimageTools,
  fetchurl,
  lib,
  nix-update-script,
}:

let
  pname = "github-copilot-app";
  version = "1.0.22";
  src = fetchurl {
    url = "https://github.com/github/app/releases/download/v${version}/GitHub-Copilot-linux-x64.AppImage";
    hash = "sha256-HgsvDy5nIu2bPFgSR7vPyfO6vHb3Vs6npI2hbMxNRAs=";
  };
  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  passthru = {
    inherit src;
    updateScript = nix-update-script {
      attrPath = pname;
      extraArgs = [ "--flake" ];
    };
  };

  extraInstallCommands = ''
    install -Dm444 "${appimageContents}/usr/share/applications/GitHub Copilot.desktop" \
      "$out/share/applications/github-copilot-app.desktop"
    substituteInPlace "$out/share/applications/github-copilot-app.desktop" \
      --replace-fail "Exec=github %u" "Exec=github-copilot-app %u" \
      --replace-fail "Icon=github" "Icon=github-copilot-app"
    install -Dm444 "${appimageContents}/usr/lib/GitHub Copilot/icons/icon.png" \
      "$out/share/icons/hicolor/512x512/apps/github-copilot-app.png"
  '';

  meta = {
    description = "GitHub Copilot desktop application";
    homepage = "https://github.com/github/app";
    license = lib.licenses.unfree;
    mainProgram = "github-copilot-app";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
