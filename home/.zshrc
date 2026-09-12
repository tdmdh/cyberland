# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME=""

plugins=(
    git
    archlinux
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# ---- desktop palette ----------------------------------------------------
# The same colours quickshell reads, written by hypr/bin/tokyo-palette after
# every wallpaper change. Sourced once per shell: shells started after a
# wallpaper change get the new palette, running ones keep the old one, and
# nothing pays a stat per prompt to track a file that moves twice a day.
# The fallbacks are Theme.qml's, so a missing file degrades to the same look.
source ~/.config/hypr/wallust/tokyo.sh 2>/dev/null

# The autosuggestion is this shell's ghost value: a stale reading rests at
# Theme.ghost on the HUD and cannot be dimmed in a terminal, so it takes the
# hairline colour instead -- present, structural, not competing with input.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=${TOKYO_BORDER_PRIMARY:-#4B4F58}"

# Colour only ever means "wrong". Out of the box this plugin paints eight
# hues at once, which is the one thing the design does not do: a command that
# will not run is red, a mismatched bracket is red, and everything else is
# text or held back to secondary. Set after oh-my-zsh has sourced the plugin,
# which is what declares the array and defaults it with `:=`.
ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=${TOKYO_ALERT:-#FF4D5A}"
ZSH_HIGHLIGHT_STYLES[bracket-error]="fg=${TOKYO_ALERT:-#FF4D5A}"
ZSH_HIGHLIGHT_STYLES[command]="fg=${TOKYO_PRIMARY_TEXT:-#F3F4F7}"
ZSH_HIGHLIGHT_STYLES[builtin]="fg=${TOKYO_PRIMARY_TEXT:-#F3F4F7}"
ZSH_HIGHLIGHT_STYLES[function]="fg=${TOKYO_PRIMARY_TEXT:-#F3F4F7}"
ZSH_HIGHLIGHT_STYLES[alias]="fg=${TOKYO_PRIMARY_TEXT:-#F3F4F7}"
ZSH_HIGHLIGHT_STYLES[precommand]="fg=${TOKYO_ACCENT_PRIMARY:-#B7BBC5}"
ZSH_HIGHLIGHT_STYLES[reserved-word]="fg=${TOKYO_ACCENT_PRIMARY:-#B7BBC5}"
ZSH_HIGHLIGHT_STYLES[path]="fg=${TOKYO_PRIMARY_TEXT:-#F3F4F7}"
ZSH_HIGHLIGHT_STYLES[globbing]="fg=${TOKYO_ACCENT_SECONDARY:-#7B8191}"
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]="fg=${TOKYO_SECONDARY_TEXT:-#606B8A}"
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=${TOKYO_SECONDARY_TEXT:-#606B8A}"
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]="fg=${TOKYO_SECONDARY_TEXT:-#606B8A}"
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]="fg=${TOKYO_SECONDARY_TEXT:-#606B8A}"
ZSH_HIGHLIGHT_STYLES[redirection]="fg=${TOKYO_BORDER_PRIMARY:-#4B4F58}"
ZSH_HIGHLIGHT_STYLES[commandseparator]="fg=${TOKYO_BORDER_PRIMARY:-#4B4F58}"
ZSH_HIGHLIGHT_STYLES[comment]="fg=${TOKYO_BORDER_PRIMARY:-#4B4F58}"

# Check archlinux plugin commands here
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/archlinux

# Display Pokemon-colorscripts
# Project page: https://gitlab.com/phoneybadger/pokemon-colorscripts#on-other-distros-and-macos
#pokemon-colorscripts --no-title -s -r #without fastfetch
# fastfetch --logo ~/Pictures/wallpapers/daisy.png --logo-type kitty --logo-width 38
# fastfetch. Will be disabled if above colorscript was chosen to install
#fastfetch -c $HOME/.config/fastfetch/config-compact.jsonc

# Set-up icons for files/directories in terminal using lsd
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'
alias lg='lazygit'
alias ld='lazydocker'
alias nv='nvim'
alias phoneinfoga='docker run --rm -it sundowndev/phoneinfoga'

# Set-up FZF key bindings (CTRL R for fuzzy history finder)
# Same instrument: unselected rows recede to secondary, the selected one sits
# on layer2 like a raised panel, and ▸ is the prompt's own cursor mark.
# bg is left at -1 so the terminal's ground (and its blur) shows through.
export FZF_DEFAULT_OPTS="--prompt='▸ ' --pointer='▸' --marker='+' --info=inline
  --color=bg:-1,gutter:-1,fg:${TOKYO_SECONDARY_TEXT:-#606B8A},fg+:${TOKYO_PRIMARY_TEXT:-#F3F4F7}
  --color=bg+:${TOKYO_LAYER_BACKGROUND2:-#0F0F0F},hl:${TOKYO_ACCENT_PRIMARY:-#B7BBC5},hl+:${TOKYO_ACCENT_PRIMARY:-#B7BBC5}
  --color=prompt:${TOKYO_ACCENT_PRIMARY:-#B7BBC5},pointer:${TOKYO_ACCENT_PRIMARY:-#B7BBC5},marker:${TOKYO_WARN:-#FFB020}
  --color=info:${TOKYO_BORDER_PRIMARY:-#4B4F58},header:${TOKYO_BORDER_PRIMARY:-#4B4F58},border:${TOKYO_BORDER_PRIMARY:-#4B4F58},spinner:${TOKYO_BORDER_PRIMARY:-#4B4F58}"
source <(fzf --zsh)

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
alias cd='z'

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export PATH="$HOME/.local/bin:$PATH"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
