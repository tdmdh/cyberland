#!/usr/bin/env bash
#
# Runs install.sh against a throwaway HOME and checks the links landed.
# Packages are skipped, so this is safe and offline.
#
#   ./test.sh
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# XDG_CONFIG_HOME must be overridden too. install.sh honours it, so setting
# only HOME would point the sandbox at the real ~/.config and move it aside.
run() { env HOME="$SANDBOX" XDG_CONFIG_HOME="$SANDBOX/.config" bash "$REPO/install.sh" "$@"; }

mkdir -p "$SANDBOX/.config/hypr"
echo "in the way" > "$SANDBOX/.config/hypr/hyprland.conf"

run full --no-packages >/dev/null

fail=0
for p in .config/hypr/hyprland.lua \
         .config/hypr/conf/binds.lua \
         .config/hypr/conf/monitors_local.lua \
         .config/hypr/bin/tokyo-palette \
         .config/quickshell/deck/shell.qml \
         .config/quickshell/deck/views/common/Theme.qml \
         .config/quickshell/deck/views/rank.js \
         .config/hypr/src/fileindex/main.go \
         .config/kitty/kitty-themes/01-Wallust.conf \
         .config/superfile/theme/wallust.toml \
         .config/starship.toml \
         .config/nvim/init.lua \
         .zshrc; do
    [ -r "$SANDBOX/$p" ] || { echo "unreadable after install: $p"; fail=1; }
done

# What was in the way must have been kept, not destroyed.
[ -n "$(find "$SANDBOX/.dotfiles-backup" -name hyprland.conf 2>/dev/null)" ] \
    || { echo "the pre-existing config was not backed up"; fail=1; }

# The palette regenerates from the committed defaults with no wallpaper set.
env HOME="$SANDBOX" python3 "$SANDBOX/.config/hypr/bin/tokyo-palette" >/dev/null 2>&1 \
    || { echo "tokyo-palette failed on a fresh install"; fail=1; }
[ -s "$SANDBOX/.config/quickshell/qml_color.json" ] \
    || { echo "no palette written for quickshell"; fail=1; }

# Re-running must change nothing.
[ -z "$(run full --no-packages | grep -i moved)" ] \
    || { echo "second run was not idempotent"; fail=1; }

# desktop profile must not link the dev configs.
rm -rf "$SANDBOX/.config" "$SANDBOX/.zshrc" "$SANDBOX/.dotfiles-backup"
run desktop --no-packages >/dev/null
[ -e "$SANDBOX/.config/nvim" ] && { echo "desktop profile linked nvim"; fail=1; }
[ -e "$SANDBOX/.config/hypr" ] || { echo "desktop profile skipped hypr"; fail=1; }

[ $fail -eq 0 ] && echo "ok" || exit 1
