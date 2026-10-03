# mise adds its managed Node and uv versions to the interactive shell.
if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
fi

export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less -FRX}"
export HOMEBREW_BUNDLE_FILE="${HOMEBREW_BUNDLE_FILE:-$HOME/Brewfile}"

# BSD ls (the macOS default) uses LSCOLORS for its color palette.
export CLICOLOR=1
export LSCOLORS='GxFxCxDxBxegedabagaced'
alias ls='command ls -G'
alias l='ls -lh'
alias ll='ls -lah'
alias la='ls -A'
alias lla='ls -lah'
alias c='clear'
alias q='exit'
alias vim='nvim'

# Keep a large, shared history while avoiding noisy duplicates.
HISTFILE="$HOME/.zsh_history"
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
_compdump="${ZDOTDIR:-$HOME}/.zcompdump-${ZSH_VERSION}"
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

# Built-in VCS information keeps the prompt useful without another dependency.
autoload -Uz add-zsh-hook vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr ' %F{green}+%f'
zstyle ':vcs_info:git:*' unstagedstr ' %F{red}!%f'
zstyle ':vcs_info:git:*' untrackedstr ' %F{red}?%f'
zstyle ':vcs_info:git:*' formats ' %F{yellow}[%b%f%c%u%F{yellow}]%f'
zstyle ':vcs_info:git:*' actionformats ' %F{yellow}[%b|%a%f%c%u%F{yellow}]%f'

setopt PROMPT_SUBST
typeset -g _prompt_status='%F{green}❯%f'

_update_prompt() {
  local exit_status=$?
  vcs_info
  if (( exit_status == 0 )); then
    typeset -g _prompt_status='%F{green}❯%f'
  else
    typeset -g _prompt_status="%F{red}✘ ${exit_status}%f"
  fi
}
add-zsh-hook precmd _update_prompt

PROMPT='%F{cyan}%~%f${vcs_info_msg_0_} ${_prompt_status} '

alias ..='cd ..'
alias ...='cd ../..'

if [[ -r "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
