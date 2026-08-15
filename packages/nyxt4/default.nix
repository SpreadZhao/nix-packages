{
  appimageTools,
  buildFHSEnv,
  fetchurl,
  lib,
  nix-update-script,
  runCommand,
  writeShellScript,
  writeShellScriptBin,
}:

let
  pname = "nyxt";
  version = "4.0.0";

  releaseArchive = fetchurl {
    url = "https://github.com/atlas-engineer/nyxt/releases/download/${version}/Linux-Nyxt-x86_64.tar.gz";
    hash = "sha256-v+x6K5svLA3L+IjEdTjmJEf3hvgwhwrvqAcelpY1ScQ=";
  };

  nyxtAppImageFile = runCommand "nyxt-${version}.AppImage" { } ''
    tar xzf ${releaseArchive}
    install -Dm755 Nyxt-x86_64.AppImage "$out"
  '';

  nyxtAppImage = appimageTools.extract {
    inherit pname version;
    src = nyxtAppImageFile;
  };

  electronAppImage = appimageTools.extract {
    pname = "cl-electron-server";
    inherit version;
    src = "${nyxtAppImage}/usr/bin/cl-electron-server";
  };

  electronLauncher = writeShellScriptBin "cl-electron-server" ''
    export APPDIR=${electronAppImage}
    export LD_LIBRARY_PATH="${electronAppImage}/usr/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export XDG_DATA_DIRS="${electronAppImage}/usr/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
    export GSETTINGS_SCHEMA_DIR="${electronAppImage}/usr/share/glib-2.0/schemas''${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"

    exec ${electronAppImage}/cl-electron-server "$@"
  '';

  nyxtLauncher = writeShellScript "nyxt-launcher" ''
    export APPDIR=${nyxtAppImage}
    export LD_LIBRARY_PATH="${nyxtAppImage}/usr/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export PATH="${electronLauncher}/bin:$PATH"

    exec ${nyxtAppImage}/usr/bin/nyxt "$@"
  '';
in
buildFHSEnv (
  appimageTools.defaultFhsEnvArgs
  // {
    inherit pname version;

    targetPkgs =
      pkgs:
      appimageTools.defaultFhsEnvArgs.targetPkgs pkgs
      ++ [
        electronLauncher
        pkgs.wl-clipboard
      ];

    runScript = nyxtLauncher;

    extraInstallCommands = ''
      install -Dm444 "${nyxtAppImage}/nyxt.desktop" \
        "$out/share/applications/nyxt.desktop"
      substituteInPlace "$out/share/applications/nyxt.desktop" \
        --replace-fail "Exec=nyxt" "Exec=nyxt %U"
      install -Dm444 "${nyxtAppImage}/nyxt.png" \
        "$out/share/icons/hicolor/256x256/apps/nyxt.png"
    '';

    passthru = {
      src = releaseArchive;
      updateScript = nix-update-script {
        attrPath = "nyxt4";
        extraArgs = [ "--flake" ];
      };
    };

    meta = {
      description = "Infinitely extensible web browser using the Electron renderer";
      homepage = "https://nyxt.atlas.engineer";
      changelog = "https://github.com/atlas-engineer/nyxt/releases/tag/${version}";
      license = lib.licenses.bsd3;
      mainProgram = "nyxt";
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  }
)
