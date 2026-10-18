{
  pkgs,
  package,
  plugins,
  propertiesEnv,
  extraProperties ? { },
  runtimePackages ? [ ],
  environment ? { },
}:

let
  inherit (pkgs) lib;
  mainProgram = package.meta.mainProgram;
  pluginDirectory = pkgs.runCommand "${package.pname}-managed-plugins" { } ''
    mkdir -p "$out"
    ${lib.concatMapStringsSep "\n" (plugin: ''
      ln -s ${lib.escapeShellArg (toString plugin)} "$out/${builtins.baseNameOf (toString plugin)}"
    '') (lib.unique plugins)}
  '';
  properties = (pkgs.formats.javaProperties { }).generate "${package.pname}-managed.properties" (
    extraProperties
    // {
      "idea.plugins.path" = toString pluginDirectory;
    }
  );
  wrapperArgs = [
    "--set"
    propertiesEnv
    (toString properties)
  ]
  ++ lib.concatLists (
    lib.mapAttrsToList (name: value: [
      "--set"
      name
      value
    ]) environment
  )
  ++ lib.optionals (runtimePackages != [ ]) [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath runtimePackages)
  ];
  validVariable = name: builtins.match "[A-Z_][A-Z0-9_]*" name != null;
in
assert lib.assertMsg (validVariable propertiesEnv)
  "propertiesEnv must be an environment variable name";
assert lib.assertMsg (lib.all validVariable (
  builtins.attrNames environment
)) "environment keys must be environment variable names";
pkgs.symlinkJoin {
  pname = "${package.pname}-configured";
  inherit (package) version;
  paths = [ package ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    # Remove only the link created by symlinkJoin, never the upstream executable.
    rm "$out/bin/${mainProgram}"
    makeWrapper ${lib.getExe package} "$out/bin/${mainProgram}" ${lib.escapeShellArgs wrapperArgs}
  '';
  passthru = {
    inherit
      package
      plugins
      pluginDirectory
      properties
      ;
  };
  inherit (package) meta;
}
