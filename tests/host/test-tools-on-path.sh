#!/usr/bin/env bash
# host (macOS, not CI): the converged shell actually resolves tools and loaded
# its plugins. This is the BEHAVIORAL counterpart to shell-startup's absent
# branch: a string can be present in .zshrc while the runtime is broken; only a
# real interactive login shell can prove the tools and plugins are truly there.
#
# We probe a representative sample, not the whole [tools] list - the point is
# "activation works and PATH is right", not to re-enumerate the config (that
# would be double-entry that breaks on every tool add). See docs/TESTING.md.

echo "== host: tools on path =="

if ! command -v zsh >/dev/null 2>&1; then skip "tools-on-path (zsh not installed)"; return 0; fi

in_login_shell() {
  local cmd="$1"
  if script --version 2>/dev/null | grep -q util-linux; then
    script -qec "zsh -i -l -c '$cmd'" /dev/null 2>/dev/null
  else
    script -q /dev/null zsh -i -l -c "$cmd" 2>/dev/null
  fi
}

# A representative sample across mise [tools] and brew packages.
for tool in mise starship fzf bat rg jq; do
  if in_login_shell "command -v $tool >/dev/null && echo FOUND" | grep -q FOUND; then
    ok "$tool resolves on PATH"
  else
    bad "$tool resolves on PATH" "command -v $tool failed in interactive login shell"
  fi
done

# PATH shape: ~/.local/bin present (script-installed tools) + brew prefix.
# shellcheck disable=SC2016 # $PATH must expand in the spawned shell
path_out="$(in_login_shell 'echo "$PATH"')"
assert_contains "PATH includes ~/.local/bin" "$path_out" "/.local/bin"
if command -v brew >/dev/null 2>&1; then
  assert_contains "PATH includes brew prefix bin" "$path_out" "$(brew --prefix)/bin"
else
  skip "PATH includes brew prefix bin (brew not installed)"
fi

# Plugins loaded their shell functions (not merely referenced in rc).
for fn in _zsh_autosuggest_start _zsh_highlight; do
  if in_login_shell "typeset -f $fn >/dev/null && echo LOADED" | grep -q LOADED; then
    ok "zsh plugin loaded ($fn defined)"
  else
    bad "zsh plugin loaded ($fn)" "$fn not defined in interactive shell"
  fi
done
