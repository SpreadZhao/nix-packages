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
  qt6,
  stdenv,
  wayland,
  zlib,
  zstd,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "bili23-downloader";
  version = "2.20.0";

  src = fetchurl {
    url = "https://github.com/ScottSloan/Bili23-Downloader/releases/download/v${finalAttrs.version}/Bili23-Downloader_${finalAttrs.version}_linux_amd64_portable.tar.gz";
    hash = "sha256-ZfjcVoX8JPMVsbamXgqJzsZq6lCGCV7QpImnu1Z/xp8=";
  };

  # The portable release embeds its icons in Qt resources. Fetch the desktop
  # icon from the matching upstream tag instead of the removed script path.
  desktopIcon = fetchurl {
    url = "https://raw.githubusercontent.com/ScottSloan/Bili23-Downloader/v${finalAttrs.version}/assets/app.svg";
    hash = "sha256-fsvds5q/pZd0rpEx1mz1xyQ2tk4H6g1fwnl63K80nnk=";
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
    # These unused plugins have dependencies omitted from the portable release.
    # In particular, mixing Nix's newer Qt keyboard libraries with bundled Qt
    # fails at runtime because their symbol versions differ.
    rm -f \
      "$out/opt/bili23-downloader/runtime/lib/python3.13/site-packages/PySide6/Qt/plugins/platformthemes/libqgtk3.so" \
      "$out/opt/bili23-downloader/runtime/lib/python3.13/site-packages/PySide6/Qt/plugins/imageformats/libqpdf.so" \
      "$out/opt/bili23-downloader/runtime/lib/python3.13/site-packages/PySide6/Qt/plugins/platforminputcontexts/libqtvirtualkeyboardplugin.so"
    chmod +x "$out/opt/bili23-downloader/bili23-downloader"
    chmod +x "$out/opt/bili23-downloader/bundle/ffmpeg"

    makeWrapper "$out/opt/bili23-downloader/bili23-downloader" "$out/bin/bili23-downloader" \
      --chdir "$out/opt/bili23-downloader"

    install -Dm444 "$desktopIcon" \
      "$out/share/icons/hicolor/scalable/apps/bili23-downloader.svg"

    runHook postInstall
  '';

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
