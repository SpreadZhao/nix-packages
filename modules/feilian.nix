{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.feilian;
in
{
  options.services.feilian = {
    enable = lib.mkEnableOption "the FeiLian (SealSuite) client and VPN daemon";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../packages/feilian { };
      defaultText = lib.literalExpression "pkgs.callPackage ../packages/feilian { }";
      description = "FeiLian package, including its unwrapped vendor files and service launcher.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.networking.networkmanager.enable;
        message = "services.feilian requires networking.networkmanager.enable.";
      }
    ];

    environment.systemPackages = [ cfg.package ];
    boot.kernelModules = [ "tun" ];
    environment.etc = {
      "NetworkManager/dnsmasq.d/corplink.conf".source =
        "${cfg.package.unwrapped}/share/feilian/corplink-dnsmasq.conf";
      "xdg/autostart/corplink-uc-ui.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=FeiLian user helper
        Exec=${cfg.package}/bin/feilian-user-helper
        Terminal=false
        StartupNotify=false
      '';
    };
    systemd.tmpfiles.rules = [
      "d /etc/NetworkManager/conf.d 0755 root root -"
    ];

    systemd.services.corplink = {
      description = "FeiLian VPN and endpoint service";
      wantedBy = [ "multi-user.target" ];
      wants = [ "NetworkManager.service" ];
      after = [ "NetworkManager.service" ];
      path = [
        pkgs.coreutils
        pkgs.rsync
      ];
      # The vendor writes beside its binaries. Refresh shipped files when the
      # package changes, preserving generated configs, certificates and logs.
      preStart = ''
        source=${lib.escapeShellArg "${cfg.package.unwrapped}/libexec/feilian"}
        installed="$(cat /var/lib/feilian/.nix-package 2>/dev/null || true)"
        if [[ "$installed" != "$source" ]]; then
          rsync -rlt --chmod=u+w "$source/" /var/lib/feilian/
          mkdir -p /var/lib/feilian/data/edlp/back_paks/{ui,cfg}
          printf '%s\n' "$source" > /var/lib/feilian/.nix-package
        fi
      '';
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/feilian-service";
        ExecStopPost = "${pkgs.coreutils}/bin/rm -f /etc/NetworkManager/conf.d/corplink-nm.conf";
        StateDirectory = "feilian";
        StateDirectoryMode = "0755";
        WorkingDirectory = "/var/lib/feilian";
        Restart = "always";
        RestartSec = "3s";
        KillMode = "control-group";
      };
    };
  };
}
