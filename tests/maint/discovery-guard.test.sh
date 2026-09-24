#!/usr/bin/env bash
# shellcheck disable=SC2154 # pass/fail counters come from the sourced testlib.sh
# maint: guard - prove tests/run.sh (ci/host/all) NEVER discovers or executes
# anything under tests/maint/. This locks the isolation so a future refactor of
# run.sh's discovery cannot silently pull maintenance tests into `mise run
# test`/`verify`/CI. Standalone like its siblings (prints its own summary).
#
# Run it directly:  bash tests/maint/discovery-guard.test.sh
#
# Method: drop a sentinel *.test.sh AND a sentinel test-*.sh into a throwaway
# copy of tests/maint inside a sandbox, point a copy of run.sh's discovery at
# it, and assert the sentinels never fire. We test the real run.sh's contract
# two ways: (1) it only iterates suites ci/host, and (2) its glob is test-*.sh,
# so a *.test.sh name is immune even if a maint dir were ever scanned.
set -euo pipefail

REPO="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export REPO
# shellcheck source=tests/lib/testlib.sh
source "$REPO/tests/lib/testlib.sh"

RUN="$REPO/tests/run.sh"

echo "== maint: discovery guard =="

# (1) run.sh's case statement must not route to a maint suite. Inspect source:
# the accepted words are ci/host/all/"" - never maint. Slice from the case to
# esac and assert no run_suite maint / maint) branch exists.
{
  case_block="$(sed -n '/case "${1:-}"/,/esac/p' "$RUN")"
  assert_not_contains "run.sh case has no maint branch" "$case_block" "maint"
  run_capture bash "$RUN" maint
  assert_eq "run.sh rejects 'maint' arg" "2" "$RUN_STATUS"
  assert_contains "usage lists only ci|host|all" "$(cat "$RUN_STDERR")" "ci|host|all"
}

# (2) run.sh's discovery glob is test-*.sh; maint files are *.test.sh, so even a
# maint dir scanned by that glob yields nothing. Prove the naming is immune.
{
  sb="$(sandbox)"; mkdir -p "$sb/maint"
  # Sentinels: if either were sourced by the test-*.sh glob, it aborts loudly.
  echo 'echo SENTINEL_FIRED_DOTTEST; exit 99' >"$sb/maint/reset.test.sh"
  echo 'echo SENTINEL_FIRED_DASH; exit 99'    >"$sb/maint/helper.sh"
  matches="$(find "$sb/maint" -name 'test-*.sh' | wc -l | tr -d ' ')"
  assert_eq "no maint file matches the test-*.sh glob" "0" "$matches"
}

# (3) End-to-end: a full `run.sh all` never emits a maint sentinel. Plant one in
# the REAL tests/maint via a name that WOULD match test-*.sh, run all, remove it.
# If run.sh ever scanned maint/, the sentinel string would appear in output.
{
  planted="$REPO/tests/maint/test-SENTINEL-guard.sh"
  # shellcheck disable=SC2064 # expand planted now so the trap removes this exact file
  trap "rm -f '$planted'" EXIT
  echo 'echo MAINT_SENTINEL_FIRED' >"$planted"
  run_capture bash "$RUN" all
  assert_not_contains "run.sh all never sourced tests/maint" "$(cat "$RUN_STDOUT")" "MAINT_SENTINEL_FIRED"
  rm -f "$planted"; trap - EXIT
}

echo
echo "== summary: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
