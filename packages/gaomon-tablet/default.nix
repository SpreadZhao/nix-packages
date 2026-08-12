{
  coreutils,
  dbus,
  fetchurl,
  fontconfig,
  freetype,
  glib,
  glibc,
  krb5,
  lib,
  libGL,
  libusb1,
  libX11,
  libXext,
  libXinerama,
  libXrandr,
  libXtst,
  libxcb,
  libxkbcommon,
  patchelf,
  procps,
  stdenv,
  systemd,
  util-linux,
  xdotool,
  zlib,
}:

let
  pname = "gaomon-tablet";
  version = "16.0.0.49";
  runtimeLibraries = [
    dbus
    fontconfig
    freetype
    glib
    glibc
    krb5
    libGL
    libusb1
    libX11
    libXext
    libXinerama
    libXrandr
    libXtst
    libxcb
    libxkbcommon
    stdenv.cc.cc.lib
    systemd
    zlib
  ];
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://driver.gaomon.cn/download/Driver/Linux/GaomonTablet_LinuxDriver_v${version}.x86_64.tar.xz";
    hash = "sha256-37FX3mZYGO7LeGtFusyL9rc3SE7yQFZ8kqd6mTv+NYs=";
    curlOptsList = [
      "-A"
      "Mozilla/5.0"
      "-e"
      "https://www.gaomon.cn/download/"
    ];
  };

  sourceRoot = "gaomon";
  dontBuild = true;

  nativeBuildInputs = [ patchelf ];

  installPhase = ''
    runHook preInstall

    appDir="$out/libexec/gaomontablet"
    mkdir -p "$appDir" "$out/bin"
    cp -a gaomontablet/. "$appDir/"

    patchShebangs "$appDir"
    substituteInPlace "$appDir/screenshot" \
      --replace-fail \
        'readonly SCREENSHOT_TARGET_DIR="/usr/lib/huiontablet/res"' \
        'readonly SCREENSHOT_TARGET_DIR="''${GAOMON_TABLET_RUNTIME_DIR:?}/res"'

    runtimeLibraryPath=${lib.escapeShellArg (lib.makeLibraryPath runtimeLibraries)}
    while IFS= read -r -d "" file; do
      if oldRpath="$(patchelf --print-rpath "$file" 2>/dev/null)"; then
        patchelf --set-rpath "''${oldRpath:+$oldRpath:}$runtimeLibraryPath" "$file"
        if interpreter="$(patchelf --print-interpreter "$file" 2>/dev/null)" \
          && [[ -n "$interpreter" ]]; then
          patchelf --set-interpreter ${lib.escapeShellArg stdenv.cc.bintools.dynamicLinker} "$file"
        fi
      fi
    done < <(find "$appDir" -type f -print0)

    install -Dm755 ${./gaomon-tablet.sh} "$out/bin/gaomon-tablet"
    install -Dm755 ${./gaomon-tablet.sh} "$out/bin/gaomon-tablet-core"
    substituteInPlace "$out/bin/gaomon-tablet" "$out/bin/gaomon-tablet-core" \
      --subst-var-by appDir "$appDir" \
      --subst-var-by runtimePath ${
        lib.escapeShellArg (
          lib.makeBinPath [
            coreutils
            procps
            util-linux
            xdotool
          ]
        )
      } \
      --subst-var-by version "$version"
    patchShebangs "$out/bin"

    install -Dm444 share/applications/gaomontablet.desktop \
      "$out/share/applications/gaomontablet.desktop"
    substituteInPlace "$out/share/applications/gaomontablet.desktop" \
      --replace-fail "/usr/lib/gaomontablet/gaomontablet.sh manual_launch" \
        "gaomon-tablet manual_launch" \
      --replace-fail "/usr/share/icons/gaomontablet.png" "gaomontablet"
    install -Dm444 icon/gaomontablet.png \
      "$out/share/icons/hicolor/256x256/apps/gaomontablet.png"
    install -Dm444 ${./70-gaomon-m5.rules} \
      "$out/lib/udev/rules.d/70-gaomon-m5.rules"
    install -Dm444 "$appDir/LGPL" \
      "$out/share/licenses/${pname}/LGPL"

    runHook postInstall
  '';

  meta = {
    description = "Official GAOMON tablet driver for the M5 V2";
    homepage = "https://www.gaomon.cn/download/";
    license = lib.licenses.unfree;
    mainProgram = "gaomon-tablet";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
