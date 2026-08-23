# Screenshot helper, bound to Print and friends in hyprland.lua and also useful
# to call from a terminal.
#
# Always copies to the clipboard — pasting is the common case — and additionally
# writes a file when passed "save".
#
# Feedback goes through `hyprctl notify`, which is built into the compositor, so
# this works before a notification daemon exists. Revisit once mako is in.
#
# usage: screenshot [region|window|output] [save]

mode=${1:-region}
save=${2:-}

case "$mode" in
  region)
    # slurp exits non-zero when cancelled with Escape; that is not an error.
    geom=$(slurp) || exit 0
    [ -n "$geom" ] || exit 0
    set -- -g "$geom"
    ;;
  window)
    geom=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
    set -- -g "$geom"
    ;;
  output)
    set -- -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')"
    ;;
  *)
    echo "usage: screenshot [region|window|output] [save]" >&2
    exit 2
    ;;
esac

if [ -n "$save" ]; then
  dir=${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots
  mkdir -p "$dir"
  file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
  grim "$@" "$file"
  wl-copy <"$file"
  hyprctl notify -1 2500 "rgb(00ff99)" "Screenshot saved: $file"
else
  grim "$@" - | wl-copy
  hyprctl notify -1 1500 "rgb(00ff99)" "Screenshot copied to clipboard"
fi
