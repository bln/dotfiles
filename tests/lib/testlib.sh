#!/usr/bin/env bash
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
sandboxes=()
cleanup() {
  for d in "${sandboxes[@]:-}"; do
    [ -n "$d" ] && rm -rf "$d"
  done
  return 0
}
trap cleanup EXIT

sandbox() {
  local d
  d="$(mktemp -d)"
  sandboxes+=("$d")
  printf '%s\n' "$d"
}

# ── output helpers ───────────────────────────────────────────────────────────
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; printf '       %s\n' "$2" >&2; fail=$((fail + 1)); }

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

# assert_ne LABEL NOT_EXPECTED ACTUAL
assert_ne() {
  if [ "$2" != "$3" ]; then ok "$1"; else bad "$1" "expected NOT [$2], got [$3]"; fi
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

# assert_exit LABEL EXPECTED_CODE COMMAND...
# Runs the command and checks the exit code.
assert_exit() {
  local label="$1" expected="$2"
  shift 2
  set +e
  "$@" >/dev/null 2>&1
  local rc=$?
  set -e
  assert_eq "$label" "$expected" "$rc"
}

# assert_no_placeholder LABEL CONTENT
# Checks that no {{ ... }} template placeholders remain.
assert_no_placeholder() {
  case "$2" in
    *'{{'*) bad "$1" "found {{ in output" ;;
    *) ok "$1" ;;
  esac
}
