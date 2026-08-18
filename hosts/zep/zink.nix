{ config, pkgs, lib, zink, ... }:
let
  zink-relay = zink.packages.${pkgs.stdenv.hostPlatform.system}.zink-relay;
in
{
  # Relay state (identity key, mailboxes, blob cache) lives on the data disk
  # so a flood of blob pushes can't pressure the system drive. A static user
  # instead of DynamicUser: systemd only manages ownership for state under
  # /var/lib, so for /data we create the directory ourselves via tmpfiles.
  users.users.zink-relay = {
    isSystemUser = true;
    group = "zink-relay";
  };
  users.groups.zink-relay = { };

  systemd.tmpfiles.rules = [
    "d /data/zink-relay 0750 zink-relay zink-relay -"
  ];

  systemd.services.zink-relay = {
    description = "zink relay (mailbox + blob cache + iroh relay server)";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment = {
      RUST_LOG = "info";
    };
    serviceConfig = {
      User = "zink-relay";
      Group = "zink-relay";
      ExecStart = lib.concatStringsSep " " [
        (lib.getExe zink-relay)
        "/data/zink-relay"
        # Fixed ports so the printed dial spec survives restarts.
        "--port 4400"
        "--relay-port 4401"
      ];
      Restart = "always";
      RestartSec = 5;
    };
  };

  # UDP 4400: the iroh QUIC endpoint (mailbox + blobs).
  # TCP 4401: the embedded iroh relay's HTTP server (rendezvous/holepunch).
  # UDP 4401: QUIC address discovery, same-port convention with the relay port.
  networking.firewall.allowedUDPPorts = [ 4400 4401 ];
  networking.firewall.allowedTCPPorts = [ 4401 ];
}
