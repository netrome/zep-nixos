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

  # Installs hyprlock and, crucially, registers security.pam.services.hyprlock —
  # without the PAM service the lock screen cannot authenticate you back in.
  programs.hyprlock.enable = true;

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

    grim # screenshots
    slurp # region selection for the above

    # Bound to Print and friends; also useful to call from a terminal.
    # Always copies to the clipboard — pasting is the common case — and
    # additionally writes a file when passed "save".
    #
    # Feedback goes through `hyprctl notify`, which is built into the
    # compositor, so this works before a notification daemon exists.
    (pkgs.writeShellScriptBin "screenshot" ''
      set -eu

      mode=''${1:-region}
      save=''${2:-}

      case "$mode" in
        region)
          # slurp exits non-zero when cancelled with Escape; that is not an error.
          geom=$(${pkgs.slurp}/bin/slurp) || exit 0
          [ -n "$geom" ] || exit 0
          set -- -g "$geom"
          ;;
        window)
          geom=$(${pkgs.hyprland}/bin/hyprctl activewindow -j \
            | ${pkgs.jq}/bin/jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
          set -- -g "$geom"
          ;;
        output)
          set -- -o "$(${pkgs.hyprland}/bin/hyprctl monitors -j \
            | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name')"
          ;;
        *)
          echo "usage: screenshot [region|window|output] [save]" >&2
          exit 2
          ;;
      esac

      if [ -n "$save" ]; then
        dir=''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots
        mkdir -p "$dir"
        file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
        ${pkgs.grim}/bin/grim "$@" "$file"
        ${pkgs.wl-clipboard}/bin/wl-copy < "$file"
        ${pkgs.hyprland}/bin/hyprctl notify -1 2500 "rgb(00ff99)" "Screenshot saved: $file"
      else
        ${pkgs.grim}/bin/grim "$@" - | ${pkgs.wl-clipboard}/bin/wl-copy
        ${pkgs.hyprland}/bin/hyprctl notify -1 1500 "rgb(00ff99)" "Screenshot copied to clipboard"
      fi
    '')

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

    # Screen lock. The NixOS programs.hyprlock module above installs the package
    # and the PAM service; null keeps home-manager from adding a second copy.
    programs.hyprlock = lib.mkIf (name == "marten") {
      enable = true;
      package = null;
      settings = {
        general = {
          hide_cursor = true;
          grace = 0; # no "unlock without password" window
        };

        # Blurred snapshot of the session, so no wallpaper file is needed yet.
        background = [{
          path = "screenshot";
          blur_passes = 3;
          blur_size = 8;
        }];

        input-field = [{
          size = "300, 50";
          position = "0, -80";
          halign = "center";
          valign = "center";
          outline_thickness = 2;
          dots_center = true;
          fade_on_empty = false;
          placeholder_text = "<i>Password…</i>";
        }];

        label = [{
          text = "$TIME";
          font_size = 64;
          position = "0, 80";
          halign = "center";
          valign = "center";
        }];
      };
    };

    # Idle daemon. Chosen over swayidle because it honours all three inhibit
    # channels; swayidle cannot see org.freedesktop.ScreenSaver, which is one of
    # the two backends Firefox uses for the Screen Wake Lock API that Meet needs.
    services.hypridle = lib.mkIf (name == "marten") {
      enable = true;
      settings = {
        general = {
          # Everything locks via `loginctl lock-session` rather than by running
          # hyprlock directly, so logind's LockedHint stays truthful and D-Bus
          # consumers (compliance tooling, chrome.idle) can actually see it.
          lock_cmd = "${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
          before_sleep_cmd = "${pkgs.systemd}/bin/loginctl lock-session";
          after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";

          # Explicit rather than defaulted: honouring these is the entire reason
          # for picking hypridle. Flipping any to true reintroduces the Regolith
          # failure mode of locking mid-meeting.
          ignore_dbus_inhibit = false;
          ignore_systemd_inhibit = false;
          ignore_wayland_inhibit = false;
        };

        listener = [
          # 5 min: dim as a warning shot. Restored on any input.
          {
            timeout = 300;
            on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10";
            on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -r";
          }
          # Device is white:kbd_backlight on this machine — the upstream sample
          # config hardcodes rgb:kbd_backlight, which would fail silently here.
          {
            timeout = 300;
            on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -sd white:kbd_backlight set 0";
            on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -rd white:kbd_backlight";
          }
          # 10 min: lock.
          {
            timeout = 600;
            on-timeout = "${pkgs.systemd}/bin/loginctl lock-session";
          }
          # 11 min: display off.
          {
            timeout = 660;
            on-timeout = "${pkgs.hyprland}/bin/hyprctl dispatch dpms off";
            on-resume = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
          }
          # 30 min: suspend. before_sleep_cmd locks first.
          {
            timeout = 1800;
            on-timeout = "${pkgs.systemd}/bin/systemctl suspend";
          }
        ];
      };
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
