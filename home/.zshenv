# Establish the XDG roots and move all later Zsh startup files under ZDOTDIR.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

# Use Neovim consistently for shell, Git, mise, and interactive tools.
export EDITOR=nvim
export VISUAL=nvim
export GIT_EDITOR=nvim

# Keep npm's user configuration in the XDG configuration tree.
export NPM_CONFIG_USERCONFIG="${NPM_CONFIG_USERCONFIG:-$XDG_CONFIG_HOME/npm/npmrc}"

# Keep zoxide's macOS database in the XDG data tree.
export _ZO_DATA_DIR="${_ZO_DATA_DIR:-$XDG_DATA_HOME/zoxide}"
