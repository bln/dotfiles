#!/usr/bin/env bash
# Secret hygiene: scan tracked files for accidental secret inclusion.

echo "== static: secret hygiene =="

# Patterns that should never appear in tracked files.
# Each pattern is checked against all files except templates and lock files.
fail_count=0

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

# Private key headers
check_pattern "no RSA private keys" "BEGIN RSA PRIVATE KEY"
check_pattern "no EC private keys" "BEGIN EC PRIVATE KEY"
check_pattern "no generic private keys" "BEGIN PRIVATE KEY"
check_pattern "no PGP private keys" "BEGIN PGP PRIVATE KEY"

# Common token prefixes (outside templates)
check_pattern "no GitHub tokens" "ghp_[A-Za-z0-9]"
check_pattern "no npm tokens" "npm_[A-Za-z0-9]"

# Generated identity files should not be tracked
{
  for f in "$REPO/home/.config/git/config.local" \
           "$REPO/home/.config/git/identity-play"; do
    if [ -f "$f" ]; then
      bad "no tracked identity: $(basename "$f")" "$f exists in repo (should be gitignored)"
    else
      ok "no tracked identity: $(basename "$f")"
    fi
  done
}

# Generated pi config should not be tracked
{
  for f in "$REPO/home/.pi/agent/models.json" \
           "$REPO/home/.pi/agent/settings.json"; do
    if [ -f "$f" ]; then
      bad "no tracked pi config: $(basename "$f")" "$f exists in repo (should be generated, not committed)"
    else
      ok "no tracked pi config: $(basename "$f")"
    fi
  done
}
