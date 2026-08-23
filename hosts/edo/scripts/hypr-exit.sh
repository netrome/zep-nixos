# Confirmation wrapper for quitting the session, bound to Super+Shift+E.
#
# Exiting used to be a single unconfirmed keypress (Super+M in Hyprland's
# example config), which is an easy way to lose a session by accident.

# Escape in fuzzel exits non-zero: treat that as "cancel", not as an error.
choice=$(printf 'Cancel\nExit Hyprland\n' | fuzzel --dmenu --prompt 'Exit Hyprland? ') || exit 0

# NB: with a Lua config, `hyprctl dispatch` evaluates Lua — the legacy
# `hyprctl dispatch exit` parses as hl.dispatch(exit), an undefined global, and
# fails silently. Dispatchers must be written as Lua calls.
if [ "$choice" = "Exit Hyprland" ]; then
  exec hyprctl dispatch 'hl.dsp.exit()'
fi
