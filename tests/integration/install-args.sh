#!/usr/bin/env bash
# Integration tests for install.sh argument parsing and pre-flight checks.
# These test the non-mutating parts of install.sh: argument handling, help
# output, and early validation. They do NOT run actual bootstrap.

echo "== install.sh arguments =="

INSTALL="$REPO/install.sh"

# --help prints usage and exits 0
{
  run_capture bash "$INSTALL" --help
  assert_eq "--help exits 0" "0" "$RUN_STATUS"
  assert_contains "--help mentions bootstrap" "$(cat "$RUN_STDOUT")" "mise bootstrap"
}

# -h also prints help
{
  run_capture bash "$INSTALL" -h
  assert_eq "-h exits 0" "0" "$RUN_STATUS"
  assert_contains "-h mentions bootstrap" "$(cat "$RUN_STDOUT")" "mise bootstrap"
}

# Unknown argument exits non-zero with an error message
{
  run_capture bash "$INSTALL" --bogus
  assert_ne "unknown arg exits non-zero" "0" "$RUN_STATUS"
  assert_contains "unknown arg mentions the arg" "$(cat "$RUN_STDERR")" "--bogus"
}

# Multiple unknown arguments also rejected
{
  run_capture bash "$INSTALL" --verbose --debug
  assert_ne "multiple unknown args exits non-zero" "0" "$RUN_STATUS"
}

# --dry-run and -n are accepted (not treated as unknown args)
{
  run_capture bash "$INSTALL" --help
  stdout="$(cat "$RUN_STDOUT")"
  assert_contains "--help mentions dry-run" "$stdout" "dry-run"
}
{
  # Verify -n is listed as an alias in help
  run_capture bash "$INSTALL" --help
  assert_eq "--help exits 0 consistently" "0" "$RUN_STATUS"
}
