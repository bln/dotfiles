#!/usr/bin/env bash
# Verify-tier (macOS host only): the converged shell actually has the tools.
#
# Targets FM5 (tool declared but not on PATH) and the plugin-load regression the
# owner hit. This is the BEHAVIORAL replacement for the deleted source-grep
# brew-path-guard test: instead of asserting a string is in .zshrc, it starts a
# real interactive login shell and asks whether the tools and plugins are
# actually there. A string can be present while the runtime is broken; this can
# only pass if the shell truly resolves them.
#
# Host-coupled by design (reads the live machine): wired into `verify`, never
# into CI. Run under a pty so interactive startup matches a real terminal.

echo "== tools-on-path =="

if ! command -v zsh >/dev/null 2>&1; then
  skip "tools-on-path (zsh not installed)"
  return 0
fi

# Run a command inside a real interactive login zsh (this user's real config),
# under a pty, and capture stdout.
in_login_shell() {
  local cmd="$1" out
  if script --version 2>/dev/null | grep -q util-linux; then
    out="$(script -qec "zsh -i -l -c '$cmd'" /dev/null 2>/dev/null)"
  else
    out="$(script -q /dev/null zsh -i -l -c "$cmd" 2>/dev/null)"
  fi
  printf '%s' "$out"
}

# Core tools declared in [tools] / [bootstrap.packages] that must resolve.
for tool in mise starship zoxide fzf atuin bat eza fd rg jq gh; do
  if in_login_shell "command -v $tool >/dev/null && echo FOUND" | grep -q FOUND; then
    ok "$tool resolves on PATH"
  else
    bad "$tool resolves on PATH" "command -v $tool failed in interactive login shell"
  fi
done

# ~/.local/bin and the brew prefix are on PATH.
# shellcheck disable=SC2016  # $PATH must expand in the spawned shell, not here
path_out="$(in_login_shell 'echo "$PATH"')"
assert_contains "PATH includes ~/.local/bin" "$path_out" "/.local/bin"
if command -v brew >/dev/null 2>&1; then
  brew_bin="$(brew --prefix)/bin"
  assert_contains "PATH includes brew prefix bin" "$path_out" "$brew_bin"
else
  skip "PATH includes brew prefix bin (brew not installed)"
fi

# zsh plugins actually loaded their shell functions (not just referenced in rc).
if in_login_shell 'typeset -f _zsh_autosuggest_start >/dev/null && echo LOADED' | grep -q LOADED; then
  ok "zsh-autosuggestions loaded (function defined)"
else
  bad "zsh-autosuggestions loaded" "_zsh_autosuggest_start not defined in interactive shell"
fi
if in_login_shell 'typeset -f _zsh_highlight >/dev/null && echo LOADED' | grep -q LOADED; then
  ok "zsh-syntax-highlighting loaded (function defined)"
else
  bad "zsh-syntax-highlighting loaded" "_zsh_highlight not defined in interactive shell"
fi

# Tool completions were generated and are on $fpath: completing the `cat=bat`
# alias must autoload _bat without "function definition file not found". This is
# the exact failure the .zshrc completion block guards against; here the tool is
# really present, so the generated _bat file must exist and load.
if in_login_shell 'command -v bat >/dev/null || exit 3; autoload -Uz +X _bat 2>/dev/null && echo COMP_OK' | grep -q COMP_OK; then
  ok "bat completion autoloads (fpath ordering correct)"
elif ! command -v bat >/dev/null 2>&1; then
  skip "bat completion autoloads (bat not installed)"
else
  bad "bat completion autoloads" "_bat failed to autoload despite bat present (stale zcompdump / fpath order)"
fi
