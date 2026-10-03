# mise adds its managed Node and uv versions to the interactive shell.
if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
fi

export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less -FRX}"
export HOMEBREW_BUNDLE_FILE="${HOMEBREW_BUNDLE_FILE:-$HOME/Brewfile}"

# BSD ls (the macOS default) uses LSCOLORS for its color palette. Use cool
# colors for directories and links, green for executables, and keep all
# backgrounds neutral so listings stay readable across terminal themes.
export CLICOLOR=1
export LSCOLORS='ExGxFxDxCxBxBxCxCxExDx'
alias ls='command ls -G'
alias l='ls -lh'
alias ll='ls -lah'
alias la='ls -A'
alias lla='ls -lah'
alias c='clear'
alias q='exit'

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

autoload -Uz add-zsh-hook

# Starship-inspired prompt: keep context on its own line and the command
# prompt below it so long paths and Git state do not compete for one row.
# Show only the last three path components once the directory gets deep.
_dotfiles_git_prompt() {
  local line branch='' branch_oid='' counts x y
  local ahead=0 behind=0 staged=0 modified=0 untracked=0 deleted=0 conflicted=0
  local status_output

  status_output="$(command git status --porcelain=v2 --branch --untracked-files=normal 2>/dev/null)" || return 0

  while IFS= read -r line; do
    case "$line" in
      '# branch.head '*)
        branch="${line#'# branch.head '}"
        ;;
      '# branch.oid '*)
        branch_oid="${line#'# branch.oid '}"
        ;;
      '# branch.ab '*)
        counts="${line#'# branch.ab '}"
        ahead="${counts%% *}"
        behind="${counts##* }"
        ahead="${ahead#+}"
        behind="${behind#-}"
        ;;
      '1 '*|'2 '*|'u '*)
        x="${line[3]}"
        y="${line[4]}"
        if [[ "$x$y" == *U* ]]; then
          (( conflicted += 1 ))
        elif [[ "$x" == D || "$y" == D ]]; then
          (( deleted += 1 ))
        else
          [[ "$x" != ' ' && "$x" != '.' ]] && (( staged += 1 ))
          [[ "$y" != ' ' && "$y" != '.' ]] && (( modified += 1 ))
        fi
        ;;
      '? '*)
        (( untracked += 1 ))
        ;;
    esac
  done <<< "$status_output"

  if [[ -z "$branch" || "$branch" == '(detached)' ]]; then
    branch="HEAD ${branch_oid[1,7]}"
  fi

  local git_segment="  %F{magenta} ${branch}%f"
  local sync_segment='' dirty_segment=''

  if (( ahead > 0 && behind > 0 )); then
    sync_segment=" %F{cyan}⇕${ahead}/${behind}%f"
  elif (( ahead > 0 )); then
    sync_segment=" %F{cyan}⇡${ahead}%f"
  elif (( behind > 0 )); then
    sync_segment=" %F{cyan}⇣${behind}%f"
  fi

  (( conflicted > 0 )) && dirty_segment+=" %F{red}=${conflicted}%f"
  (( staged > 0 )) && dirty_segment+=" %F{green}+${staged}%f"
  (( modified > 0 )) && dirty_segment+=" %F{yellow}!${modified}%f"
  (( untracked > 0 )) && dirty_segment+=" %F{cyan}?${untracked}%f"
  (( deleted > 0 )) && dirty_segment+=" %F{red}✘${deleted}%f"

  if [[ -z "$sync_segment$dirty_segment" ]]; then
    dirty_segment=' %F{green}✓%f'
  fi

  print -r -- "${git_segment}${sync_segment}${dirty_segment}"
}

setopt PROMPT_SUBST
typeset -g _prompt_status='%F{green}❯%f'

_update_prompt() {
  local exit_status=$?
  _prompt_git="$(_dotfiles_git_prompt)"
  if (( exit_status == 0 )); then
    typeset -g _prompt_status='%F{green}❯%f'
  else
    typeset -g _prompt_status="%F{red}✘ ${exit_status}%f"
  fi
}
add-zsh-hook precmd _update_prompt

PROMPT=$'%F{blue}╭─%f %F{cyan}%(4~|…/|)%3~%f${_prompt_git}\n%F{blue}╰─%f ${_prompt_status} '

alias ..='cd ..'
alias ...='cd ../..'

if [[ -r "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
