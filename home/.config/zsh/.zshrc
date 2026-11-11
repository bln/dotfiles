#mise: activate tools + shims for interactive shells (PATH starts in .zshenv)
command -v mise &>/dev/null && eval "$(mise activate zsh)"

# Mise config manages Homebrew PATH ordering.
# Keep the tied Zsh path array unique after activation.
typeset -gU path PATH

# Interactive command-line defaults.
export PAGER="${PAGER:-less -FRX}"
export CLICOLOR=1
export LSCOLORS='ExGxFxDxCxBxBxCxCxExDx'

alias l='command ls -laG'

alias bat='command bat --theme=OneHalfDark --style=numbers,changes,header --paging=auto'

alias q='exit'
alias c='clear'
alias ec="$EDITOR $ZDOTDIR/.zshrc"
alias sc="source $ZDOTDIR/.zshrc"

alias cxyolo='codex --dangerously-bypass-approvals-and-sandbox'

alias ..='cd ..'
alias ...='cd ../..'

# Keep a large, shared history while avoiding noisy duplicates.
mkdir -p "$XDG_CACHE_HOME/zsh"
HISTFILE="$XDG_CACHE_HOME/zsh/history"
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY       # save timestamps and command durations
setopt SHARE_HISTORY          # share commands between open shells
setopt HIST_EXPIRE_DUPS_FIRST # expire duplicates before unique entries
setopt HIST_IGNORE_ALL_DUPS   # remove older copies of a repeated command
setopt HIST_IGNORE_SPACE      # do not save commands beginning with a space
setopt HIST_FIND_NO_DUPS      # skip duplicates while searching
setopt HIST_SAVE_NO_DUPS      # do not save duplicates when the file is written
setopt HIST_REDUCE_BLANKS     # normalize unnecessary whitespace
setopt HIST_VERIFY             # show history expansion before executing it

setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt NO_BEEP

# Completion menu, matching, and navigation.
setopt AUTO_MENU
setopt MENU_COMPLETE
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}No matches for: %d%f'

autoload -Uz compinit
_compdump="$XDG_CACHE_HOME/zsh/zcompdump-${ZSH_VERSION}"
if [[ -r "$_compdump" ]]; then
  compinit -C -d "$_compdump"
else
  compinit -d "$_compdump"
fi
unset _compdump

# Use prefix-aware history search for the arrow keys.
bindkey -e
bindkey '^[[A' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward
bindkey '^[OA' history-beginning-search-backward
bindkey '^[OB' history-beginning-search-forward
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[OH' beginning-of-line
bindkey '^[OF' end-of-line
bindkey '^[[3~' delete-char

eval "$(starship init zsh)"

eval "$(zoxide init zsh)"
alias cc='z'

if [[ -r "$ZDOTDIR/.zshrc.local" ]]; then
  source "$ZDOTDIR/.zshrc.local"
fi

if [[ -f "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
fi

if [[ -f "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
