# mise activates its managed runtimes and tools in the interactive shell.
if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
fi

export PAGER="${PAGER:-less -FRX}"

# BSD ls (the macOS default) uses LSCOLORS for its color palette. Use cool
# colors for directories and links, green for executables, and keep all
# backgrounds neutral so listings stay readable across terminal themes.
export CLICOLOR=1
export LSCOLORS='ExGxFxDxCxBxBxCxCxExDx'

# Keep native ls as the fallback; use eza for the convenience aliases.
alias ls='command ls -G'
alias l='eza --long --group-directories-first --icons=auto --color=auto'
alias ll='eza --long --all --group-directories-first --icons=auto --color=auto --git'
alias la='eza --all --group-directories-first --icons=auto --color=auto'
alias lla='eza --long --all --group-directories-first --icons=auto --color=auto --git'
alias tree='eza --tree --level=2 --group-directories-first --git-ignore --icons=auto --color=auto'
alias c='clear'
alias q='exit'
alias v='nvim'
alias cc='z'
alias dc='z'

# Git and workflow shortcuts.
alias gcm='git switch "$(git main-branch)" && git pull'
function grm() {
  local main_branch
  main_branch="$(git main-branch)" || return
  git fetch origin "$main_branch" && git rebase "origin/$main_branch"
}
alias gpf='git push --force-with-lease --force-if-includes'
alias prc='gh pr create --web'
alias prv='gh pr view --web'
alias kc='kubectl config use-context'
if (( $+commands[pbcopy] )); then
  alias cbc='pbcopy'
  alias cbp='pbpaste'
fi

# One Dark colors for eza metadata and file categories.
export EZA_COLORS='fi=38;2;171;178;191:di=38;2;97;175;239:ln=38;2;86;182;194:ex=38;2;152;195;121:da=38;2;229;192;123:sn=38;2;92;99;112'

# Keep a large, shared history while avoiding noisy duplicates.
HISTFILE="$XDG_STATE_HOME/zsh/history"
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
mkdir -p "$XDG_CACHE_HOME/zsh"
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

# fzf uses fd for file and directory candidates and bat for file previews.
export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border --info=inline --color=fg:#abb2bf,bg:#282c34,hl:#61afef,fg+:#abb2bf,bg+:#5c6370,hl+:#61afef,info:#56b6c2,prompt:#c678dd,pointer:#c678dd,marker:#98c379,spinner:#56b6c2,header:#5c6370,border:#5c6370'
export FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude .git --color=never'
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git --color=never'
export FZF_CTRL_T_OPTS="
  --preview 'bat --color=always --style=numbers --line-range=:500 {}'"
if (( $+commands[fzf] )); then
  FZF_CTRL_R_COMMAND= source <(fzf --zsh)
fi

# Atuin owns Ctrl-R; preserve the existing native Up-arrow history bindings.
if (( $+commands[atuin] )); then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# Return to the directory selected in Yazi after it exits.
if (( $+commands[yazi] )); then
  function y() {
    local tmp cwd
    tmp="$(mktemp -t yazi-cwd.XXXXXX)"
    yazi "$@" --cwd-file="$tmp"
    if [[ -s "$tmp" ]]; then
      IFS= read -r -d '' cwd < "$tmp"
      [[ -n "$cwd" && "$cwd" != "$PWD" ]] && builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
  }
fi

alias lg='lazygit'

# Starship renders the prompt and manages its Zsh hooks.
eval "$(starship init zsh)"
alias ..='cd ..'
alias ...='cd ../..'

if [[ -r "$ZDOTDIR/.zshrc.local" ]]; then
  source "$ZDOTDIR/.zshrc.local"
fi

# Load autosuggestions before syntax highlighting; syntax highlighting must be last.
if [[ -r /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
if [[ -r /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
