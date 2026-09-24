#!/usr/bin/env bash
# shellcheck disable=SC2154 # pass/fail counters come from the sourced testlib.sh
# maint: live spike proving the RTK -> Codex native PreToolUse hook actually
# rewrites commands, and recording how Codex's hook-trust model behaves
# non-interactively. This needs a real rtk >= 0.50.0 and (for the end-to-end
# leg) an installed, authenticated Codex, so it lives in the maint tier: run by
# hand, never gated by `mise run test`/`verify`/CI. Named *.test.sh so no stray
# glob pulls it into the suite; self-contained (own REPO + summary + exit).
#
# Run it directly:  bash tests/maint/rtk-codex-hook.test.sh
#
# What it proves:
#   1. `rtk init -g --codex` writes a $CODEX_HOME/hooks.json with a Bash
#      PreToolUse entry that invokes `rtk hook codex`.
#   2. The hook binary rewrites a real Codex PreToolUse payload: a filtered
#      command comes back as `updatedInput.command` with permissionDecision
#      "allow"; an unfiltered command fails open (no stdout).
#   3. TRUST: whether `codex exec` runs the registered hook. Observed on codex
#      0.156.1: a user-layer hooks.json hook is Untrusted until reviewed, and
#      `codex exec` has no trust-review UI, so the hook is SILENTLY SKIPPED
#      unless `--dangerously-bypass-hook-trust` is passed. This leg passes that
#      flag, asks Codex to run a filtered command, and confirms the rewrite
#      lands (`rtk git status`). Skips cleanly when Codex is absent/unauthed.
#
# Seams: CODEX_HOME points at a sandbox (the no-override default is production);
# RTK_TELEMETRY_DISABLED is forced so init never prompts.
set -euo pipefail

REPO="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export REPO
# shellcheck source=tests/lib/testlib.sh
source "$REPO/tests/lib/testlib.sh"

export RTK_TELEMETRY_DISABLED="${RTK_TELEMETRY_DISABLED:-1}"

echo "== maint: rtk codex hook =="

# A live rtk >= 0.50.0 with the Codex hook is required; skip cleanly otherwise.
if ! command -v rtk >/dev/null 2>&1; then
  skip "rtk not installed"
elif ! rtk hook codex --help >/dev/null 2>&1; then
  skip "rtk lacks the Codex hook (needs >= 0.50.0)"
else

# A real Codex PreToolUse envelope. `permission_mode` is required: Codex sends
# it on every hook event and the hook fails open without a supported mode.
codex_payload() {
  local cmd="$1"
  printf '{"session_id":"s1","turn_id":"t1","hook_event_name":"PreToolUse","tool_name":"Bash","tool_use_id":"tu1","tool_input":{"command":%s},"permission_mode":"default"}' \
    "$(printf '%s' "$cmd" | sed 's/\\/\\\\/g; s/"/\\"/g; s/^/"/; s/$/"/')"
}

# ── 1. init registers the hook ────────────────────────────────────────────────
{
  ch="$(sandbox)"
  printf '# shared body\n' > "$ch/AGENTS.md"
  run_capture env CODEX_HOME="$ch" rtk init -g --codex
  assert_eq "rtk init --codex exits 0" "0" "$RUN_STATUS"
  assert_file "hooks.json created" "$ch/hooks.json"
  hooks="$(cat "$ch/hooks.json")"
  assert_contains "hooks.json has a Bash matcher" "$hooks" "Bash"
  assert_contains "hooks.json invokes rtk hook codex" "$hooks" "rtk hook codex"
}

# ── 2. the hook rewrites a real payload ───────────────────────────────────────
{
  # A filtered command (git) is rewritten with allow + updatedInput.
  out="$(codex_payload "git status" | rtk hook codex)"
  assert_contains "filtered cmd -> updatedInput" "$out" "updatedInput"
  assert_contains "filtered cmd -> rewritten to rtk" "$out" "rtk git status"
  assert_contains "filtered cmd -> permissionDecision allow" "$out" "allow"

  # An unfiltered command fails open: exit 0, no stdout, original runs as-is.
  run_capture rtk hook codex <<<"$(codex_payload "echo hi")"
  assert_eq "unfiltered cmd exits 0" "0" "$RUN_STATUS"
  assert_eq "unfiltered cmd emits no rewrite" "" "$(cat "$RUN_STDOUT")"

  # rtk's own dry-run cross-check.
  run_capture rtk hook check --agent codex git status
  assert_contains "hook check confirms rewrite" "$(cat "$RUN_STDOUT")" "rtk git status"
}

# ── 3. TRUST behavior (informational, needs live authenticated Codex) ─────────
if ! command -v codex >/dev/null 2>&1; then
  skip "codex not installed (trust leg)"
else
  ch="$(sandbox)"
  cp "$HOME/.config/codex/auth.json" "$ch/auth.json" 2>/dev/null || true
  : > "$ch/config.toml"
  env CODEX_HOME="$ch" rtk init -g --codex >/dev/null 2>&1
  # A user-layer hook is Untrusted and `codex exec` has no review UI, so the hook
  # only runs with --dangerously-bypass-hook-trust. Ask Codex to run a filtered
  # command and confirm the rewrite lands. Kill after a bounded wait (no
  # `timeout` on macOS BSD).
  log="$ch/exec.log"
  ( printf 'Use your shell tool to run exactly: git status\n' \
      | env CODEX_HOME="$ch" codex exec --skip-git-repo-check --dangerously-bypass-hook-trust \
      >"$log" 2>&1 & p=$!; sleep 50; kill "$p" 2>/dev/null || true )
  body="$(cat "$log" 2>/dev/null || true)"
  if printf '%s' "$body" | grep -qiE '401 Unauthorized|not.*(logged|authenticated)'; then
    skip "codex unauthenticated in sandbox (trust leg inconclusive)"
  elif printf '%s' "$body" | grep -qiE 'rtk git status'; then
    ok "OBSERVED: codex exec ran the hook and rewrote git status -> rtk git status (bypass flag)"
  else
    skip "trust leg indeterminate; inspect $log by hand"
    printf '       -> tail of codex exec output:\n'; printf '%s\n' "$body" | tail -5 | sed 's/^/          /'
  fi
fi

fi  # end: rtk present with Codex hook

echo
echo "== summary: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
