# ── mise ──────────────────────────────────────────────────────────────────────
# Activate tools and shims for interactive shells (PATH bootstrapped in .zshenv).
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi
# Deduplicate PATH after mise adds its entries (zsh tied-array feature).
typeset -gU path PATH

# ── environment ───────────────────────────────────────────────────────────────
# Interactive defaults; honour values already set by the parent process.
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less -FRX}"
export LANG="${LANG:-en_US.UTF-8}"

# ── history ───────────────────────────────────────────────────────────────────
mkdir -p "$XDG_CACHE_HOME/zsh"
HISTFILE="$XDG_CACHE_HOME/zsh/history"
HISTSIZE=50000
SAVEHIST=50000

setopt HIST_IGNORE_ALL_DUPS   # drop older duplicate entries
setopt HIST_IGNORE_SPACE      # exclude lines starting with a space
setopt HIST_FIND_NO_DUPS      # skip duplicates when searching
setopt HIST_REDUCE_BLANKS     # strip superfluous blanks
setopt HIST_VERIFY            # show expanded history line before executing

# atuin replaces zsh history sync when present; enabling both double-writes.
if command -v atuin &>/dev/null; then
  _use_atuin=1
  eval "$(atuin init zsh)"
else
  _use_atuin=0
  setopt SHARE_HISTORY        # share history across sessions
  setopt INC_APPEND_HISTORY   # write each command immediately
fi

# ── options ───────────────────────────────────────────────────────────────────
setopt AUTO_CD                # bare directory name cds into it
setopt AUTO_PUSHD             # cd pushes old dir onto the stack
setopt PUSHD_IGNORE_DUPS      # no duplicate dirs on the stack
setopt NO_BEEP                # silence

# ── completions ───────────────────────────────────────────────────────────────
# mise-managed tools emit their zsh completions to stdout rather than shipping
# a file on $fpath. Generate them into a cache dir and prepend it to $fpath
# before compinit so the dump includes them. Regenerate only when the tool's
# version changes (version stamp file sits alongside the completion file).
_compdir="$XDG_CACHE_HOME/zsh/completions"
mkdir -p "$_compdir"

_cache_completion() {  # usage: _cache_completion <bin> <outfile> <cmd…>
  local bin=$1 out=$2; shift 2
  command -v "$bin" &>/dev/null || return 0
  local stamp="${out}.version"
  local ver; ver="$("$bin" --version 2>/dev/null | head -1)" || return 0
  [[ -s $out && -f $stamp && "$(<$stamp)" == "$ver" ]] && return 0
  local tmp="${out}.tmp.$$"
  "$bin" "$@" >"$tmp" 2>/dev/null && mv -f "$tmp" "$out" && printf '%s\n' "$ver" >"$stamp"
  rm -f "$tmp"
}

_cache_completion atuin    "$_compdir/_atuin"    gen-completions --shell zsh
_cache_completion bat      "$_compdir/_bat"      --completion zsh
_cache_completion gh       "$_compdir/_gh"       completion -s zsh
_cache_completion mise     "$_compdir/_mise"     completion zsh
_cache_completion starship "$_compdir/_starship" completions zsh
_cache_completion uv       "$_compdir/_uv"       generate-shell-completion zsh

fpath=("$_compdir" "${fpath[@]}")
unset _compdir

autoload -Uz compinit
# Full rebuild when the dump is missing, the completions dir is newer, or the
# dump is older than 7 days. Otherwise use the fast cached path (-C skips audit).
_zdump="$XDG_CACHE_HOME/zsh/zcompdump-${ZSH_VERSION}"
_stale=( $_zdump(Nmh+168) )
if [[ ! -s $_zdump || $XDG_CACHE_HOME/zsh/completions -nt $_zdump || -n $_stale ]]; then
  compinit -i -d "$_zdump"
else
  compinit -C -d "$_zdump"
fi
unset _zdump _stale

setopt MENU_COMPLETE          # select first match immediately; Tab cycles
setopt COMPLETE_IN_WORD       # complete from either end of a word
setopt ALWAYS_TO_END          # move cursor to end after completion

