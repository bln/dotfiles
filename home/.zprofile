# Provide mise shims to login shells, including noninteractive login shells.
# Interactive shells run full mise activation in .zshrc.
command -v mise &>/dev/null && eval "$(mise activate zsh --shims)"
