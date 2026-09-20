#!/usr/bin/env bash
# shellcheck disable=SC2034 # RUN_STATUS/RUN_STDOUT/RUN_STDERR are read by sourcing tests
# Shared test library for the dotfiles test harness.
#
# Provides assertion helpers, sandbox management, and run_capture for separating
# stdout from stderr. Sourced by tests/run.sh; individual test files also source
# this so they can be developed/debugged in isolation.
#
# Convention: all helpers here are POSIX-compatible where practical, bash 3.2+
# otherwise (macOS ships bash 3.2). GNU-first with BSD fallback for stat/date.

# ── counters ─────────────────────────────────────────────────────────────────
pass=0
fail=0

# ── sandbox management ───────────────────────────────────────────────────────
# Two registration paths, both drained here:
#   - sandbox() runs in command substitution (a subshell) so it records dirs in a
#     manifest FILE, not the array: a `sandboxes+=(...)` inside the subshell (and
#     likewise an `export` of a new var) updates only the subshell's copy, which
#     the parent's EXIT trap never sees - that is the leak this replaces. The
#     manifest path is fixed HERE, in the parent, at source time, so every
#     subshell appends to the same file.
#   - run_capture/zsh_startup run in the parent shell and append RUN_STDOUT/ERR
#     temp files to the `sandboxes` array directly.
sandboxes=()
SANDBOX_MANIFEST="$(mktemp)"
cleanup() {
  for d in "${sandboxes[@]:-}"; do
    [ -n "$d" ] && rm -rf "$d"
  done
  if [ -f "$SANDBOX_MANIFEST" ]; then
    while IFS= read -r d; do
      [ -n "$d" ] && rm -rf "$d"
    done <"$SANDBOX_MANIFEST"
    rm -f "$SANDBOX_MANIFEST"
  fi
  return 0
}
trap cleanup EXIT

# sandbox: create a temp dir and register it (via the parent-owned manifest file,
# see above) for cleanup on EXIT. Safe to call inside command substitution.
sandbox() {
  local d
  d="$(mktemp -d)"
  printf '%s\n' "$d" >>"$SANDBOX_MANIFEST"
  printf '%s\n' "$d"
}

# ── output helpers ───────────────────────────────────────────────────────────
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; printf '       %s\n' "$2" >&2; fail=$((fail + 1)); }
# skip: record a non-failing skip (missing optional dependency). Counts as a
# pass so the suite stays green, but names what was not exercised.
skip() { printf '  skip %s\n' "$1"; pass=$((pass + 1)); }

# ── zsh_startup ──────────────────────────────────────────────────────────────
# Build (or reuse) a sandbox HOME/ZDOTDIR symlinking the repo's real rc files,
# then run zsh under a pseudo-terminal (so interactive startup matches a real
# terminal, not the `zsh -i -c` non-tty path which triggers a benign fzf
# `setopt zle` warning). GNU and BSD `script` differ; this handles both.
#   sb="$(zsh_home)"                       # once, to reuse across passes
#   zsh_startup <-i|-l> "$sb" ["cmd"]      # cmd runs inside the shell (default: exit)
# then read $RUN_STATUS, $RUN_STDOUT (cmd's stdout), $RUN_STDERR.
# If no sandbox is passed, a fresh one is created for that single run.
#
# Hermetic by design: the shell runs with a MINIMAL PATH (system dirs + zsh's
# own bin only), so the caller's real mise/starship/zoxide/fzf are invisible.
# This matches a fresh CI runner and, crucially, exercises the rc's `command -v`
# tool guards on their absent branch. It also avoids a hang: real `mise activate
# zsh` eval'd inside a login shell under a `script` pty blocks reading the tty.
# The integration suite also prepends fixture commands when it needs to exercise
# the tool-present branch; the verify tier covers the real installed machine.
zsh_home() {
  local sb
  sb="$(sandbox)"
  mkdir -p "$sb/.config/zsh" "$sb/.cache" "$sb/.local/share" "$sb/.local/state"
  ln -sf "$REPO/home/.zshenv"               "$sb/.zshenv"
  ln -sf "$REPO/home/.config/zsh/.zshrc"    "$sb/.config/zsh/.zshrc"
  ln -sf "$REPO/home/.config/zsh/.zprofile" "$sb/.config/zsh/.zprofile"
  printf '%s\n' "$sb"
}

