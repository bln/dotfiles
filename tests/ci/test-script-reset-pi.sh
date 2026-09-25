#!/usr/bin/env bash
# ci: reset-pi clears session state but never config/auth/extensions, and its
# PI_CODING_AGENT_DIR guard refuses catastrophic targets.
# CI exercises structural/safety paths only; real CLI verification is in host/.

echo "== ci: reset-pi =="

RESET="$REPO/scripts/reset-pi.sh"

# Keep-list vs delete: kept files and managed extensions survive, sessions clear.
{
  home="$(sandbox)"
  decoy="$home/default"
  mkdir -p "$decoy/agent/sessions"
  touch "$decoy/agent/sessions/decoy.json"
  mkdir -p "$home/agent/sessions" "$home/agent/extensions/ext1"
  for keep in auth.json AGENTS.md settings.json models.json models-store.json; do
    touch "$home/agent/$keep"
  done
  touch "$home/agent/sessions/s1.json"
  echo x >"$home/agent/extensions/ext1/ext.js"
  out="$(PI_HOME="$decoy" PI_CODING_AGENT_DIR="$home/agent" bash "$RESET" 2>&1)"; rc=$?
  assert_eq "exits 0" "0" "$rc"
  for keep in auth.json AGENTS.md settings.json models.json models-store.json; do
    assert_file "kept $keep" "$home/agent/$keep"
  done
  assert_not_exists "cleared sessions" "$home/agent/sessions"
  assert_file "kept managed extension" "$home/agent/extensions/ext1/ext.js"
  assert_file "ignored PI_HOME decoy" "$decoy/agent/sessions/decoy.json"
}

# --dry-run deletes nothing.
{
  home="$(sandbox)"
  mkdir -p "$home/agent/sessions"; touch "$home/agent/sessions/s1.json" "$home/agent/auth.json"
  out="$(PI_CODING_AGENT_DIR="$home/agent" bash "$RESET" --dry-run 2>&1)"; rc=$?
  assert_eq "dry-run exits 0" "0" "$rc"
  assert_file "dry-run keeps sessions" "$home/agent/sessions/s1.json"
  assert_contains "dry-run says DRY RUN" "$out" "DRY RUN"
}

# Missing agent dir is a clean no-op.
{
  out="$(PI_CODING_AGENT_DIR="$(sandbox)/nope" bash "$RESET" 2>&1)"; rc=$?
  assert_eq "missing dir exits 0" "0" "$rc"
  assert_contains "missing dir reports no-op" "$out" "nothing to clear"
}

# PI_CODING_AGENT_DIR guard: a catastrophic target is refused.
{
  set +e; out="$(PI_CODING_AGENT_DIR="/etc" bash "$RESET" 2>&1)"; rc=$?; set -e
  assert_eq "refuses /etc (exit 2)" "2" "$rc"
  assert_contains "names the unsafe target" "$out" "unsafe PI_CODING_AGENT_DIR"
}

# Depth guard: shallow non-denylisted path is refused.
{
  set +e; out="$(PI_CODING_AGENT_DIR="/singlesegment" bash "$RESET" 2>&1)"; rc=$?; set -e
  assert_eq "refuses shallow path (exit 2)" "2" "$rc"
  assert_contains "names the unsafe target" "$out" "unsafe PI_CODING_AGENT_DIR"
}
