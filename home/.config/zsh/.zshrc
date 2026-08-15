# mise: activate tools + shims for interactive shells (PATH is set in .zshenv)
command -v mise &>/dev/null && eval "$(mise activate zsh)"

# Keep Homebrew available without letting it shadow mise-managed tools or shims.
path=(${path:#/opt/homebrew/bin})
path=(${path:#/opt/homebrew/sbin})
[[ -d /opt/homebrew/bin ]] && path+=(/opt/homebrew/bin)
[[ -d /opt/homebrew/sbin ]] && path+=(/opt/homebrew/sbin)
typeset -gU path PATH

# ── environment ───────────────────────────────────────────────────────────────
export EDITOR=nvim
export VISUAL=nvim
export PAGER="less -FRX"
export LANG=en_US.UTF-8
# (no LC_ALL: it overrides every locale category and would stomp a user's
#  regional prefs for dates/numbers/currency. LANG is the sane default.)

# ── history ───────────────────────────────────────────────────────────────────
mkdir -p "$XDG_CACHE_HOME/zsh"
HISTFILE="$XDG_CACHE_HOME/zsh/history"
HISTSIZE=50000
SAVEHIST=50000

setopt HIST_IGNORE_ALL_DUPS   # remove older duplicate entries from history
setopt HIST_FIND_NO_DUPS      # don't display duplicates when searching
setopt HIST_REDUCE_BLANKS     # remove superfluous blanks from history items
setopt HIST_VERIFY            # show command from history before executing
setopt SHARE_HISTORY          # share history across all sessions
setopt INC_APPEND_HISTORY     # write to history file immediately

# ── completion ────────────────────────────────────────────────────────────────
# Tools installed by mise ship their zsh completion via stdout (not a file on
# $fpath), so generate them into a cache dir and put that dir on $fpath BEFORE
# compinit. Without this, an alias like `cat=bat` triggers `_bat` autoload from
# a stale zcompdump and fails with "function definition file not found".
_zcompdir="$XDG_CACHE_HOME/zsh/completions"
mkdir -p "$_zcompdir"
# (tool, subcommand/flag) pairs - only tools present get regenerated. Cheap: a
# handful of `--completion` calls, cached to files that compinit then indexes.
_gen_completion() {  # $1=binary  $2=file  $3+=args to emit zsh completion
  local bin=$1 out=$2; shift 2
  command -v "$bin" &>/dev/null || return
  # regenerate only if missing or the binary is newer than the cached file
  if [[ ! -f $out || $(command -v "$bin") -nt $out ]]; then
    "$bin" "$@" >| "$out" 2>/dev/null || rm -f "$out"
  fi
}
_gen_completion bat      "$_zcompdir/_bat"      --completion zsh
_gen_completion starship "$_zcompdir/_starship" completions zsh
fpath=("$_zcompdir" $fpath)
unfunction _gen_completion; unset _zcompdir

autoload -Uz compinit
# Rebuild the dump (full compinit) when it is stale, else use the fast path.
_zdump="$XDG_CACHE_HOME/zsh/zcompdump-${ZSH_VERSION}"
_stale=( $_zdump(Nmh+168) )
if [[ ! -s $_zdump
   || $XDG_CACHE_HOME/zsh/completions -nt $_zdump
   || -n $_stale ]]; then
  compinit -i -d "$_zdump"       # full: audit + rebuild index
else
  compinit -C -d "$_zdump"       # fast: reuse existing dump
fi
unset _zdump _stale

setopt MENU_COMPLETE          # auto-select first completion match
setopt AUTO_LIST              # automatically list choices on ambiguous completion
setopt COMPLETE_IN_WORD       # complete from both ends of a word
setopt ALWAYS_TO_END          # move cursor to end of word after completion

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*:warnings' format 'No matches for: %d'

# ── options ───────────────────────────────────────────────────────────────────
setopt AUTO_CD                # type a directory name to cd into it
setopt AUTO_PUSHD             # cd pushes old directory to stack
setopt PUSHD_IGNORE_DUPS      # don't push duplicates onto the stack
setopt NO_BEEP                # silence

# ── prompt ────────────────────────────────────────────────────────────────────
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
else
  autoload -Uz vcs_info
  precmd() { vcs_info }
  zstyle ':vcs_info:git:*' formats ' (%b)'
  setopt PROMPT_SUBST
  PROMPT='%F{cyan}%~%f%F{yellow}${vcs_info_msg_0_}%f %# '
fi

# ── key bindings ──────────────────────────────────────────────────────────────
bindkey -e                                # emacs key bindings (default macOS feel)
bindkey '^[[A' history-search-backward    # up arrow: search history by prefix
bindkey '^[[B' history-search-forward     # down arrow
bindkey '^[[H' beginning-of-line          # Home
bindkey '^[[F' end-of-line                # End
bindkey '^[[3~' delete-char               # Delete key

# ── navigation ────────────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# ── zoxide (smart cd replacement) ─────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
  alias cd='z'
fi

# ── listing (eza enhancement) ────────────────────────────────────────────────
if command -v eza &>/dev/null; then
  alias ls='eza --icons=auto'
  alias ll='eza -lh --icons=auto --git'
  alias la='eza -lah --icons=auto --git'
  alias tree='eza --tree --icons=auto'
else
  alias ls='ls -G'
  alias ll='ls -lhG'
  alias la='ls -lahG'
fi

# ── bat (colored cat & pager) ────────────────────────────────────────────────
if command -v bat &>/dev/null; then
  alias cat='bat --style=plain'
  export BAT_THEME="TwoDark"
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# ── fzf (fuzzy finder) ────────────────────────────────────────────────────────
if command -v fzf &>/dev/null; then
  source <(fzf --zsh)

  if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --strip-cwd-prefix --hidden --follow --exclude .git'
  fi

  if command -v bat &>/dev/null; then
    export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"
  fi
fi

# ── ripgrep ───────────────────────────────────────────────────────────────────
[[ -f "$HOME/.ripgreprc" ]] && export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"

# ── safer defaults ────────────────────────────────────────────────────────────
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias mkdir='mkdir -p'

# ── convenience ───────────────────────────────────────────────────────────────
alias c='clear'
alias q='exit'

# ── misc ──────────────────────────────────────────────────────────────────────
alias path='echo $PATH | tr ":" "\n"'
alias reload='exec zsh'
alias zshrc='nvim "$ZDOTDIR/.zshrc"'
alias vim='nvim'

# ── functions ─────────────────────────────────────────────────────────────────
mkcd() { mkdir -p "$1" && cd "$1"; }
serve() { python3 -m http.server "${1:-8000}"; }

# ── zsh plugins (loaded last for proper terminal rendering) ───────────────────
HB_PREFIX="/opt/homebrew/share"

if [[ -f "$HB_PREFIX/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$HB_PREFIX/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
fi

if [[ -f "$HB_PREFIX/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$HB_PREFIX/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
