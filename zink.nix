{ config, pkgs, lib, zink, ... }:
let
  zink-relay = zink.packages.${pkgs.stdenv.hostPlatform.system}.zink-relay;
in
{
  systemd.services.zink-relay = {
    description = "zink relay (mailbox + blob cache + iroh relay server)";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment = {
      RUST_LOG = "info";
    };
    serviceConfig = {
      # No home-directory access needed: systemd runs this under a transient
      # uid and owns /var/lib/zink-relay for it, where the relay's identity
      # key, mailboxes, and blob cache persist across restarts.
      DynamicUser = true;
      StateDirectory = "zink-relay";
      ExecStart = lib.concatStringsSep " " [
        (lib.getExe zink-relay)
        "/var/lib/zink-relay"
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
