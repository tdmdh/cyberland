# Sourced by the dev-session terminals (term() in each project's dev.sh),
# after .zshrc, so nothing there can put /usr/bin/sudo back in front.
# See sudo-shim/sudo for why only these terminals.
path=("$HOME/.config/hypr/bin/sudo-shim" $path)
