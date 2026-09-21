#!/usr/bin/env bash
# ci: the shipped zsh rc files load cleanly on a fresh machine, and the
# optional tool branches remain clean on both absent and present paths.
#
# This is the highest-value shell check and one grep cannot make: a .zshrc can
# contain exactly the right text and still error at runtime (bad eval, unguarded
# setopt, $fpath ordered so a completion autoload fails). We symlink the real rc
# files into a sandbox HOME/ZDOTDIR and actually start zsh under a pty (see
# zsh_startup in testlib - the pty makes startup match a real terminal and
# avoids fzf's benign non-tty warning). The shell runs with a MINIMAL PATH so
# the caller's real toolchain is invisible; that exercises the `command -v` tool
# guards on their ABSENT branch and matches a fresh CI runner. A fixture bin
# prepended via ZSH_STARTUP_EXTRA_PATH exercises the PRESENT branch.

echo "== ci: shell startup =="

if ! command -v zsh >/dev/null 2>&1; then skip "shell startup (zsh not installed)"; return 0; fi
if ! command -v script >/dev/null 2>&1; then skip "shell startup (script/pty not available)"; return 0; fi

# Clean startup, login + interactive, run twice (pass 1 builds the compinit
# dump, pass 2 reuses it) - both must exit 0 with empty stderr.
for flag in -l -i; do
  case "$flag" in -l) mode=login ;; -i) mode=interactive ;; esac
  sb="$(zsh_home)"
  for pass_n in 1 2; do
    zsh_startup "$flag" "$sb"
    assert_eq "$mode startup exits 0 (pass $pass_n)" "0" "$RUN_STATUS"
    assert_eq "$mode startup has empty stderr (pass $pass_n)" "" "$(cat "$RUN_STDERR")"
  done
done

# Completion system initialized (compinit ran) and the repo's fpath prepend
# makes a planted completion autoloadable - the exact regression the .zshrc
# comment warns about (a mis-ordered $fpath breaks generated completions).
sb="$(zsh_home)"
zsh_startup -i "$sb" 'whence -w compdef >/dev/null 2>&1 && print COMPDEF_OK'
assert_contains "compinit initialized" "$(cat "$RUN_STDOUT")" "COMPDEF_OK"

compdir="$sb/.cache/zsh/completions"; mkdir -p "$compdir"
printf '#compdef faketool\n_faketool() { _message faked; }\n' >"$compdir/_faketool"
zsh_startup -i "$sb" 'autoload -Uz +X _faketool 2>&1 && print AUTOLOAD_OK'
assert_contains "repo fpath prepend makes a completion autoloadable" "$(cat "$RUN_STDOUT")" "AUTOLOAD_OK"

# Optional-tool branch: the same real rc still starts cleanly.
fixture_bin="$sb/bin"; mkdir -p "$fixture_bin"
for tool in eza bat nvim zoxide codex claude mise; do printf '#!/bin/sh\nexit 0\n' >"$fixture_bin/$tool"; chmod +x "$fixture_bin/$tool"; done
ZSH_STARTUP_EXTRA_PATH="$fixture_bin" zsh_startup -i "$sb"
assert_eq "optional-tool startup exits 0" "0" "$RUN_STATUS"
assert_eq "optional-tool startup has empty stderr" "" "$(cat "$RUN_STDERR")"
