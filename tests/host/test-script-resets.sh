#!/usr/bin/env bash
# host (macOS, not CI): reset-* scripts verified against real CLI binaries.
#
# For each agent (codex, claude, pi):
#   1. Build a sandbox seeded from the real config/auth (no sessions).
#   2. Inject session state (files/dirs).
#   3. Run the real reset script pointing at the sandbox.
#   4. Assert the CLI still considers itself healthy (config/auth intact).
#   5. Assert the session state is gone.
#
# Skips cleanly if a required binary is absent.

echo "== host: reset scripts (real CLIs) =="

RESET_CODEX="$REPO/scripts/reset-codex.sh"
RESET_CLAUDE="$REPO/scripts/reset-claude.sh"
RESET_PI="$REPO/scripts/reset-pi.sh"

CODEX_REAL="${XDG_CONFIG_HOME:-$HOME/.config}/codex"
CLAUDE_REAL="${CLAUDE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/claude}"
PI_REAL="${PI_CODING_AGENT_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/pi/agent}"

# ── codex ──────────────────────────────────────────────────────────────────────
if ! command -v codex >/dev/null 2>&1; then
  skip "reset-codex real-CLI (codex not installed)"
else
  home="$(sandbox)"
  # Seed config/auth from real install so doctor passes.
  [ -f "$CODEX_REAL/auth.json" ]   && cp "$CODEX_REAL/auth.json"   "$home/"
  [ -f "$CODEX_REAL/config.toml" ] && cp "$CODEX_REAL/config.toml" "$home/"
  # Inject session state.
  mkdir -p "$home/sessions" "$home/tmp"
  echo '{"id":"s1"}' >"$home/sessions/s1.jsonl"
  touch "$home/tmp/scratch.txt"
  session_count_before="$(find "$home/sessions" -type f | wc -l | tr -d ' ')"

  CODEX_HOME="$home" bash "$RESET_CODEX" >/dev/null 2>&1
  rc=$?
  assert_eq "codex: reset exits 0" "0" "$rc"
  assert_not_exists "codex: sessions cleared" "$home/sessions"
  assert_not_exists "codex: tmp cleared" "$home/tmp/scratch.txt"
  assert_file "codex: auth.json kept" "$home/auth.json"
  assert_file "codex: config.toml kept" "$home/config.toml"
  assert_eq "codex: had sessions before reset" "1" "$session_count_before"

  # CLI health: doctor reports config and auth ok.
  doctor_out="$(CODEX_HOME="$home" codex doctor 2>&1)"
  assert_contains "codex: doctor reports config ok" "$doctor_out" "✓ config"
  assert_contains "codex: doctor reports auth ok"   "$doctor_out" "✓ auth"
fi

# ── claude ─────────────────────────────────────────────────────────────────────
if ! command -v claude >/dev/null 2>&1; then
  skip "reset-claude real-CLI (claude not installed)"
else
  home="$(sandbox)"
  # Seed config/auth.
  [ -f "$CLAUDE_REAL/settings.json" ] && cp "$CLAUDE_REAL/settings.json" "$home/"
  [ -f "$CLAUDE_REAL/CLAUDE.md" ]     && cp "$CLAUDE_REAL/CLAUDE.md"     "$home/"
  # Minimal .claude.json with one project entry so purge has something to report.
  printf '{"projects":{"/tmp/fake":{"history":[]}}}\n' >"$home/.claude.json"
  mkdir -p "$home/projects/-tmp-fake" "$home/tasks" "$home/sessions" "$home/plans"
  echo '{"type":"human","text":"hi"}' >"$home/projects/-tmp-fake/transcript.jsonl"
  echo 'history line' >"$home/history.jsonl"
  echo '{"task":"x"}' >"$home/tasks/t1.json"
  echo x >"$home/plans/p1.md"
  touch "$home/sessions/s1.json"

  CLAUDE_CONFIG_DIR="$home" bash "$RESET_CLAUDE" >/dev/null 2>&1
  rc=$?
  assert_eq "claude: reset exits 0" "0" "$rc"
  assert_not_exists "claude: sessions cleared" "$home/sessions"
  assert_not_exists "claude: plans cleared" "$home/plans"
  # `claude project purge --all --dry-run` exits 1 when nothing remains.
  set +e
  purge_out="$(CLAUDE_CONFIG_DIR="$home" claude project purge --all --dry-run 2>&1)"; purge_rc=$?
  set -e
  assert_eq "claude: no project state remains (purge exits 1)" "1" "$purge_rc"
  assert_contains "claude: purge reports nothing found" "$purge_out" "No Claude Code project state found"
  # settings preserved - doctor or --version works.
  ver_out="$(CLAUDE_CONFIG_DIR="$home" claude --version 2>&1)"
  assert_contains "claude: binary still responds after reset" "$ver_out" "."
