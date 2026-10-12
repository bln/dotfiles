# ~/.zshenv — the one shell file that must live in $HOME. zsh reads it before
# any other rc file, so it is where we bootstrap XDG paths and ZDOTDIR. Every
# other shell file (.zprofile, .zshrc) lives under $ZDOTDIR (~/.config/zsh).

export SHELL_SESSIONS_DISABLE=1   # disable macOS Terminal session save/restore

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

# ~/.local/bin holds script-installed mise and uv-managed python/python3. It must
# be on PATH before .zprofile (Homebrew + mise shims) and .zshrc (mise activate)
# run, so it lives here in .zshenv, which is sourced for every shell invocation.
export PATH="$HOME/.local/bin:$PATH"
