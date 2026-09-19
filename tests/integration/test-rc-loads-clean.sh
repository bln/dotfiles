#!/usr/bin/env bash
# Integration: the shipped zsh rc files load cleanly on a fresh machine.
#
# Targets FM6 (shell errors on start): a real failure the owner hit. Greps of
# .zshrc for a string cannot catch this - the file can contain the right text
# and still error at runtime (bad eval, unguarded setopt, missing guard around a
# plugin). We symlink the three real rc files into a sandbox HOME/ZDOTDIR and
# actually start zsh, asserting exit 0 and empty stderr.
#
# zsh must run under a pseudo-terminal: `zsh -i -c` on a pipe takes a non-tty
# path where fzf's key-binding init emits a benign `can't change option: zle`
# warning that never appears in a real terminal. zsh_startup (testlib) wraps the
# GNU/BSD `script` split so interactive startup matches a real login.
#
# Runs twice: first start builds the compinit dump (slow path), second reuses it
# (fast path) - both must stay clean.
#
# Also asserts the completion system actually initialized (compdef defined) and
# that an alias-triggered completion autoload succeeds. The rc comment warns
# that a mis-ordered $fpath makes `cat=bat` fail with "function definition file
# not found" on autoload; this proves the ordering works at runtime, tool-less
# safe (autoload resolves _bat from the zsh distribution's stub regardless).

echo "== rc-loads-clean =="

if ! command -v zsh >/dev/null 2>&1; then
  skip "rc-loads-clean (zsh not installed)"
  return 0
fi
if ! command -v script >/dev/null 2>&1; then
  skip "rc-loads-clean (script/pty not available)"
  return 0
fi

for flag in -l -i; do
  case "$flag" in
    -l) mode="login" ;;
    -i) mode="interactive" ;;
  esac
  sb="$(zsh_home)"   # one HOME per mode so pass 2 reuses pass 1's compinit dump
  for pass_n in 1 2; do
    zsh_startup "$flag" "$sb"
    assert_eq "$mode startup exits 0 (pass $pass_n)" "0" "$RUN_STATUS"
    stderr_content="$(cat "$RUN_STDERR")"
    assert_eq "$mode startup has empty stderr (pass $pass_n)" "" "$stderr_content"
  done
done

# Completion system initialized in an interactive shell (compinit ran, so
# `compdef` is a defined function). Probe stdout for a token, not exact match,
# since the pty injects terminal escape sequences.
sb="$(zsh_home)"
zsh_startup -i "$sb" 'whence -w compdef >/dev/null 2>&1 && print COMPDEF_OK'
assert_contains "compinit initialized (compdef defined)" "$(cat "$RUN_STDOUT")" "COMPDEF_OK"

# The rc prepends its generated-completions dir ($XDG_CACHE_HOME/zsh/completions)
# to $fpath before compinit. Plant a completion stub there and confirm it
# autoloads: this fails with "function definition file not found" if that
# prepend is dropped or ordered after compinit - the exact regression the rc
# comment warns about. Tool-less (no real tool needed).
compdir="$sb/.cache/zsh/completions"
mkdir -p "$compdir"
printf '#compdef faketool\n_faketool() { _message faked; }\n' >"$compdir/_faketool"
zsh_startup -i "$sb" 'autoload -Uz +X _faketool 2>&1 && print AUTOLOAD_OK'
assert_contains "repo fpath prepend makes a completion autoloadable" "$(cat "$RUN_STDOUT")" "AUTOLOAD_OK"