fi

# ── pi ─────────────────────────────────────────────────────────────────────────
if ! command -v pi >/dev/null 2>&1; then
  skip "reset-pi real-CLI (pi not installed)"
else
  pi_home="$(sandbox)"
  agent="$pi_home/agent"
  mkdir -p "$agent"
  # Seed config from real install.
  for f in settings.json models.json models-store.json; do
    [ -f "$PI_REAL/$f" ] && cp "$PI_REAL/$f" "$agent/"
  done
  # auth.json is a credential - copy only if present; tests verify behavior, not credentials.
  [ -f "$PI_REAL/auth.json" ] && cp "$PI_REAL/auth.json" "$agent/" || echo '{}' >"$agent/auth.json"
  # Inject session state.
  mkdir -p "$agent/sessions" "$agent/extensions/ext1"
  echo '{"id":"s1"}' >"$agent/sessions/s1.jsonl"
  echo 'exports = {}' >"$agent/extensions/ext1/index.js"
  session_count_before="$(find "$agent/sessions" -type f | wc -l | tr -d ' ')"

  PI_CODING_AGENT_DIR="$agent" bash "$RESET_PI" >/dev/null 2>&1
  rc=$?
  assert_eq "pi: reset exits 0" "0" "$rc"
  assert_not_exists "pi: sessions cleared" "$agent/sessions"
  assert_file "pi: extensions kept" "$agent/extensions/ext1/index.js"
  assert_eq "pi: had sessions before reset" "1" "$session_count_before"

  # CLI health: list and list-models still work with config intact.
  list_rc=0
  PI_CODING_AGENT_DIR="$agent" pi list >/dev/null 2>&1 || list_rc=$?
  assert_eq "pi: list exits 0" "0" "$list_rc"
  models_out="$(PI_CODING_AGENT_DIR="$agent" pi --list-models 2>&1)"
  assert_contains "pi: models list has providers" "$models_out" "anthropic"
fi

# ── rtk ────────────────────────────────────────────────────────────────────────
# RTK has no filesystem seam; data dir is fixed at ~/Library/Application Support/rtk/.
# We do NOT run the reset here - that would destroy production history data.
# The CI stub test already proves the script calls `rtk gain --reset --yes`
# with the right args. Here we only verify the binary is healthy and --dry-run
# is non-destructive.
if ! command -v rtk >/dev/null 2>&1; then
  skip "reset-rtk real-CLI (rtk not installed)"
else
  RESET_RTK="$REPO/scripts/reset-rtk.sh"
  RTK_DB="$HOME/Library/Application Support/rtk/history.db"

  # --dry-run must not touch the database.
  count_before="$(sqlite3 "$RTK_DB" 'SELECT COUNT(*) FROM commands;' 2>/dev/null || echo unknown)"
  out="$(bash "$RESET_RTK" --dry-run 2>&1)"; rc=$?
  count_after="$(sqlite3 "$RTK_DB" 'SELECT COUNT(*) FROM commands;' 2>/dev/null || echo unknown)"
  assert_eq "rtk: dry-run exits 0" "0" "$rc"
  assert_contains "rtk: dry-run says DRY RUN" "$out" "DRY RUN"
  assert_eq "rtk: dry-run does not modify database" "$count_before" "$count_after"

  # Binary is present and responsive.
  ver_out="$(rtk proxy rtk --version 2>&1)"
  assert_contains "rtk: binary responds" "$ver_out" "rtk"
fi
