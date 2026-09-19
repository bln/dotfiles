# mise: activate tools + shims for interactive shells (PATH is set in .zshenv)
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi



# ── history ───────────────────────────────────────────────────────────────────
mkdir -p "$XDG_CACHE_HOME/zsh"
HISTFILE="$XDG_CACHE_HOME/zsh/history"
HISTSIZE=50000
SAVEHIST=50000

setopt HIST_IGNORE_ALL_DUPS   # remove older duplicate entries from history
setopt HIST_IGNORE_SPACE      # lines starting with space are not recorded
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
  # Regenerate when: output missing OR version string has changed since last run.
  # Version files live alongside the completion file (e.g. _bat.version).
  local ver_file="${out}.version"
  local cur_ver
  cur_ver="$("$bin" --version 2>/dev/null | head -1)" || return
  if [[ ! -s $out || ! -f $ver_file || "$(<"$ver_file")" != "$cur_ver" ]]; then
    local tmp="${out}.tmp.$$"
    if "$bin" "$@" >"$tmp" 2>/dev/null; then
      mv -f "$tmp" "$out"
      printf '%s\n' "$cur_ver" >"$ver_file"
    fi
    rm -f "$tmp"
  fi
}
_gen_completion bat      "$_zcompdir/_bat"      --completion zsh
_gen_completion gh       "$_zcompdir/_gh"       completion -s zsh
_gen_completion mise     "$_zcompdir/_mise"     completion zsh
_gen_completion starship "$_zcompdir/_starship" completions zsh
_gen_completion uv       "$_zcompdir/_uv"       generate-shell-completion zsh
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

# ── zoxide (smart cd replacement) ─────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
  alias cd='z'
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

# ── functions ─────────────────────────────────────────────────────────────────
mkcd() { mkdir -p "$1" && cd "$1"; }
serve() { python3 -m http.server "${1:-8000}"; }

# ── zsh plugins (loaded last for proper terminal rendering) ───────────────────
# Plugins are installed via mise bootstrap packages (brew:zsh-autosuggestions,
# brew:zsh-syntax-highlighting). Detect the native package share prefix once
# rather than hard-coding /opt/homebrew (which is Apple Silicon only).
_plugin_prefix=""
if command -v brew &>/dev/null; then
  _plugin_prefix="$(brew --prefix)/share"
elif [[ -d /opt/homebrew/share ]]; then
  _plugin_prefix="/opt/homebrew/share"
elif [[ -d /usr/local/share ]]; then
  _plugin_prefix="/usr/local/share"
fi

if [[ -n "$_plugin_prefix" && -f "$_plugin_prefix/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$_plugin_prefix/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
fi

if [[ -n "$_plugin_prefix" && -f "$_plugin_prefix/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$_plugin_prefix/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
unset _plugin_prefix

# ── machine-local overrides (never committed) ─────────────────────────────────
# Per-machine tweaks live in $ZDOTDIR/.zshrc.local (gitignored). Sourced last so
# it can override anything above. Absent on a fresh machine - that is fine.
# Use a full `if` (not `&& source`) so an absent file does not leave the shell
# with a nonzero $? at the first prompt.
if [[ -r "${ZDOTDIR:-$HOME}/.zshrc.local" ]]; then
  source "${ZDOTDIR:-$HOME}/.zshrc.local"
fi
