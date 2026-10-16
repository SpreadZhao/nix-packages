{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  alsa-lib,
  android-tools,
  pipewire,
  pulseaudio,
  wireplumber,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "micyou-cli";
  version = "2.1.1";

  # Upstream ships the standalone CLI in its desktop release archive.
  src = fetchurl {
    url = "https://github.com/MicYou-Dev/MicYou/releases/download/v${finalAttrs.version}/MicYou-Linux-${finalAttrs.version}.deb";
    hash = "sha256-08BK6OC5e4JoNmY7JA1M1lPPrWJbMnQt3cu3fIZR7Ow=";
  };

  licenseFile = fetchurl {
    url = "https://raw.githubusercontent.com/MicYou-Dev/MicYou/v${finalAttrs.version}/LICENSE";
    hash = "sha256-ljjhNJd95O4Ml0XPlOOixkwiUviAV/1QknMbnXTnWBY=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    stdenv.cc.cc.lib
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 usr/bin/micyou-cli "$out/bin/micyou-cli"
    # Preserve the resource path expected by the CLI's executable-relative
    # lookup. GUI/TUI binaries, icons and ONNX Runtime are intentionally omitted.
    install -Dm644 usr/lib/micyou/resources/alsa/micyou-pipewire.conf \
      "$out/lib/micyou/resources/alsa/micyou-pipewire.conf"
    install -Dm644 "$licenseFile" "$out/share/licenses/micyou-cli/LICENSE"
    install -m644 usr/lib/micyou/resources/LICENSE-*.txt "$out/share/licenses/micyou-cli/"

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/micyou-cli" \
      --prefix PATH : ${
        lib.makeBinPath [
          android-tools
          pipewire
          pulseaudio
          wireplumber
        ]
      } \
      --set ALSA_PLUGIN_DIR ${pipewire}/lib/alsa-lib
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/micyou-cli" --version | grep -Fx 'micyou-cli ${finalAttrs.version}'
    runHook postInstallCheck
  '';

  meta = {
    description = "Command-line server for using an Android phone as a microphone";
    homepage = "https://github.com/MicYou-Dev/MicYou";
    changelog = "https://github.com/MicYou-Dev/MicYou/releases/tag/v${finalAttrs.version}";
    # GPL-3.0-or-later with the upstream MicYou Plugin Exception.
    license = lib.licenses.gpl3Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "micyou-cli";
  };
})
