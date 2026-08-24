{ config, pkgs, lib, ... }:

let
  # Users that push to GitHub over HTTPS. Each needs a matching
  # secrets/github-pat-<user>.age holding the two lines git's credential
  # protocol expects, and nothing else:
  #
  #   username=<github login>
  #   password=<the PAT>
  #
  # Keep the tokens fine-grained and scoped per user (see README) — a token
  # here is readable by that user, so it is exactly as trusted as the agent
  # sessions running under it.
  patUsers = [ "dev-near" ];

  secretName = user: "github-pat-${user}";

  # git-credential-store is deliberately not used. It rewrites its file after
  # every successful auth, even when the credential is unchanged, and the
  # agenix secret lives at 0400 on a root-owned tmpfs — so each push would
  # print "fatal: unable to get credential storage lock". This helper only
  # answers `get`; `store` and `erase` are no-ops.
  helperFor = user: pkgs.writeShellScript "git-credential-${user}" ''
    [ "$1" = get ] || exit 0
    exec ${pkgs.coreutils}/bin/cat ${config.age.secrets.${secretName user}.path}
  '';
in
{
  age.secrets = lib.genAttrs (map secretName patUsers) (name: {
    file = ../../secrets/${name}.age;
    # agenix decrypts as root; hand the plaintext to the one user that needs it.
    owner = lib.removePrefix "github-pat-" name;
    group = "users";
    mode = "0400";
  });

  # Scoped to github.com so the token is never offered to another host.
  home-manager.users = lib.genAttrs patUsers (user: {
    programs.git.settings.credential."https://github.com".helper =
      "${helperFor user}";
  });
}
