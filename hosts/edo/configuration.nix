{ pkgs, lib, slackmdSrc, mojimeSrc, nearCliSrc, ... }:
let
  # Sources come from flake inputs (flake = false), so revisions are pinned in
  # flake.lock and bumped with `nix flake update slackmd mojime near-cli-rs`.
  slackmd = pkgs.callPackage ../../pkgs/slackmd.nix { src = slackmdSrc; };
  mojime = pkgs.callPackage ../../pkgs/mojime.nix { src = mojimeSrc; };
  # Named for its pname, not `near-cli`: nixpkgs still carries a `near-cli`
  # attribute that throws on eval, and a let binding that shadows it would make
  # any typo here fail in a confusing place.
  near-cli-rs = pkgs.callPackage ../../pkgs/near-cli-rs.nix { src = nearCliSrc; };
in
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

  # Secret Service provider (org.freedesktop.secrets). near-cli-rs stores access
  # keys through this D-Bus API and has no file-based fallback for it — its only
  # other mode is the "legacy keychain", which is plaintext JSON under
  # ~/.near-credentials. Nothing here supplied a provider before: on TuxedoOS
  # gnome-keyring came along with GNOME, and Hyprland has no equivalent, so the
  # keychain option failed with an error pointing at a Python library's README.
  #
  # The module registers the D-Bus service and sets
  # security.pam.services.login.enableGnomeKeyring. That is the right hook here
  # because logins happen on tty1 through agetty, i.e. the `login` PAM service;
  # the keyring is then unlocked with the login password as a side effect of
  # signing in, with no separate prompt.
  services.gnome.gnome-keyring.enable = true;

  # The module only wires the `login` service, and /etc/pam.d/passwd ships with
  # pam_unix alone. Without this, `passwd` would change the Unix password while
  # login.keyring stayed encrypted with the old one — auto-unlock then breaks,
  # and it surfaces much later as an unexplained password prompt rather than as
  # an error at the point of the change. pam_gnome_keyring's password phase
  # re-encrypts the keyring in step.
  security.pam.services.passwd.enableGnomeKeyring = true;

  environment.systemPackages = with pkgs; [
    alacritty
    git
    vim
    firefox
    libreoffice-qt6
    ripgrep
    fd
    jq
    curl
    htop
    tree
    fastfetch
    tokei
    claude-code
    codex
    near-cli-rs # provides `near`; see ../../pkgs/near-cli-rs.nix

    # Keychain tooling, both talking to the gnome-keyring service above.
    libsecret # secret-tool: inspect/store entries from the shell
    seahorse # GUI; the only convenient way to re-password a keyring file
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

    google-chrome # unfree — required for Google Workspace Endpoint Verification

    libnotify # notify-send, for testing that mako is alive

    # Own tools, see ../../pkgs and the keybindings in hyprland.lua.
    slackmd # Super+M / Super+S
    mojime # Super+Shift+M

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
  #
  # Noto Sans Symbols 2 is the only font here carrying the non-emoji Dingbats
  # and Symbols blocks — e.g. U+1F5F8 LIGHT CHECK MARK, which some web UIs use
  # as a status tick and which Noto Color Emoji does not cover. Trimmed to the
  # one variant so this stays 400K rather than all 50M of Noto.
  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
    (pkgs.noto-fonts.override { variants = [ "Noto Sans Symbols 2" ]; })
  ];

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

  # Hyprland runs no XSETTINGS daemon, and GTK3 only asks the portal above for
  # desktop settings when this is set — reading the schemas off XDG_DATA_DIRS
  # is not enough, its Wayland backend ignores them. Without it gtk-xft-dpi
  # stays at its "unset" sentinel of -1, and WebKitGTK feeds that straight into
  # its DPI scaling: devicePixelRatio comes out NEGATIVE (scale 2 * -1/96), so
  # every rem-based layout collapses — tiny text, wrong proportions, images
  # sized to nothing. Hits any webkit2gtk app, e.g. Tauri dev builds.
  environment.sessionVariables.GTK_USE_PORTAL = "1";

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
  home-manager.users = lib.genAttrs [ "marten" "dev" ] (name: { config, ... }: {
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
          #
          # The argument MUST be a table. hlDpms() calls tableToggleAction(),
          # which returns TOGGLE_ACTION_TOGGLE unless lua_istable() — so the
          # obvious-looking `hl.dsp.dpms("on")` discards the string and
          # *toggles*, while still printing `ok`. Two dispatches then cancel
          # out, which is exactly what happens on a suspend resume: this
          # after_sleep_cmd and the 660s listener's on-resume both fire, the
          # displays toggle off→on→off, and the machine comes back with live
          # input but dark panels. Cost two blind reboots on 2026-08-24.
          after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'";

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
          # 11 min: display off. Table args, not bare strings — see above.
          {
            timeout = 660;
            on-timeout = "${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'";
            on-resume = "${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'";
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

    # PDF viewer. The nixpkgs `zathura` attr is the wrapper and already bundles
    # the mupdf PDF plugin (plus djvu/ps/cb), so nothing else is needed to open
    # a document. Keys are vim's: j/k scroll, gg/G jump, / searches, Tab opens
    # the thumbnail index, `:` takes any of the options below at runtime.
    programs.zathura = lib.mkIf (name == "marten") {
      enable = true;
      options = {
        # zathura draws its own chrome with girara instead of following the GTK
        # theme, so the dark setup above doesn't reach it. These are mako's
        # colours, so notifications and the viewer match.
        default-bg = "#1a1a1a";
        default-fg = "#e6e6e6";
        statusbar-bg = "#1a1a1a";
        statusbar-fg = "#e6e6e6";
        inputbar-bg = "#1a1a1a";
        inputbar-fg = "#e6e6e6";
        # Search hits, and the one currently jumped to. These two have to carry
        # their own alpha — the old highlight-transparency option is gone, and
        # an opaque colour here paints over the very text it is marking.
        highlight-color = "rgba(51,204,255,0.5)";
        highlight-active-color = "rgba(0,255,153,0.5)";
        font = "JetBrainsMono Nerd Font 11";

        # Page contents stay as authored — Ctrl+R toggles inversion for the
        # white-page-at-night case, and these are the two ends it maps to.
        # keephue keeps figures and syntax highlighting recognisable inverted.
        recolor = false;
        recolor-lightcolor = "#1a1a1a";
        recolor-darkcolor = "#e6e6e6";
        recolor-keephue = true;

        # The default plain-text database only carries bookmarks; sqlite is what
        # makes a document reopen on the page it was left at.
        database = "sqlite";

        # Without this, yanked text goes to the primary selection only, so
        # Ctrl+V in another app comes up empty.
        selection-clipboard = "clipboard";
      };
    };

    # Nothing claimed PDFs before, so Firefox downloads and Dolphin double-clicks
    # had no handler to hand them to. This is the whole reason the viewer is
    # reachable outside of typing `zathura` in a terminal.
    #
    # force is needed because ~/.config/mimeapps.list already existed: Telegram
    # and Slack register their scheme handlers by writing it at runtime, and
    # `claude` installs its own URL handler the same way. Home-manager refuses to
    # clobber a file it didn't create, so activation fails until we say so
    # explicitly. The catch is that force makes it a read-only store symlink —
    # those apps can no longer add themselves back, so anything they used to
    # write has to be declared here or it is simply gone. Hence the second group
    # below: it is not new configuration, it is what that file already held.
    xdg.mimeApps = lib.mkIf (name == "marten") {
      enable = true;
      defaultApplications = {
        "text/html" = "firefox.desktop";
        "application/xhtml+xml" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";

        "application/pdf" = "org.pwmt.zathura.desktop";
        "image/vnd.djvu" = "org.pwmt.zathura.desktop";
        "application/postscript" = "org.pwmt.zathura.desktop";

        # Pre-existing, preserved verbatim — these are what make slack:// links
        # from the browser, tg:// links, and `claude --resume` deep links open
        # the installed app instead of nothing at all.
        "x-scheme-handler/slack" = "slack.desktop";
        "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
        "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
        "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      };

      # Telegram had these in [Added Associations] as well as as defaults.
      associations.added = {
        "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
        "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
      };
    };

    # See the force note on xdg.mimeApps above. Applies to the file HM would
    # otherwise refuse to overwrite; kept narrow rather than set globally via
    # home-manager.backupFileExtension so a future collision still stops and
    # asks instead of silently taking over a file someone edited by hand.
    # mkIf, not a bare `.force` — home-manager.users covers dev too, and an entry
    # with force but no source would fail to evaluate for a user that has no
    # mimeapps.list to begin with.
    xdg.configFile."mimeapps.list" = lib.mkIf (name == "marten") { force = true; };

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

        # Git injects LESS=FRX when LESS is otherwise unset. Explicitly cancel X
        # so less uses the alternate screen, letting the terminal translate
        # mouse-wheel events into pager navigation.
        core.pager = "less -RF -+X";

        init.defaultBranch = "main";
        push.autoSetupRemote = true;
      };

      # SSH signatures rather than GPG: no gpg-agent, keyring or smartcard
      # daemon, and a hardware key needs nothing extra later — a YubiKey FIDO2
      # credential is also just a `user.signingkey` path, so switching to one
      # means changing this line (see README for the non-rebuild routes).
      #
      # Reuses the authentication key; GitHub takes the same key registered
      # twice, once as an auth key and once as a signing key. That key has a
      # passphrase, so every commit prompts for it.
      signing = lib.mkIf (name == "marten") {
        format = "ssh";
        key = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
        signByDefault = true;
      };
    };

    programs.tmux = {
      enable = true;
      mouse = true;
    };

    # Claude Code's own preferences, which it otherwise writes to
    # ~/.claude/settings.json itself when they're changed through /config.
    # package = null because claude-code is in environment.systemPackages
    # above — the same split used for hyprland and hyprlock.
    #
    # Note the tradeoff: home-manager writes settings.json as a store symlink,
    # so /config can no longer save these keys and reports a write error. That's
    # the intended direction (change them here, rebuild), but it does mean the
    # in-app settings UI is now read-only for anything listed below.
    programs.claude-code = {
      enable = true;
      package = null;
      settings = {
        theme = "dark";
        tui = "fullscreen";

        # Attention notifications. Claude's default is "auto", which only
        # resolves for Apple Terminal, iTerm2, kitty and ghostty and silently
        # does nothing anywhere else; "terminal_bell" is a bare \a, which is
        # what Alacritty understands. From there: Alacritty turns a bell in an
        # unfocused window into an xdg-activation request, Hyprland flags the
        # window urgent, and waybar paints the workspace button with the
        # .urgent rule in waybar-style.css. Same chain codex rides by default.
        preferredNotifChannel = "terminal_bell";
      };
    };

    # See the force note on xdg.mimeApps above — the same reasoning, opposite
    # conclusion. claude-code has already written this file on every machine
    # where it has run, so without force the first rebuild stops for each user;
    # and unlike mimeapps.list there's nothing to preserve, because every key
    # it holds is declared above.
    home.file."${config.home.homeDirectory}/.claude/settings.json".force = true;
  });

  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (lib.getName pkg) [ "claude-code" "google-chrome" "slack" ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
