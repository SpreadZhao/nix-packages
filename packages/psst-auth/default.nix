{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  fontconfig,
  libxkbcommon,
  systemd,
  wayland,
  libGL,
  vulkan-loader,
}:

# This is phisch's authentication UI, not the psst Spotify client in nixpkgs.
rustPlatform.buildRustPackage {
  pname = "psst-auth";
  version = "0.2.0-unstable-2026-06-22";

  src = fetchFromGitHub {
    owner = "phisch";
    repo = "psst";
    rev = "851c599c599e1dbaba48c6336ff41971f210826e";
    hash = "sha256-BgHRx6RQs1wB31Gu0LMDnsS4C2DUghbc4iQFXsGJi3g=";
  };

  cargoHash = "sha256-H1mmA9x8iXib18+7JJt+AB1SEogbkmGA7HzX0AytXOE=";
  cargoBuildFlags = [
    "-p"
    "pinentry"
    "-p"
    "polkit-agent"
  ];
  cargoTestFlags = [
    "-p"
    "pinentry"
    "-p"
    "polkit-agent"
    "-p"
    "theme"
  ];

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];
  buildInputs = [
    fontconfig
    libxkbcommon
    systemd
    wayland
  ];

  # GPUI loads the graphics and Wayland libraries at runtime.
  postFixup = ''
    for program in psst-pinentry psst-polkit-agent; do
      patchelf --add-rpath ${
        lib.makeLibraryPath [
          libGL
          vulkan-loader
          wayland
        ]
      } "$out/bin/$program"
    done
  '';

  meta = {
    description = "Shared Wayland password UI for Pinentry and Polkit";
    homepage = "https://github.com/phisch/psst";
    license = with lib.licenses; [
      mpl20
      gpl3Plus
    ];
    platforms = lib.platforms.linux;
    mainProgram = "psst-pinentry";
  };
}
