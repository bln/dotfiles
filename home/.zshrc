export LANG=en_US.UTF-8
export EDITOR=vim
export VISUAL=vim

command -v mise &>/dev/null && eval "$(mise activate zsh)"
command -v starship &>/dev/null && eval "$(starship init zsh)"
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"
command -v fzf &>/dev/null && source <(fzf --zsh)

_fzf_compgen_path() {
  command fd --hidden --follow --exclude .git --color=never . "$1"
}
_fzf_compgen_dir() {
  command fd --type d --hidden --follow --exclude .git --color=never . "$1"
}

export PAGER="${PAGER:-less -FRX}"
export CLICOLOR=1
export LSCOLORS='ExGxFxDxCxBxBxCxCxExDx'

export FZF_DEFAULT_OPTS='
  --height=40%
  --layout=reverse
  --border
  --info=inline
  --color=bg:#303446,bg+:#414559,fg:#c6d0f5,fg+:#c6d0f5,hl:#e78284,hl+:#e78284,info:#ca9ee6,prompt:#ca9ee6,pointer:#f2d5cf,marker:#a6d189,spinner:#f2d5cf,header:#a6d189,border:#626880'

export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --strip-cwd-prefix --hidden --follow --exclude .git'

export FZF_CTRL_T_OPTS="
  --bind=ctrl-/:toggle-preview
  --preview 'bat --color=always --style=numbers --line-range=:300 -- {}'"

export FZF_ALT_C_OPTS="
  --bind=ctrl-/:toggle-preview
  --preview 'eza --color=always --icons=always --long --all --header --group-directories-first -- {}'"

export FZF_CTRL_R_OPTS="
  --bind 'ctrl-y:execute-silent(printf %s {2..} | pbcopy)+abort'
  --header 'Ctrl-Y: copy command to clipboard'"


setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS NO_BEEP

alias l='eza --color=auto --icons=auto --group-directories-first --long --all --header --git'
alias ll='eza --color=auto --icons=auto --group-directories-first --long --header --git'
alias la='eza --color=auto --icons=auto --group-directories-first --long --all --header --git'
alias tree='eza --color=auto --icons=auto --group-directories-first --tree --level=2'
alias q='exit'
alias c='clear'
alias cc='z'
alias ec="$EDITOR $HOME/.zshrc"
alias sc="source $HOME/.zshrc"
alias cxyolo='codex --dangerously-bypass-approvals-and-sandbox'
alias ..='cd ..'
alias ...='cd ../..'

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_VERIFY

setopt AUTO_MENU MENU_COMPLETE COMPLETE_IN_WORD ALWAYS_TO_END

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}No matches for: %d%f'

autoload -Uz compinit
compinit

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

[[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
