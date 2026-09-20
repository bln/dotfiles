#!/usr/bin/env bash
# host (opt-in, mutates this machine): install.sh is safe to re-run - the
# idempotency failure mode the owner actually hit. Gated behind
# DOTFILES_TEST_MUTATE=1 so `verify` stays non-destructive by default.

echo "== host: converge idempotent =="

if [ "${DOTFILES_TEST_MUTATE:-0}" != "1" ]; then
  skip "converge-idempotent (set DOTFILES_TEST_MUTATE=1 to run; mutates this machine)"
  return 0
fi
if ! command -v mise >/dev/null 2>&1; then
  skip "converge-idempotent (mise not installed)"
  return 0
fi

run_capture bash "$REPO/install.sh"
assert_eq "install.sh re-run exits 0" "0" "$RUN_STATUS"

# On a converged host a re-plan must be empty: --detailed-exitcode returns 0
# when there is nothing left to do.
run_capture env mise -C "$REPO" -q bootstrap plan --detailed-exitcode
assert_eq "bootstrap plan empty after re-run" "0" "$RUN_STATUS"
