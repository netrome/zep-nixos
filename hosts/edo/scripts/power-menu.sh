# Power menu, bound to both Super+Shift+E and the physical power key.
#
# logind's default HandlePowerKey=poweroff kills the machine on a single
# unconfirmed press, which cost a session on 2026-08-23. Instead logind ignores
# the short press and Hyprland routes it here; a *long* press still powers off
# directly via HandlePowerKeyLongPress, so the muscle memory survives.
#
# "Cancel" is first because fuzzel preselects the first entry, making Enter a
# no-op rather than something destructive.

choice=$(printf 'Cancel\nLock\nSuspend\nLog out\nReboot\nPower off\n' \
  | fuzzel --dmenu --prompt 'Power: ') || exit 0

case "$choice" in
  Lock) exec loginctl lock-session ;;
  Suspend) exec systemctl suspend ;;
  # Lua call, not the legacy `hyprctl dispatch exit`, which silently no-ops.
  "Log out") exec hyprctl dispatch 'hl.dsp.exit()' ;;
  Reboot) exec systemctl reboot ;;
  "Power off") exec systemctl poweroff ;;
  *) exit 0 ;;
esac
