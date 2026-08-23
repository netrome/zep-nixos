{ pkgs, lib, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Keeping hostname == flake attribute name lets `nixos-rebuild --flake .`
  # pick the right config automatically. Rename both together if you rename.
  networking.hostName = "edo";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "sv_SE.UTF-8";
    LC_NUMERIC = "sv_SE.UTF-8";
    LC_MONETARY = "sv_SE.UTF-8";
    LC_MEASUREMENT = "sv_SE.UTF-8";
    LC_PAPER = "sv_SE.UTF-8";
  };
  console.keyMap = "sv-latin1";

  # Fan control, keyboard backlight, etc. for TUXEDO hardware
  hardware.tuxedo-drivers.enable = true;

  zramSwap.enable = true;

  users.users.marten = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
    initialPassword = "changeme";
  };

  # Secondary account for running claude-code, like on zep. No password —
  # reach it with `sudo -iu dev`.
  users.users.dev = {
    isNormalUser = true;
    shell = pkgs.zsh;
  };
  # Same shell stack as zep.
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };

  programs.starship.enable = true;

  programs.fzf = {
    keybindings = true;
    fuzzyCompletion = true;
  };

  programs.zoxide.enable = true;

  programs.hyprland.enable = true;

  # Sound server; the hyprland.lua volume keys drive it via wpctl.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  environment.systemPackages = with pkgs; [
    alacritty
    git
    vim
    firefox
    ripgrep
    fd
    jq
    curl
    htop
    tree
    fastfetch
    tokei
    claude-code
    # Referenced by hyprland.lua keybindings:
    kdePackages.dolphin # Super+E
    brightnessctl # XF86MonBrightness keys
    playerctl # XF86Audio media keys

    # Super+Shift+E. Exiting used to be a single unconfirmed keypress (Super+M),
    # which is an easy way to lose a session by accident.
    (pkgs.writeShellScriptBin "hypr-exit" ''
      choice=$(printf 'Cancel\nExit Hyprland\n' \
        | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt 'Exit Hyprland? ')
      [ "$choice" = "Exit Hyprland" ] && exec ${pkgs.hyprland}/bin/hyprctl dispatch exit
    '')
    # Wayland clipboard from the command line (wl-copy/wl-paste)
    wl-clipboard
  ];

  environment.variables = {
    VISUAL = "hx";
    EDITOR = "hx";
  };

  # Machine-wide memory for Claude Code; loaded into every session on this
  # host regardless of user or repo.
  environment.etc."claude-code/CLAUDE.md".text = ''
    This machine (edo) is a NixOS laptop managed declaratively from the
    zep-nixos flake repo. Don't install software imperatively or edit
    generated files under /etc — propose changes to the flake instead.
  '';

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users = lib.genAttrs [ "marten" "dev" ] (name: {
    home.stateVersion = "26.05";

    # marten-only: dev doesn't run a graphical session. The config itself
    # lives in ./hyprland.lua; edits apply via nixos-rebuild + hyprctl reload.
    wayland.windowManager.hyprland = lib.mkIf (name == "marten") {
      enable = true;
      # The NixOS module (programs.hyprland) already installs Hyprland and
      # its xdg portal; null stops home-manager from pulling in second copies.
      package = null;
      portalPackage = null;
      # Explicit because the default is stateVersion-dependent, and the wrong
      # value would feed Lua to the hyprlang parser.
      configType = "lua";
      extraConfig = builtins.readFile ./hyprland.lua;
    };

    # Application launcher, on Super+Space and Super+D.
    programs.fuzzel = lib.mkIf (name == "marten") {
      enable = true;
      settings.main = {
        terminal = "${pkgs.alacritty}/bin/alacritty";
        layer = "overlay";
        lines = 12;
        width = 45;
      };
    };

    # Same helix setup as zep.
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

    programs.git = {
      enable = true;
      settings = {
        user.name = "Mårten Blankfors";
        user.email = "marten@blankfors.se";

        # Drop git's default -X so less uses the alternate screen, letting the
        # terminal's alternate scroll mode translate the wheel into arrow keys.
        core.pager = "less -RF";

        init.defaultBranch = "main";
        push.autoSetupRemote = true;
      };
    };

    programs.tmux = {
      enable = true;
      mouse = true;
    };
  });

  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (lib.getName pkg) [ "claude-code" ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
