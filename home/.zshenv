# ~/.zshenv — the one shell file that must live in $HOME. zsh reads it before
# any other rc file, so it is where we bootstrap XDG paths and ZDOTDIR. Every
# other shell file (.zprofile, .zshrc) lives under $ZDOTDIR (~/.config/zsh).

export SHELL_SESSIONS_DISABLE="${SHELL_SESSIONS_DISABLE:-1}"   # disable macOS Terminal session save/restore

# XDG base dirs (define defaults so downstream tools + $ZDOTDIR resolve cleanly)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Relocate npm's user config out of $HOME into XDG (keeps $HOME to one dotfile).
# The file itself is tracked in the dotfiles repo and symlinked here by mise.
export NPM_CONFIG_USERCONFIG="${NPM_CONFIG_USERCONFIG:-$XDG_CONFIG_HOME/npm/npmrc}"

# Relocate the rest of zsh's rc files out of $HOME into ~/.config/zsh.
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# Keep agent-owned state out of the repository. Native mise copy mappings seed
# only AGENTS/CLAUDE instructions and skills; credentials, sessions, databases,
# and other runtime files remain under these machine-local roots.
export PI_CODING_AGENT_DIR="${PI_CODING_AGENT_DIR:-$XDG_CONFIG_HOME/pi/agent}"
export CODEX_HOME="${CODEX_HOME:-$XDG_CONFIG_HOME/codex}"
export CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$XDG_CONFIG_HOME/claude}"
export ENABLE_PROMPT_CACHING_1H="${ENABLE_PROMPT_CACHING_1H:-1}"
export PI_CACHE_RETENTION="${PI_CACHE_RETENTION:-long}"

# ~/.local/bin holds script-installed mise and uv-managed python/python3. It must
# be on PATH before .zprofile (mise shims) and .zshrc (mise activate) run, so it
# lives here in .zshenv, which is sourced for every shell invocation.
case ":$PATH:" in
  *:"$HOME/.local/bin":*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

export RTK_TELEMETRY_DISABLED=1
