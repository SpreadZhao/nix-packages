{
  buildFHSEnv,
  cacert,
  dpkg,
  fetchurl,
  lib,
  nix,
  python3,
  stdenvNoCC,
  symlinkJoin,
  writeShellApplication,
  writeShellScript,
  writeShellScriptBin,
}:

let
  pname = "feilian";
  sourceInfo = lib.importJSON ./source.json;
  inherit (sourceInfo) version;
  appDir = "/opt/apps/com.volcengine.feilian/files";
  src = fetchurl {
    inherit (sourceInfo) url hash;
  };
  meta = {
    description = "FeiLian (SealSuite) enterprise network and endpoint security client";
    homepage = "https://www.volcengine.com/product/feilian/download";
    license = lib.licenses.unfree;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
  # Keep the signed vendor binaries intact; run them in an FHS environment.
  unwrapped = stdenvNoCC.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version src;
    nativeBuildInputs = [ dpkg ];
    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x "$src" .
      runHook postUnpack
    '';
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/libexec" "$out/share/applications" "$out/share/icons"
      cp -a opt/apps/com.volcengine.feilian/files "$out/libexec/feilian"
      cp -a usr/share/icons/hicolor "$out/share/icons/"
      cp usr/share/applications/corplink.desktop "$out/share/applications/feilian.desktop"
      substituteInPlace "$out/share/applications/feilian.desktop" \
        --replace-fail "Exec=env NODE_ENV=production ${appDir}/corplink --no-sandbox %U" \
          "Exec=feilian %U"
      install -Dm444 etc/NetworkManager/dnsmasq.d/corplink.conf \
        "$out/share/feilian/corplink-dnsmasq.conf"
      runHook postInstall
    '';
    inherit meta;
  };
  fhsArgs = {
    inherit version;
    targetPkgs =
      pkgs: with pkgs; [
        alsa-lib
        at-spi2-atk
        at-spi2-core
        atk
        audit
        bash
        cairo
        coreutils
        cups
        dbus
        dnsmasq
        expat
        gdk-pixbuf
        glib
        gtk3
        iproute2
        iptables
        iw
        libcanberra-gtk3
        libdrm
        libgbm
        libGL
        libhandy
        libselinux
        libX11
        libXcomposite
        libXcursor
        libXdamage
        libXext
        libXfixes
        libXi
        libXrandr
        libXrender
        libXtst
        libxcb
        libxcrypt-legacy
        libxkbcommon
        networkmanager
        nspr
        nss
        nss.tools
        pango
        procps
        stdenv.cc.cc.lib
        systemd
        udisks2
        util-linux
        zlib
      ];
    multiPkgs = _: [ ];
    # Share the real network namespace, system bus, and NetworkManager config.
    extraBwrapArgs = [
      "--bind-try /var/lib/feilian ${appDir}"
      "--bind /etc/NetworkManager /etc/NetworkManager"
    ];
  };
  guiEnv = buildFHSEnv (
    fhsArgs
    // {
      inherit pname;
      runScript = writeShellScript "feilian-launch" ''
        if [[ ! -x ${appDir}/corplink ]]; then
          echo "FeiLian needs the NixOS module: enable services.feilian first." >&2
          exit 1
        fi
        export NODE_ENV=production
        cd ${appDir}
        if [[ "''${1:-}" == --user-helper ]]; then
          shift
          exec ./bin/corplink-uc --cmd=normal --switch-process-privilege=user \
            --switch-smaster-process "$@"
        fi
        exec ./corplink --no-sandbox "$@"
      '';
    }
  );
  serviceEnv = buildFHSEnv (
    fhsArgs
    // {
      pname = "feilian-service";
      runScript = "${appDir}/corplink-service";
      # The root daemon configures the host VPN interface and starts helpers.
      extraBwrapArgs = fhsArgs.extraBwrapArgs ++ [ "--cap-add ALL" ];
    }
  );
  userHelper = writeShellScriptBin "feilian-user-helper" ''
    exec ${lib.getExe guiEnv} --user-helper "$@"
  '';
  updateScript = writeShellApplication {
    name = "update-feilian";
    runtimeInputs = [
      nix
      python3
    ];
    runtimeEnv.SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    text = ''
      exec python3 ${./update.py} "$PWD/packages/feilian"
    '';
  };
in
symlinkJoin {
  name = "${pname}-${version}";
  paths = [
    guiEnv
    serviceEnv
    userHelper
  ];
  postBuild = ''
    cp -a ${unwrapped}/share/. "$out/share/"
  '';
  passthru = {
    inherit
      src
      unwrapped
      guiEnv
      serviceEnv
      version
      ;
    updateScript = lib.getExe updateScript;
  };
  inherit meta;
}
