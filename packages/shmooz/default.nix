{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  libxkbcommon,
  wayland,
  wl-clipboard,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "shmooz";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "chmouel";
    repo = "shmooz";
    tag = "v${finalAttrs.version}";
    hash = "sha256-U7nF2P1RRmDWk2C0DyXzGh+7TUk0kF3kVXGiKyFLCPA=";
  };

  cargoHash = "sha256-EKrrv89MclJKaX0pVnpmUzMIso3pXyJt4IBJN1muRz0=";

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    libxkbcommon
    wayland
  ];

  postFixup = ''
    wrapProgram "$out/bin/shmooz" \
      --prefix PATH : ${lib.makeBinPath [ wl-clipboard ]}
  '';

  meta = {
    description = "Zoom, annotate, capture screenshots, and pick colors on Wayland";
    homepage = "https://github.com/chmouel/shmooz";
    changelog = "https://github.com/chmouel/shmooz/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "shmooz";
    platforms = lib.platforms.linux;
  };
})