zsh_startup() {
  local flag="$1" sb="${2:-}" cmd="${3:-exit}"
  [ -n "$sb" ] || sb="$(zsh_home)"
  RUN_STDOUT="$(mktemp)"; RUN_STDERR="$(mktemp)"; sandboxes+=("$RUN_STDOUT" "$RUN_STDERR")
  # Minimal PATH: system dirs plus wherever this zsh lives (so `zsh` and its
  # helpers resolve) - nothing from the caller's toolchain. Tests can prepend
  # a fixture directory with ZSH_STARTUP_EXTRA_PATH to exercise tool-present
  # branches without copying or modifying the real rc file.
  local zbin minpath
  zbin="$(dirname "$(command -v zsh)")"
  minpath="$zbin:/usr/bin:/bin:/usr/sbin:/sbin"
  if [ -n "${ZSH_STARTUP_EXTRA_PATH:-}" ]; then
    minpath="$ZSH_STARTUP_EXTRA_PATH:$minpath"
  fi
  # Pin HOME/ZDOTDIR and the XDG dirs at the sandbox so .zshenv resolves cache/
  # config/data inside it - otherwise the caller's real XDG_* leak through
  # `script`. stdin from /dev/null so no run can block on terminal input.
  set +e
  if script --version 2>/dev/null | grep -q util-linux; then
    HOME="$sb" ZDOTDIR="$sb/.config/zsh" PATH="$minpath" \
      XDG_CONFIG_HOME="$sb/.config" XDG_CACHE_HOME="$sb/.cache" \
      XDG_DATA_HOME="$sb/.local/share" XDG_STATE_HOME="$sb/.local/state" \
      script -qec "zsh $flag -c '$cmd'" /dev/null >"$RUN_STDOUT" 2>"$RUN_STDERR" </dev/null
  else
    HOME="$sb" ZDOTDIR="$sb/.config/zsh" PATH="$minpath" \
      XDG_CONFIG_HOME="$sb/.config" XDG_CACHE_HOME="$sb/.cache" \
      XDG_DATA_HOME="$sb/.local/share" XDG_STATE_HOME="$sb/.local/state" \
      script -q /dev/null zsh "$flag" -c "$cmd" >"$RUN_STDOUT" 2>"$RUN_STDERR" </dev/null
  fi
  RUN_STATUS=$?
  set -e
}

# ── run_capture ──────────────────────────────────────────────────────────────
# Run a command capturing stdout and stderr separately.
#   run_capture COMMAND [ARGS...]
# After the call:
#   $RUN_STATUS  - exit code
#   $RUN_STDOUT  - path to file containing stdout
#   $RUN_STDERR  - path to file containing stderr
RUN_STATUS=0
RUN_STDOUT=""
RUN_STDERR=""

run_capture() {
  RUN_STDOUT="$(mktemp)"
  RUN_STDERR="$(mktemp)"
  sandboxes+=("$RUN_STDOUT" "$RUN_STDERR")
  set +e
  "$@" >"$RUN_STDOUT" 2>"$RUN_STDERR"
  RUN_STATUS=$?
  set -e
}

# ── assertion helpers ────────────────────────────────────────────────────────

# assert_eq LABEL EXPECTED ACTUAL
assert_eq() {
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$2], got [$3]"; fi
}

# assert_contains LABEL HAYSTACK NEEDLE
assert_contains() {
  case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "output does not contain [$3]" ;; esac
}

# assert_not_contains LABEL HAYSTACK NEEDLE
assert_not_contains() {
  case "$2" in *"$3"*) bad "$1" "output should not contain [$3]" ;; *) ok "$1" ;; esac
}

# assert_file LABEL PATH
assert_file() {
  if [ -f "$2" ]; then ok "$1"; else bad "$1" "missing file: $2"; fi
}

# assert_dir LABEL PATH
assert_dir() {
  if [ -d "$2" ]; then ok "$1"; else bad "$1" "missing directory: $2"; fi
}

# assert_symlink LABEL PATH
assert_symlink() {
  if [ -L "$2" ]; then ok "$1"; else bad "$1" "not a symlink: $2"; fi
}

# assert_symlink_to LABEL PATH EXPECTED_TARGET
assert_symlink_to() {
  if [ ! -L "$2" ]; then
    bad "$1" "not a symlink: $2"
  else
    local actual
    actual="$(readlink "$2")"
    if [ "$actual" = "$3" ]; then ok "$1"; else bad "$1" "symlink points to [$actual], expected [$3]"; fi
  fi
}

# assert_not_exists LABEL PATH
assert_not_exists() {
  if [ ! -e "$2" ] && [ ! -L "$2" ]; then ok "$1"; else bad "$1" "should not exist: $2"; fi
}

# assert_mode LABEL PATH EXPECTED_MODE
# GNU stat first (Linux/CI), BSD fallback (macOS).
assert_mode() {
  local mode
  mode="$(stat -c '%a' "$2" 2>/dev/null || stat -f '%Lp' "$2")"
  if [ "$mode" = "$3" ]; then ok "$1"; else bad "$1" "mode is [$mode], expected [$3]"; fi
}

# assert_json LABEL PATH
# Validates the file is parseable JSON. Skips if jq is not installed.
assert_json() {
  if ! command -v jq >/dev/null 2>&1; then
    ok "$1 (skipped - jq not installed)"
    return
  fi
  if jq empty "$2" 2>/dev/null; then ok "$1"; else bad "$1" "$2 is not valid JSON"; fi
}

# assert_no_placeholder LABEL CONTENT
# Checks that no {{ ... }} template placeholders remain.
assert_no_placeholder() {
  case "$2" in
    *'{{'*) bad "$1" "found {{ in output" ;;
    *) ok "$1" ;;
  esac
}
