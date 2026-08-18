{ pkgs, lib, mindex, ... }:

let
  # Private key lives on the laptop (edo) and was never on this server.
  sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl4uMk/HNkQauwnCoX4nBWmEp0Qka4rQ7YNxBET/9w8 marten@edo";

  # Ad-hoc interpreter for all users. Defined here so the `python` shim below
  # points at the same wrapped environment.
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    requests
    ipython
  ]);
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
      AcceptEnv = [ "COLORTERM" ];
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
    mindex.packages.${pkgs.stdenv.hostPlatform.system}.default
    pythonEnv
    # nixpkgs only ships a `python3` binary; keep a `python` alias for
    # tools and muscle memory that expect the bare name.
    (writeShellScriptBin "python" ''exec ${pythonEnv}/bin/python3 "$@"'')
  ];

  environment.variables = {
    VISUAL = "hx";
    EDITOR = "hx";
  };

  # Machine-wide memory for Claude Code; loaded into every session on this
  # host regardless of user or repo.
  environment.etc."claude-code/CLAUDE.md".text = ''
    This machine (zep) is a headless NixOS server. Missing commands are normal:
    use `nix run`/`nix shell nixpkgs#<pkg>` for one-offs, `nix develop` for project
    dev shells, and propose config changes rather than installing imperatively.
    The system is managed declaratively — don't edit generated files under /etc.
  '';

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users = lib.genAttrs [ "marten" "dev" "dev-near" ] (name: {
    home.stateVersion = "26.05";

    programs.helix = {
      enable = true;
      settings = {
        theme = "dark_plus";
        editor = {
          auto-pairs = false;
          soft-wrap.enable = true;
          file-picker.hidden = false;
          end-of-line-diagnostics = "hint";
          insert-final-newline = false;
          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };
          inline-diagnostics.cursor-line = "warning";
        };
      };
    };

    # Drop git's default -X so less uses the alternate screen, letting the
    # terminal's alternate scroll mode translate the wheel into arrow keys.
    programs.git = {
      enable = true;
      settings.core.pager = "less -RF";
    };

    programs.tmux = {
      enable = true;
      mouse = true;
    };
  });

  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (lib.getName pkg) [ "claude-code" ];
}