# LS_COLORS is unset on stock macOS (only LSCOLORS exists for BSD ls).
# Provide a minimal ANSI default so completion list-colors work everywhere.
: "${LS_COLORS:=di=34:ln=36:ex=32:pi=33:so=35:bd=33;01:cd=33;01:su=31;01:sg=31;01:tw=34;01:ow=34;01}"

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'        # case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*:warnings'     format 'No matches for: %d'

# ── key bindings ──────────────────────────────────────────────────────────────
bindkey -e                             # emacs bindings (standard macOS feel)
bindkey '^[[A' history-search-backward # up arrow   — prefix search back
bindkey '^[[B' history-search-forward  # down arrow — prefix search forward
bindkey '^[[H' beginning-of-line       # Home
bindkey '^[[F' end-of-line             # End
bindkey '^[[3~' delete-char            # Delete

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

# ── tools ─────────────────────────────────────────────────────────────────────
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
  alias dc='z'
fi

if command -v fzf &>/dev/null; then
  source <(fzf --zsh)
  export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border --bind='ctrl-/:toggle-preview'"

  if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --strip-cwd-prefix --hidden --follow --exclude .git'
  fi

  if command -v bat &>/dev/null; then
    export FZF_CTRL_T_OPTS="--select-1 --exit-0 --preview 'bat --style=numbers --color=always --line-range :500 {}'"
  else
    export FZF_CTRL_T_OPTS="--select-1 --exit-0"
  fi

  if command -v eza &>/dev/null; then
    export FZF_ALT_C_OPTS="--select-1 --exit-0 --preview 'eza --tree --icons=auto --level=2 {} 2>/dev/null'"
  else
    export FZF_ALT_C_OPTS="--select-1 --exit-0 --preview 'ls {}'"
  fi
fi

[[ -f "$HOME/.ripgreprc" ]] && export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"

# ── aliases ───────────────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias c='clear'
alias q='exit'
alias reload='exec zsh'
alias path='print -rl -- ${(s.:.)PATH}'
alias mkdir='command mkdir -p'
alias zshrc='${EDITOR:-vi} "$ZDOTDIR/.zshrc"'

(( $+commands[eza]    )) && alias l='eza --icons=auto' ll='eza -lh --icons=auto --git' la='eza -lah --icons=auto --git' \
                         || alias l='command ls'       ll='command ls -lh'              la='command ls -lah'
(( $+commands[nvim]   )) && alias vim='nvim' v='nvim' vz='NVIM_APPNAME=nvim-lazyvim nvim' vk='NVIM_APPNAME=nvim-kickstart nvim' \
                         || alias vim='vi'   v='vi'
(( $+commands[gitui]  )) && alias gg='gitui'
(( $+commands[codex]  )) && alias cxyolo='codex --dangerously-bypass-approvals-and-sandbox' \
                                   cxfull='codex --sandbox danger-full-access' \
                                   cxauto='codex --ask-for-approval never'
(( $+commands[claude] )) && alias ccyolo='claude --permission-mode auto'
(( $+commands[mise]   )) && alias dot='mise -C "${DOTFILES_DIR:-$HOME/dotfiles}"'

# ── functions ─────────────────────────────────────────────────────────────────
mkcd()  { mkdir -p "$1" && cd "$1"; }
serve() { python3 -m http.server "${1:-8000}"; }

# ── plugins ───────────────────────────────────────────────────────────────────
# Both plugins are installed by brew (brew:zsh-autosuggestions,
# brew:zsh-syntax-highlighting). Must load after completions and aliases for
# correct highlighting. Syntax-highlighting must be last.
_brew_share=""
[[ -d /opt/homebrew/share ]] && _brew_share="/opt/homebrew/share"
[[ -z $_brew_share && -d /usr/local/share ]] && _brew_share="/usr/local/share"

if [[ -n $_brew_share ]]; then
  _p="$_brew_share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  if [[ -f $_p ]]; then
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
    source "$_p"
  fi
  _p="$_brew_share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  [[ -f $_p ]] && source "$_p"
  unset _p
fi
unset _brew_share

# ── local overrides ───────────────────────────────────────────────────────────
# ~/.config/zsh/.zshrc.local is machine-local and never committed.
if [[ -r "${ZDOTDIR:-$HOME}/.zshrc.local" ]]; then
  source "${ZDOTDIR:-$HOME}/.zshrc.local"
fi
