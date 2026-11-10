#mise: activate tools + shims for interactive shells (PATH starts in .zshenv)
command -v mise &>/dev/null && eval "$(mise activate zsh)"

# Mise config manages Homebrew PATH ordering.
# Keep the tied Zsh path array unique after activation.
typeset -gU path PATH

# Interactive command-line defaults.
export PAGER="${PAGER:-less -FRX}"
export CLICOLOR=1
export LSCOLORS='ExGxFxDxCxBxBxCxCxExDx'
export EZA_COLORS='fi=38;2;171;178;191:di=38;2;97;175;239:ln=38;2;86;182;194:ex=38;2;152;195;121:da=38;2;229;192;123:sn=38;2;92;99;112'
export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border --info=inline --color=fg:#abb2bf,bg:#282c34,hl:#61afef,fg+:#abb2bf,bg+:#5c6370,hl+:#61afef,info:#56b6c2,prompt:#c678dd,pointer:#c678dd,marker:#98c379,spinner:#56b6c2,header:#5c6370,border:#5c6370'
if (( $+commands[fd] )); then
  export FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude .git --color=never'
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git --color=never'
else
  export FZF_CTRL_T_COMMAND="find . -path '*/.git' -prune -o -type f -print"
  export FZF_ALT_C_COMMAND="find . -path '*/.git' -prune -o -type d -print"
fi

# Listing aliases use eza when installed and native tools otherwise.
alias ls='command ls -G'
if (( $+commands[eza] )); then
  alias l='eza --long --group-directories-first --icons=auto --color=auto'
  alias ll='eza --long --all --group-directories-first --icons=auto --color=auto --git'
  alias la='eza --all --group-directories-first --icons=auto --color=auto'
  alias lla='eza --long --all --group-directories-first --icons=auto --color=auto --git'
  alias tree='eza --tree --level=2 --group-directories-first --git-ignore --icons=auto --color=auto'
else
  alias l='command ls -lG'
  alias ll='command ls -laG'
  alias la='command ls -AG'
  alias lla='command ls -laG'
  alias tree="command find . -path '*/.git' -prune -o -print"
fi

# Keep bat defaults in its interactive alias; cat is the fallback.
if (( $+commands[bat] )); then
  alias bat='command bat --theme=OneHalfDark --style=numbers,changes,header --paging=auto'
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --theme=OneHalfDark --style=numbers --line-range=:500 {}'"
else
  alias bat='command cat'
  export FZF_CTRL_T_OPTS="--preview 'cat {}'"
fi

# Select an available editor for the v shortcut.
if (( $+commands[vim] )); then
  alias v='vim'
else
  alias v='vi'
fi

alias q='exit'
alias c='clear'
alias ec="$EDITOR $ZDOTDIR/.zshrc"
alias sc="source $ZDOTDIR/.zshrc"
_dotfiles_missing_app() {
  print -u2 -- "Shortcut '$1' requires '$2', which is not installed."
  return 127
}
if (( $+commands[mise] )); then
  alias mdot='mise dot apply --force --yes'
  alias mu='mise self-update --yes && mise bootstrap --upgrade --yes'
else
  alias mdot='_dotfiles_missing_app mdot mise'
  alias mu='_dotfiles_missing_app mu mise'
fi

# Use CLI shortcuts when their app exists, with a clear fallback otherwise.
if (( $+commands[codex] )); then
  alias cxyolo='codex --dangerously-bypass-approvals-and-sandbox'
  alias cxauto='codex --approve-for-me'
else
  alias cxyolo='_dotfiles_missing_app cxyolo codex'
  alias cxauto='_dotfiles_missing_app cxauto codex'
fi

if (( $+commands[git] )); then
  alias gcm='git switch "$(git main-branch)" && git pull'
  alias gpf='git push --force-with-lease --force-if-includes'
else
  alias gcm='_dotfiles_missing_app gcm git'
  alias gpf='_dotfiles_missing_app gpf git'
fi

if (( $+commands[lazygit] )); then
  alias lz='lazygit'
else
  alias lz='_dotfiles_missing_app lz lazygit'
fi

if (( $+commands[gh] )); then
  alias prc='gh pr create --web'
  alias prv='gh pr view --web'
else
  alias prc='_dotfiles_missing_app prc gh'
  alias prv='_dotfiles_missing_app prv gh'
fi

if (( $+commands[kubectl] )); then
  alias kc='kubectl config use-context'
else
  alias kc='_dotfiles_missing_app kc kubectl'
fi

if (( $+commands[pbcopy] )); then
  alias cbc='pbcopy'
else
  alias cbc='_dotfiles_missing_app cbc pbcopy'
fi
if (( $+commands[pbpaste] )); then
  alias cbp='pbpaste'
else
  alias cbp='_dotfiles_missing_app cbp pbpaste'
fi

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

# fzf uses fd candidates and bat previews.
if (( $+commands[fzf] )); then
  FZF_CTRL_R_COMMAND= source <(fzf --zsh)
fi

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
  alias cc='z'
  alias dc='z'
else
  alias cc='cd'
  alias dc='cd'
fi

# Starship renders the prompt and manages its Zsh hooks.
eval "$(starship init zsh)"

if [[ -r "$ZDOTDIR/.zshrc.local" ]]; then
  source "$ZDOTDIR/.zshrc.local"
fi

# ── zsh plugins (loaded last for proper terminal rendering) ───────────────────
HB_PREFIX="/opt/homebrew/share"

if [[ -f "$HB_PREFIX/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$HB_PREFIX/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
fi

if [[ -f "$HB_PREFIX/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$HB_PREFIX/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
