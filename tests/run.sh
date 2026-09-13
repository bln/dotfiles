#!/usr/bin/env bash
# Test harness for this repo's parameterized shell scripts.
#
# Plain bash (no bats/framework, per AGENTS.md). Each test exercises the REAL
# shipped script - never a copy - by pointing its documented override seam at a
# mktemp sandbox: git-identity via $HOME, pi-config via $PI_AGENT_DIR,
# reset-codex via $CODEX_HOME. This is the pattern AGENTS.md "Script testability"
# prescribes.
#
# Test suites live under tests/unit/, tests/static/, and tests/integration/.
# Each is sourced into this process so it shares the test library and counters.
set -euo pipefail

REPO="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export REPO

# ── load test library ─────────────────────────────────────────────────────────
# shellcheck source=lib/testlib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/testlib.sh"

# ── unit tests (shipped scripts via seams) ────────────────────────────────────
for f in "$(dirname "${BASH_SOURCE[0]}")"/unit/*.sh; do
  [ -f "$f" ] && source "$f"
done

# ── static checks (config formats, cross-file references, secret hygiene) ─────
for f in "$(dirname "${BASH_SOURCE[0]}")"/static/*.sh; do
  [ -f "$f" ] && source "$f"
done

# ── summary ───────────────────────────────────────────────────────────────────
echo
echo "== summary: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
