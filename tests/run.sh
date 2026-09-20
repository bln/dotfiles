#!/usr/bin/env bash
# shellcheck disable=SC2154 # pass/fail counters are defined in the sourced testlib.sh
# Test harness for this repo. Plain bash, no framework (per AGENTS.md).
#
# Tests are organised by the ONE question that decides where a test can run:
# does it need a converged macOS host?
#
#   ci/    hermetic - no host tools, no network. Runs on every push (Linux+macOS
#          CI) and on any laptop. This is the wide base of the pyramid: script
#          logic via sandboxes/seams, shell startup under a pty, format parse.
#   host/  needs a real converged mac (tools installed, real `code`, GUI login).
#          Wired into `mise run verify`, never CI. Skips cleanly off-host.
#
# Every test exercises the REAL shipped script/config through its documented
# seam (env var or flag pointed at a mktemp sandbox) - never a copy. See
# docs/TESTING.md for the philosophy and the boundary against re-testing mise.
#
# Usage:
#   bash tests/run.sh          # ci tier (default; what CI runs)
#   bash tests/run.sh host     # host tier (macOS, opt-in)
#   bash tests/run.sh all      # both
set -euo pipefail

REPO="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export REPO
TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/testlib.sh
source "$TEST_ROOT/lib/testlib.sh"

run_suite() {
  local suite="$1"
  local suite_dir="$TEST_ROOT/$suite"
  if [ ! -d "$suite_dir" ]; then
    printf 'warning: no %s suite directory\n' "$suite" >&2
    return
  fi
  local found=false test_file
  for test_file in "$suite_dir"/test-*.sh; do
    [ -f "$test_file" ] || continue
    found=true
    # A sourced file's own exit status is never the suite verdict ($fail is);
    # never let a trailing nonzero abort the run under `set -e`.
    # shellcheck disable=SC1090 # discovered by glob, not a constant path
    source "$test_file" || true
  done
  [ "$found" = true ] || printf 'warning: no test-*.sh files in %s/\n' "$suite" >&2
}

case "${1:-}" in
  ""|ci) run_suite ci ;;
  host)  run_suite host ;;
  all)   run_suite ci; run_suite host ;;
  *)     printf 'usage: %s [ci|host|all]\n' "$0" >&2; exit 2 ;;
esac

echo
echo "== summary: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
