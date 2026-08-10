{ config, pkgs, lib, mindex, ... }:
{
  age.secrets.mindex-env.file = ./secrets/mindex-env.age;

  systemd.services.mindex = {
    description = "martex — mindex serving /home/marten/notes";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      User = "marten";
      Group = "users";
      ExecStart = lib.concatStringsSep " " [
        (lib.getExe mindex.packages.${pkgs.stdenv.hostPlatform.system}.default)
        "--root /home/marten/notes"
        "--app-name martex"
        "--auth-cookie-secure"
        "--port 3217"
      ];
      EnvironmentFile = config.age.secrets.mindex-env.path;
      Restart = "on-failure";
    };
  };

  services.caddy = {
    enable = true;
    globalConfig = "admin off";
    enableReload = false;
    virtualHosts."m.blankfors.se".extraConfig = ''
      reverse_proxy 127.0.0.1:3217
    '';
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
