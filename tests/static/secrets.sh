#!/usr/bin/env bash
# Secret hygiene: scan tracked files for accidental secret inclusion.
# Only check structural patterns (PEM headers) that are universally stable.
# Volatile token prefixes (ghp_, npm_, etc.) are omitted: they change with
# platform rotations and cause false positives on legitimate test fixtures.

echo "== static: secret hygiene =="

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail_count=0

ok()  { printf '  ok  %s\n' "$*"; }
bad() {
  local label="$1" detail="${2:-}"
  printf ' FAIL %s%s\n' "$label" "${detail:+: $detail}"
  fail_count=$((fail_count+1))
}

check_pattern() {
  local label="$1" pattern="$2"
  local matches
  matches="$(grep -rl "$pattern" "$REPO" \
    --include='*.sh' --include='*.toml' --include='*.json' --include='*.lua' \
    --include='*.yml' --include='*.yaml' --include='*.md' --include='*.ts' \
    --exclude-dir='.git' --exclude-dir='tests' \
    --exclude='*.template' --exclude='*.lock' \
    2>/dev/null || true)"
  if [ -z "$matches" ]; then
    ok "$label"
  else
    bad "$label" "found in: $(echo "$matches" | tr '\n' ' ')"
    fail_count=$((fail_count + 1))
  fi
}

# PEM headers — universally stable markers of committed private key material.
check_pattern "no RSA private keys"     "BEGIN RSA PRIVATE KEY"
check_pattern "no EC private keys"      "BEGIN EC PRIVATE KEY"
check_pattern "no generic private keys" "BEGIN PRIVATE KEY"
check_pattern "no PGP private keys"     "BEGIN PGP PRIVATE KEY"

# Machine-local identity files that must not be tracked.
{
  for f in "$REPO/home/.config/git/config.local" \
           "$REPO/home/.config/git/identity-play"; do
    if [ -f "$f" ]; then
      bad "no tracked identity" "$(basename "$f") exists in repo (should be gitignored)"
    else
      ok "no tracked identity: $(basename "$f")"
    fi
  done
}

# Generated pi config files that must not be tracked.
{
  for f in "$REPO/home/.pi/agent/models.json" \
           "$REPO/home/.pi/agent/settings.json"; do
    if [ -f "$f" ]; then
      bad "no tracked pi config" "$(basename "$f") exists in repo (should be machine-generated)"
    else
      ok "no tracked pi config: $(basename "$f")"
    fi
  done
}

if [ "$fail_count" -gt 0 ]; then
  echo
  echo "== $fail_count check(s) failed =="
  exit 1
fi

echo "== secret hygiene checks passed =="
