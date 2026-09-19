#!/usr/bin/env bash
# Verify-tier, opt-in only: install.sh is safe to re-run on a real machine (FM1).
#
# The owner hit a re-run that was not idempotent. This runs the REAL install.sh
# a second time on this already-converged host and asserts it exits 0 and leaves
# no pending bootstrap work. It MUTATES the real machine (installs/updates via
# mise), so it is gated behind an explicit opt-in: set DOTFILES_TEST_MUTATE=1.
# Without that it skips - so `verify` stays non-destructive by default.

echo "== install-idempotent =="

if [ "${DOTFILES_TEST_MUTATE:-0}" != "1" ]; then
  skip "install-idempotent (set DOTFILES_TEST_MUTATE=1 to run; mutates this machine)"
  return 0
fi
if ! command -v mise >/dev/null 2>&1; then
  skip "install-idempotent (mise not installed)"
  return 0
fi

run_capture bash "$REPO/install.sh"
assert_eq "install.sh re-run exits 0" "0" "$RUN_STATUS"

# After a re-run on a converged host, the bootstrap plan should be empty:
# --detailed-exitcode returns 0 when there is nothing to do. The new entrypoint
# runs from the checkout (mise bootstrap --from --cd), so no config-file bridge
# is needed - plan reads the merged config from the repo cwd.
run_capture env mise -C "$REPO" -q bootstrap plan --detailed-exitcode
assert_eq "bootstrap plan is empty after re-run" "0" "$RUN_STATUS"
