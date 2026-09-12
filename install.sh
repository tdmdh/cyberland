#!/usr/bin/env bash
#
# Installs this Hyprland desktop on Arch. Symlinks, so edits land back in the
# repo with no sync step. Anything already in the way is moved aside, never
# overwritten.
#
#   ./install.sh            pick a profile interactively
#   ./install.sh desktop    compositor, shell UI and theming only
#   ./install.sh full       the above plus zsh, nvim and the CLI tools
#   ./install.sh full --no-packages    link only, skip pacman and fonts
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

say()  { printf '\033[36m::\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31mxx\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- profile --

PROFILE=""
DO_PACKAGES=1
for arg in "$@"; do
    case "$arg" in
        desktop|full) PROFILE="$arg" ;;
        --no-packages) DO_PACKAGES=0 ;;
        *) die "unknown argument: $arg" ;;
    esac
done

if [ -z "$PROFILE" ]; then
    echo
    echo "  1) desktop   Hyprland, Quickshell, wallust theming, kitty, ghostty,"
    echo "               superfile, btop, cava, fastfetch."
    echo "  2) full      Everything above plus zsh (oh-my-zsh, starship, fzf,"
    echo "               zoxide, lsd) and the Neovim config."
    echo
    read -rp "  profile [1/2]: " choice
    case "$choice" in
        1) PROFILE=desktop ;;
        2) PROFILE=full ;;
        *) die "pick 1 or 2" ;;
    esac
fi
say "profile: $PROFILE"

# --------------------------------------------------------------- packages --

# Installed one at a time on purpose: a single renamed or dropped package
# should cost you that package, not the whole install.
PKGS_DESKTOP=(
    hyprland quickshell xdg-desktop-portal-hyprland polkit
    swww wallust kitty ghostty superfile
    qt6-declarative qt6-5compat qt6-svg qt6-multimedia
    cliphist wl-clipboard wl-clip-persist udiskie
    pipewire wireplumber networkmanager bluez bluez-utils
    brightnessctl playerctl power-profiles-daemon
    grim slurp swappy grimblast-git hyprpicker
    btop cava fastfetch jq python python-psutil libnotify
    ttf-cascadia-code-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk
)
PKGS_DEV=(zsh neovim starship fzf zoxide lsd lazygit git)

install_packages() {
    command -v pacman >/dev/null || die "this installer is Arch-only"
    local helper
    if   command -v yay  >/dev/null; then helper=yay
    elif command -v paru >/dev/null; then helper=paru
    else die "need an AUR helper: install yay or paru first"
    fi

    local pkgs=("${PKGS_DESKTOP[@]}")
    [ "$PROFILE" = full ] && pkgs+=("${PKGS_DEV[@]}")

    say "installing ${#pkgs[@]} packages with $helper"
    local failed=()
    for p in "${pkgs[@]}"; do
        pacman -Qq "$p" >/dev/null 2>&1 && continue
        "$helper" -S --needed --noconfirm "$p" >/dev/null 2>&1 || failed+=("$p")
    done
    if [ ${#failed[@]} -gt 0 ]; then warn "could not install: ${failed[*]}"; fi
}

# ------------------------------------------------------------------ fonts --

# Barlow Semi Condensed and Inter Display are not packaged on Arch, so they
# come straight from upstream into the user font directory.
install_fonts() {
    local dir="$HOME/.local/share/fonts"
    local tmp; tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    mkdir -p "$dir"

    if ! fc-list : family | grep -qi 'Barlow Semi Condensed'; then
        say "downloading Barlow Semi Condensed"
        if curl -fsSL 'https://fonts.google.com/download?family=Barlow%20Semi%20Condensed' \
             -o "$tmp/barlow.zip"; then
            unzip -qo "$tmp/barlow.zip" -d "$dir/barlow-semi-condensed"
        else
            warn "Barlow download failed, labels will fall back to a system sans"
        fi
    fi

    if ! fc-list : family | grep -qi 'Inter Display'; then
        say "downloading Inter"
        if curl -fsSL 'https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip' \
             -o "$tmp/inter.zip"; then
            unzip -qo "$tmp/inter.zip" -d "$dir/Inter"
        else
            warn "Inter download failed, UI text will fall back to a system sans"
        fi
    fi

    fc-cache -f >/dev/null 2>&1 || true
}

# ------------------------------------------------------------------- link --

# Moves whatever is already there into $BACKUP, then symlinks. Re-running is
# safe: a link already pointing at the repo is left alone.
link() {
    local src="$1" dest="$2"
    [ -e "$src" ] || { warn "missing in repo: $src"; return 0; }
    [ "$(readlink -f "$dest" 2>/dev/null)" = "$src" ] && return 0
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        mkdir -p "$BACKUP"
        mv "$dest" "$BACKUP/"
        warn "moved existing $(basename "$dest") to $BACKUP"
    fi
    mkdir -p "$(dirname "$dest")"
    ln -sfn "$src" "$dest"
    printf '   %s -> %s\n' "${dest/#$HOME/\~}" "${src/#$REPO/.}"
}

DESKTOP_LINKS=(hypr quickshell wallust kitty ghostty superfile btop cava fastfetch)
DEV_LINKS=(nvim starship.toml)

# ------------------------------------------------------------------- run ----

if [ "$DO_PACKAGES" -eq 1 ]; then
    install_packages
    install_fonts
else
    say "skipping packages and fonts"
fi

say "linking configs"
for name in "${DESKTOP_LINKS[@]}"; do link "$REPO/config/$name" "$CONFIG/$name"; done
if [ "$PROFILE" = full ]; then
    for name in "${DEV_LINKS[@]}"; do link "$REPO/config/$name" "$CONFIG/$name"; done
    link "$REPO/home/.zshrc" "$HOME/.zshrc"

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        say "installing oh-my-zsh"
        git clone -q --depth 1 https://github.com/ohmyzsh/ohmyzsh "$HOME/.oh-my-zsh"
    fi
    for plug in zsh-autosuggestions zsh-syntax-highlighting; do
        d="$HOME/.oh-my-zsh/custom/plugins/$plug"
        [ -d "$d" ] || git clone -q --depth 1 "https://github.com/zsh-users/$plug" "$d"
    done
fi

# Per-machine display layout. Git ignores it, so the repo never carries one
# person's monitor arrangement.
LOCAL_MON="$REPO/config/hypr/conf/monitors_local.lua"
[ -f "$LOCAL_MON" ] || cp "$LOCAL_MON.example" "$LOCAL_MON"

# The schematic workbench renders through bun. Optional: everything else in
# the desktop works without it.
if command -v bun >/dev/null; then
    say "building the schematic engine"
    dest="$HOME/.local/share/hypr/schematic-engine"
    mkdir -p "$dest"
    cp "$REPO"/share/schematic-engine/* "$dest/"
    (cd "$dest" && bun install --silent) || warn "bun install failed, the schematic studio will not render"
else
    warn "bun not found, skipping the schematic engine (Super+X)"
fi

mkdir -p "$HOME/Pictures/wallpapers"

echo
say "done. profile: $PROFILE"
if [ -d "$BACKUP" ]; then say "your previous configs: $BACKUP"; fi
cat <<'NEXT'

   Next:
     1. Put some images in ~/Pictures/wallpapers.
     2. Log out, pick Hyprland at your display manager, log back in.
     3. Super+W opens the wallpaper and theme studio. Picking a wallpaper
        regenerates the whole palette across every app.
     4. Super+/ lists every keybind.

   Multi-monitor: edit config/hypr/conf/monitors_local.lua, then run: hyprctl reload

NEXT
