{ pkgs, lib, ... }:

let
  # Private key lives on the laptop (edo) and was never on this server.
  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl4uMk/HNkQauwnCoX4nBWmEp0Qka4rQ7YNxBET/9w8 marten@edo";
in
{
  networking.hostName = "zep";
  time.timeZone = "Europe/Berlin";
  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # Hetzner static assignment; matched on MAC so it survives interface renames.
  networking.useDHCP = false;
  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.MACAddress = "08:bf:b8:a6:95:d8";
    address = [
      "65.109.124.100/26"
      "2a01:4f9:3051:1806::2/64"
    ];
    routes = [
      { Gateway = "65.109.124.65"; }
      { Gateway = "fe80::1"; }
    ];
  };
  # Hetzner recursive resolvers
  networking.nameservers = [
    "185.12.64.1"
    "185.12.64.2"
    "2a01:4ff:ff00::add:1"
    "2a01:4ff:ff00::add:2"
  ];

  # Only SSH is reachable from outside. Anything served later must be
  # opened here explicitly.
  networking.firewall.enable = true;

  # Fresh host keys are generated on install. The pre-wipe host keys and
  # ~/.ssh/id_rsa were read during the 2026-07-28 incident — never restore them.
  services.openssh = {
    enable = true;
    ports = [ 8822 ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable =  true;
  };

  programs.starship.enable = true;

  programs.fzf = {
    keybindings = true;
    fuzzyCompletion = true;
  };

  programs.zoxide.enable = true;

  users.users = {
    marten = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = [ sshKey ];
    };
  } // lib.genAttrs [ "dev" "dev-near" ] (
    name: {
      isNormalUser = true;
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = [ sshKey ];
  });

  # Deploys run as marten via --use-remote-sudo; there is no password on the
  # account, so wheel must sudo without one. Root via SSH stays disabled.
  security.sudo.wheelNeedsPassword = false;

  nix.settings.trusted-users = [ "marten" ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  zramSwap.enable = true;

  environment.systemPackages = with pkgs; [
    git
    gh
    helix
    tmux
    ripgrep
    fd
    jq
    curl
    htop
    rsync
    claude-code
    tree
    fastfetch
    tokei
  ];

  environment.variables = {
    VISUAL = "hx";
    EDITOR = "hx";
  };

  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (lib.getName pkg) [ "claude-code" ];
}
