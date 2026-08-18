{ pkgs, ... }:
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
  programs.zsh.enable = true;

  programs.hyprland.enable = true;

  environment.systemPackages = with pkgs; [
    alacritty
    git
    vim
    firefox
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
