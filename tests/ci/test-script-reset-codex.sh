#!/usr/bin/env bash
# ci: reset-codex clears session state but never the config/auth keep-list, and
# its CODEX_HOME guard refuses catastrophic targets. Destructive code -> the
# keep-list and the guard are the data-loss safety nets.
#
# Seam: CODEX_HOME points at a sandbox; the no-override default is production.

echo "== ci: reset-codex =="

RESET="$REPO/scripts/reset-codex.sh"

# Keep-list vs delete: kept files survive, everything else is cleared.
{
  home="$(sandbox)"
  mkdir -p "$home/sessions" "$home/skills/s" "$home/rules"
  for keep in auth.json config.toml AGENTS.md AGENTS.override.md; do touch "$home/$keep"; done
  echo x >"$home/skills/s/SKILL.md"
  touch "$home/sessions/s1.json" "$home/scratch.tmp"
  out="$(CODEX_HOME="$home" bash "$RESET" 2>&1)"; rc=$?
  assert_eq "exits 0" "0" "$rc"
  for keep in auth.json config.toml AGENTS.md AGENTS.override.md skills/s/SKILL.md; do
    assert_file "kept $keep" "$home/$keep"
  done
  assert_dir "kept rules dir" "$home/rules"
  assert_not_exists "cleared sessions" "$home/sessions"
  assert_not_exists "cleared scratch"  "$home/scratch.tmp"
}

# --dry-run deletes nothing.
{
  home="$(sandbox)"; mkdir -p "$home/sessions"; touch "$home/sessions/s1.json" "$home/auth.json"
  out="$(CODEX_HOME="$home" bash "$RESET" --dry-run 2>&1)"; rc=$?
  assert_eq "dry-run exits 0" "0" "$rc"
  assert_file "dry-run keeps sessions" "$home/sessions/s1.json"
  assert_contains "dry-run says DRY RUN" "$out" "DRY RUN"
}

# Missing dir is a clean no-op.
{
  out="$(CODEX_HOME="$(sandbox)/nope" bash "$RESET" 2>&1)"; rc=$?
  assert_eq "missing dir exits 0" "0" "$rc"
  assert_contains "missing dir reports no-op" "$out" "nothing to clear"
}

# CODEX_HOME guard: a catastrophic target is refused before any delete.
{
  set +e; out="$(CODEX_HOME="/etc" bash "$RESET" 2>&1)"; rc=$?; set -e
  assert_eq "refuses /etc (exit 2)" "2" "$rc"
  assert_contains "names the unsafe target" "$out" "unsafe CODEX_HOME"
}

# Depth guard: a shallow path that slips past the denylist (one segment below /)
# is still refused. /etc above never reaches this branch; /singlesegment does.
{
  set +e; out="$(CODEX_HOME="/singlesegment" bash "$RESET" 2>&1)"; rc=$?; set -e
  assert_eq "refuses shallow non-denylisted path (exit 2)" "2" "$rc"
  assert_contains "names the unsafe target" "$out" "unsafe CODEX_HOME"
}
