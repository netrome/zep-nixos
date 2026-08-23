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

  # The default is HandlePowerKey=poweroff — one unconfirmed press and the
  # machine is gone. Hyprland binds the short press to the power menu instead
  # (it sees the button as the "power-button" keyboard); a long press still
  # powers off directly, and holding it longer always triggers the firmware
  # cut-off regardless of any of this.
  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandlePowerKeyLongPress = "poweroff";
  };

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

    grim # screenshots; also on PATH for ad-hoc use
    slurp # region selection for the above

    # Chat. All three put an icon in waybar's tray module.
    slack # unfree — see allowUnfreePredicate below
    telegram-desktop
    zulip

    libnotify # notify-send, for testing that mako is alive

    # Scripts live in ./scripts/ rather than inline. writeShellApplication puts
    # runtimeInputs on PATH, so those files are plain shell with no Nix
    # interpolation — and it runs shellcheck on them at build time.
    (pkgs.writeShellApplication {
      name = "screenshot"; # Print and friends, see hyprland.lua
      runtimeInputs = with pkgs; [ grim slurp jq wl-clipboard hyprland coreutils ];
      text = builtins.readFile ./scripts/screenshot.sh;
    })

    (pkgs.writeShellApplication {
      name = "power-menu"; # Super+Shift+E and the physical power key
      runtimeInputs = with pkgs; [ fuzzel hyprland systemd ];
      text = builtins.readFile ./scripts/power-menu.sh;
    })

    # Wayland clipboard from the command line (wl-copy/wl-paste)
    wl-clipboard
  ];

  # Nothing on the system had icon glyphs, so starship's git-branch symbol and
  # anything in the bar rendered as tofu. This covers both.
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  # Required for the dconf database that carries the dark-mode setting. Without
  # it home-manager writes the keys but nothing reads them back.
  programs.dconf.enable = true;

  # Slack and Zulip are Electron. Without this they run under XWayland, which on
  # this panel means being upscaled from 1x to the 1.6 fractional scale — visibly
  # blurry. Native Wayland also gets them proper input handling and PipeWire
  # screen sharing through the portal.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # xdg-desktop-portal-hyprland (from programs.hyprland) handles screencast, but
  # not file chooser dialogs — without a GTK portal, "attach a file" in Slack
  # falls back to a poor or missing picker.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

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
          # Dispatchers go through hyprctl as *Lua*, not legacy names: this is a
          # Lua config, so `hyprctl dispatch dpms on` is a syntax error that
          # fails silently. hypridle's sample config assumes hyprlang.
          after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms(\"on\")'";

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
            on-timeout = "${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms(\"off\")'";
            on-resume = "${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms(\"on\")'";
          }
          # 30 min: suspend. before_sleep_cmd locks first.
          {
            timeout = 1800;
            on-timeout = "${pkgs.systemd}/bin/systemctl suspend";
          }
        ];
      };
    };

    # Dark theme. Four mechanisms have to agree or half the apps come out light:
    #
    #   GTK3      gtk-application-prefer-dark-theme in settings.ini
    #   GTK4/adw  gtk-interface-color-scheme (GTK4 ignores gtk-theme-name)
    #   portal    dconf org.gnome.desktop.interface color-scheme, which
    #             xdg-desktop-portal-gtk republishes as
    #             org.freedesktop.appearance — this is the one Electron (Slack,
    #             Zulip) and Firefox actually read
    #   Qt        QT_QPA_PLATFORMTHEME, so Telegram follows GTK
    #
    # home-manager's gtk module drives the first three off `colorScheme`.
    # adw-gtk3-dark rather than Adwaita-dark so GTK3 apps match libadwaita ones.
    gtk = lib.mkIf (name == "marten") {
      enable = true;
      colorScheme = "dark";
      theme = {
        name = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
    };

    qt = lib.mkIf (name == "marten") {
      enable = true;
      platformTheme.name = "gtk3";
    };

    # Also fixes waybar's "Unable to load hand2 from the cursor theme" — nothing
    # declared a cursor theme before. x11.enable is what exports XCURSOR_THEME.
    home.pointerCursor = lib.mkIf (name == "marten") {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
      gtk.enable = true;
      x11.enable = true;
      hyprcursor.enable = true;
    };

    # Notification daemon. mako over dunst/swaync: Wayland-native, tiny, and its
    # config is a dozen declarative lines. swaync would add a notification
    # *centre* with scrollback — worth revisiting if Slack pings get missed.
    services.mako = lib.mkIf (name == "marten") {
      enable = true;
      settings = {
        font = "JetBrainsMono Nerd Font 11";
        width = 380;
        margin = "10";
        padding = "12,16";
        border-size = 2;
        border-radius = 8;
        background-color = "#1a1a1aeb";
        text-color = "#e6e6e6";
        border-color = "#33ccff";
        progress-color = "over #00ff99";
        default-timeout = 6000;
        anchor = "top-right";
        max-visible = 5;

        # Critical notifications stay until dismissed rather than timing out.
        "urgency=critical" = {
          border-color = "#ff5555";
          default-timeout = 0;
        };

        # Backs the Super+Shift+N do-not-disturb toggle.
        "mode=do-not-disturb" = {
          invisible = 1;
        };
      };
    };

    programs.waybar = lib.mkIf (name == "marten") {
      enable = true;
      systemd.enable = true; # starts with hyprland-session.target, like hypridle

      settings.mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 6;

        modules-left = [ "hyprland/workspaces" "hyprland/submap" ];
        modules-center = [ "hyprland/window" ];
        modules-right = [
          "tray"
          "idle_inhibitor"
          "pulseaudio"
          "backlight"
          "network"
          "battery"
          "clock"
        ];

        "hyprland/workspaces".on-click = "activate";

        # Shows "resize" while Super+R's submap is active, so the modal state
        # is visible rather than something you discover by pressing keys.
        "hyprland/submap" = {
          format = "󰌌 {}";
          tooltip = false;
        };

        "hyprland/window" = {
          format = "{title}";
          max-length = 60;
          separate-outputs = true;
        };

        tray.spacing = 10; # Slack et al. live here

        # Manual override for the idle lock. Uses the Wayland idle-inhibit
        # protocol — the same channel hypridle honours — so this is a supported
        # "don't lock right now", not a hack.
        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "󰅶";
            deactivated = "󰛊";
          };
          tooltip-format-activated = "Idle inhibited — screen will not lock";
          tooltip-format-deactivated = "Idle lock active";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = "󰝟 muted";
          format-icons.default = [ "󰕿" "󰖀" "󰕾" ];
          on-click = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };

        backlight = {
          device = "intel_backlight";
          format = "󰃟 {percent}%";
        };

        network = {
          format-wifi = "󰤨 {essid}";
          format-ethernet = "󰈀 wired";
          format-disconnected = "󰤭 offline";
          tooltip-format = "{ifname}: {ipaddr}";
        };

        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = "󰂄 {capacity}%";
          format-plugged = "󰚥 {capacity}%";
          format-icons = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
          tooltip-format = "{timeTo} — {power}W";
        };

        clock = {
          format = "{:%H:%M}";
          format-alt = "{:%Y-%m-%d %H:%M}"; # click to toggle
          tooltip-format = "<tt>{calendar}</tt>";
        };
      };

      style = builtins.readFile ./waybar-style.css;
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
    pkg: builtins.elem (lib.getName pkg) [ "claude-code" "slack" ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
