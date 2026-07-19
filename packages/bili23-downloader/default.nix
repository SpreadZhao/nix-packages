{
  autoPatchelfHook,
  copyDesktopItems,
  dbus,
  fetchurl,
  fontconfig,
  freetype,
  glib,
  lib,
  libGL,
  libdrm,
  libx11,
  libxcb,
  libxcb-cursor,
  libxcb-image,
  libxcb-keysyms,
  libxcb-render-util,
  libxcb-util,
  libxcb-wm,
  libxkbcommon,
  makeDesktopItem,
  makeWrapper,
  nix-update-script,
  qt6,
  stdenv,
  wayland,
  zlib,
  zstd,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "bili23-downloader";
  version = "2.10.4";

  src = fetchurl {
    url = "https://github.com/ScottSloan/Bili23-Downloader/releases/download/v${finalAttrs.version}/Bili23-Downloader_${finalAttrs.version}_linux_amd64_portable.tar.gz";
    hash = "sha256-+MWn7hNwh5NAk23ASxh484ekLZTKNDcN1gS3DRn6YC0=";
  };

  sourceRoot = "Bili23-Downloader";

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    makeWrapper
  ];

  buildInputs = [
    dbus
    fontconfig
    freetype
    glib
    libGL
    libdrm
    libx11
    libxcb
    libxcb-cursor
    libxcb-image
    libxcb-keysyms
    libxcb-render-util
    libxcb-util
    libxcb-wm
    libxkbcommon
    qt6.qt3d
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwayland
    stdenv.cc.cc.lib
    wayland
    zlib
    zstd
  ];

  dontBuild = true;
  dontWrapQtApps = true;

  desktopItems = [
    (makeDesktopItem {
      name = "bili23-downloader";
      exec = "bili23-downloader %U";
      icon = "bili23-downloader";
      desktopName = "Bili23 Downloader";
      genericName = "Bilibili Video Downloader";
      comment = "Cross-platform Bilibili video downloader";
      categories = [
        "AudioVideo"
        "Network"
      ];
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/opt/bili23-downloader" "$out/bin"
    cp -R . "$out/opt/bili23-downloader/"
    chmod -R u+w "$out/opt/bili23-downloader"
    rm -f \
      "$out/opt/bili23-downloader/runtime/lib/python3.13/site-packages/PySide6/Qt/plugins/platformthemes/libqgtk3.so" \
      "$out/opt/bili23-downloader/runtime/lib/python3.13/site-packages/PySide6/Qt/plugins/imageformats/libqpdf.so"
    chmod +x "$out/opt/bili23-downloader/bili23-downloader"
    chmod +x "$out/opt/bili23-downloader/bundle/ffmpeg"

    makeWrapper "$out/opt/bili23-downloader/bili23-downloader" "$out/bin/bili23-downloader" \
      --chdir "$out/opt/bili23-downloader"

    install -Dm444 "$out/opt/bili23-downloader/script/res/icon/app.svg" \
      "$out/share/icons/hicolor/scalable/apps/bili23-downloader.svg"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    attrPath = finalAttrs.pname;
    extraArgs = [ "--flake" ];
  };

  meta = {
    description = "Cross-platform Bilibili video downloader";
    homepage = "https://github.com/ScottSloan/Bili23-Downloader";
    changelog = "https://github.com/ScottSloan/Bili23-Downloader/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "bili23-downloader";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
