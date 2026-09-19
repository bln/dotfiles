#!/usr/bin/env bash
# Integration: `mise bootstrap plan` is deterministic (FM1 idempotency, FM3
# silent partial converge).
#
# The plan is what a converge would DO. If it is non-deterministic - two reads
# of the same declared-vs-actual state produce different plans - then "safe
# re-runs" is a lie and a converge can silently do different things each time.
# We run the plan twice against the real (trusted) config and assert the output
# is byte-identical.
#
# This is inherently host-coupled: `mise bootstrap plan` reads live machine state
# and requires the config to be trusted. It therefore skips cleanly when mise is
# absent or the config is not trusted (minimal CI runners), and only exercises on
# a converged host - the same tier as `verify`. It does NOT mutate the machine
# (plan is read-only).

echo "== bootstrap-plan =="

if ! command -v mise >/dev/null 2>&1; then
  skip "bootstrap-plan (mise not installed)"
  return 0
fi

CONFIG="$REPO/home/.config/mise/config.toml"

# Trust check: an untrusted config makes `plan` error out with no plan, which is
# not this test's subject. On a converged host the config is already trusted.
if ! MISE_GLOBAL_CONFIG_FILE="$CONFIG" mise -q bootstrap plan >/dev/null 2>&1; then
  skip "bootstrap-plan (config not trusted / plan unavailable on this host)"
  return 0
fi

plan_once() {
  MISE_GLOBAL_CONFIG_FILE="$CONFIG" mise -q bootstrap plan 2>/dev/null
}

p1="$(mktemp)"; p2="$(mktemp)"; sandboxes+=("$p1" "$p2")
plan_once >"$p1"
plan_once >"$p2"

if diff -q "$p1" "$p2" >/dev/null 2>&1; then
  ok "bootstrap plan is reproducible across two reads"
else
  bad "bootstrap plan is reproducible across two reads" \
      "two consecutive plans differ:$(printf '\n')$(diff "$p1" "$p2" | head -20)"
fi
