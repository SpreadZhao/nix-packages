{ pkgs, mkJetBrainsIde }:

let
  directoryPlugin = pkgs.runCommand "fixture-directory-plugin" { } ''
    mkdir -p "$out/lib"
    touch "$out/lib/plugin.jar"
  '';
  jarPlugin = pkgs.writeText "fixture-plugin.jar" "fixture jar";
  runtime = pkgs.writeShellScriptBin "jetbrains-runtime-fixture" ''
    printf 'runtime-ok\n'
  '';
  upstream =
    pkgs.runCommand "fixture-ide-1.0"
      {
        pname = "fixture-ide";
        version = "1.0";
        meta.mainProgram = "fixture-ide";
      }
      ''
        mkdir -p "$out/bin" "$out/share/applications"
        cat > "$out/bin/fixture-ide" <<'EOF'
        #!${pkgs.runtimeShell}
        printf '%s\n' "$FIXTURE_PROPERTIES"
        printf '<%s>\n' "$@"
        printf '%s\n' "$FIXTURE_ENVIRONMENT"
        jetbrains-runtime-fixture
        EOF
        chmod +x "$out/bin/fixture-ide"
        echo 'Exec=fixture-ide %f' > "$out/share/applications/fixture-ide.desktop"
      '';
  configured = mkJetBrainsIde {
    inherit pkgs;
    package = upstream;
    plugins = [
      directoryPlugin
      jarPlugin
    ];
    propertiesEnv = "FIXTURE_PROPERTIES";
    extraProperties."idea.config.path" = "/tmp/fixture-config";
    runtimePackages = [ runtime ];
    environment.FIXTURE_ENVIRONMENT = "value with spaces";
  };
in
pkgs.runCommand "jetbrains-wrapper-check" { } ''
  test -d ${configured.pluginDirectory}/${builtins.baseNameOf (toString directoryPlugin)}/lib
  test -f ${configured.pluginDirectory}/${builtins.baseNameOf (toString jarPlugin)}
  grep -F 'idea.plugins.path = ${configured.pluginDirectory}' ${configured.properties}
  grep -F 'idea.config.path = /tmp/fixture-config' ${configured.properties}
  ${configured}/bin/fixture-ide --flag 'argument with spaces' > actual
  printf '%s\n<--flag>\n<argument with spaces>\nvalue with spaces\nruntime-ok\n' ${configured.properties} > expected
  diff -u expected actual
  test -x ${upstream}/bin/fixture-ide
  cmp ${upstream}/share/applications/fixture-ide.desktop ${configured}/share/applications/fixture-ide.desktop
  touch "$out"
''
