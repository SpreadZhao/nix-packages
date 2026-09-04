{
  alsa-lib,
  autoPatchelfHook,
  dbus,
  dpkg,
  fetchurl,
  glib,
  gtk3,
  lib,
  libayatana-appindicator,
  nix-update-script,
  openssl,
  patchelf,
  stdenv,
  webkitgtk_4_1,
  wrapGAppsHook3,
  wtype,
  xdotool,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "opentypeless";
  version = "1.1.57";

  src = fetchurl {
    url = "https://github.com/tover0314-w/opentypeless/releases/download/v${finalAttrs.version}/OpenTypeless_${finalAttrs.version}_amd64.deb";
    hash = "sha256-J2j40vqSlbaNwnQxGKj3+LspXEEyChBQCbstvEHEmSI=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    patchelf
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    dbus
    glib
    gtk3
    libayatana-appindicator
    openssl
    stdenv.cc.cc.lib
    webkitgtk_4_1
    xdotool
  ];

  runtimeDependencies = [ libayatana-appindicator ];

  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" source
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a source/usr/. "$out/"
    patchelf --replace-needed libxdo.so.3 libxdo.so "$out/bin/opentypeless"
    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${
        lib.makeBinPath [
          wtype
          xdotool
        ]
      }
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]}
    )
  '';

  passthru.updateScript = nix-update-script {
    attrPath = "opentypeless";
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Open-source AI dictation and speech-to-text desktop app";
    homepage = "https://github.com/tover0314-w/opentypeless";
    changelog = "https://github.com/tover0314-w/opentypeless/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "opentypeless";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
