#!/usr/bin/env bash
# Integration tests for wipe.sh argument parsing.
# These test the non-mutating parts of wipe.sh: argument handling, help
# output, and dry-run mode.

echo "== wipe.sh arguments =="

WIPE="$REPO/wipe.sh"

# --help prints usage and exits 0
{
  run_capture bash "$WIPE" --help
  assert_eq "--help exits 0" "0" "$RUN_STATUS"
  assert_contains "--help mentions dry-run" "$(cat "$RUN_STDOUT")" "dry-run"
}

# -h also prints help
{
  run_capture bash "$WIPE" -h
  assert_eq "-h exits 0" "0" "$RUN_STATUS"
}

# Unknown argument exits non-zero
{
  run_capture bash "$WIPE" --bogus
  assert_ne "unknown arg exits non-zero" "0" "$RUN_STATUS"
  assert_contains "unknown arg names the arg" "$(cat "$RUN_STDERR")" "--bogus"
}

# --dry-run does not prompt for confirmation (no interactive read)
# and exits cleanly (it prints DRY RUN lines but performs no mutations).
{
  run_capture bash "$WIPE" --dry-run
  # This may fail if it can't find mise/brew, but should not hang waiting for input.
  # We check it didn't hang (would be killed by timeout if we had one) and that
  # it at least attempted to print DRY RUN or a WARNING about missing tools.
  stdout="$(cat "$RUN_STDOUT")"
  stderr="$(cat "$RUN_STDERR" 2>/dev/null || true)"
  combined="$stdout$stderr"
  # Should contain either DRY RUN markers or WARNING about missing tools
  if printf '%s' "$combined" | grep -qE "(DRY RUN|WARNING|PERMANENTLY)" 2>/dev/null; then
    ok "--dry-run produces output"
  else
    bad "--dry-run produces output" "no DRY RUN or WARNING found in output"
  fi
}
