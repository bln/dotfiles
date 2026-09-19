#!/usr/bin/env bash
# Test harness for this repo's shell scripts.
#
# Plain bash (no bats/framework, per AGENTS.md). Each test exercises the REAL
# shipped script - never a copy - by pointing its documented override seam at a
# mktemp sandbox.
#
# Usage:
#   bash tests/run.sh           # run CI suites (static, unit, integration)
#   bash tests/run.sh verify    # host-only behavioral checks (macOS, not CI)
set -euo pipefail

REPO="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export REPO
TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── load test library ─────────────────────────────────────────────────────────
# shellcheck source=lib/testlib.sh
source "$TEST_ROOT/lib/testlib.sh"

run_suite() {
  local suite="$1"
  local suite_dir="$TEST_ROOT/$suite"
  if [ ! -d "$suite_dir" ]; then
    printf 'warning: no %s suite directory\n' "$suite" >&2
    return
  fi
  local found=false
  for test_file in "$suite_dir"/test-*.sh; do
    [ -f "$test_file" ] || continue
    found=true
    source "$test_file"
  done
  if [ "$found" = false ]; then
    printf 'warning: no test-*.sh files in %s/\n' "$suite" >&2
  fi
}

case "${1:-}" in
  "")
    for suite in static unit integration; do run_suite "$suite"; done
    ;;
  verify)
    run_suite verify
    ;;
  *)
    printf 'usage: %s [verify]\n' "$0" >&2
    exit 2
    ;;
esac

# ── summary ───────────────────────────────────────────────────────────────────
echo
echo "== summary: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
