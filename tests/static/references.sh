#!/usr/bin/env bash
# Static property checks: format, structure, and safety invariants.
# These assert things that must NEVER be true regardless of what you have
# configured. They do NOT check which specific packages, fonts, or themes
# you have chosen; those are content decisions, not structural ones.

echo "== static: structural properties =="

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail_count=0

ok()  { printf '  ok  %s\n' "$*"; }
bad() {
  local label="$1" detail="${2:-}"
  printf ' FAIL %s%s\n' "$label" "${detail:+: $detail}"
  fail_count=$((fail_count+1))
}

# ── 1. every tracked shell script and mise task has a shebang ─────────────
{
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    # skip non-executable text formats
    case "$f" in *.toml|*.md|*.json|*.txt|*.template|*.lock|*.ts|*.lua|*.yml|*.yaml) continue ;; esac
    first="$(head -1 "$f" 2>/dev/null)"
    case "$first" in
      '#!'*) ok "shebang: $(basename "$f")" ;;
      *)     bad "shebang" "$(basename "$f") (${f#$REPO/}) has no shebang" ;;
    esac
  done < <(find "$REPO" -type f \
    \( -path '*/scripts/*.sh' \
      -o -path '*/.mise/tasks/*' \
      -o -path '*/mise/tasks/*' \
      -o -path '*/tests/*.sh' \) \
    -not -path '*/.git/*' \
    -not -name '*.template' \
    | sort)
}

# ── 2. no private keys committed ──────────────────────────────────────────
{
  for header in \
    "BEGIN RSA PRIVATE KEY" \
    "BEGIN EC PRIVATE KEY"  \
    "BEGIN PRIVATE KEY"     \
    "BEGIN PGP PRIVATE KEY"; do

    hits="$(grep -rl "$header" "$REPO" \
      --include='*.sh' --include='*.toml' --include='*.json' \
      --include='*.lua' --include='*.yml' --include='*.yaml' \
      --include='*.md' --include='*.ts' \
      --exclude-dir='.git' --exclude-dir='tests' \
      --exclude='*.template' --exclude='*.lock' \
      2>/dev/null || true)"

    if [ -z "$hits" ]; then
      ok "no private key: $header"
    else
      bad "no private key" "$header found in: $(echo "$hits" | tr '\n' ' ')"
    fi
  done
}

# ── 3. no unfilled template placeholders in tracked non-template files ────
{
  stray=0
  while IFS= read -r f; do
    case "$f" in *.template) continue ;; esac
    [ -f "$f" ] || continue
    if grep -q '{{' "$f" 2>/dev/null; then
      bad "stray placeholder" "${f#$REPO/} contains {{ outside a .template file"
      stray=$((stray+1))
    fi
  done < <(find "$REPO" -type f \
    \( -name '*.sh' -o -name '*.json' \
      -o -name '*.lua' -o -name '*.ts' \) \
    -not -path '*/.git/*' \
    -not -path '*/tests/*' \
    | sort)
  # .toml files are excluded: mise task templates legitimately use {{config_root}},
  # {{env.HOME}}, etc. and should not be flagged as unfilled placeholders.
  # tests/ is excluded: test code contains {{ as literal patterns for assertions.
  [ "$stray" -eq 0 ] && ok "no stray template placeholders"
}

# ── 4. machine-local files that must never be committed ───────────────────
{
  for rel in \
    "home/.config/git/config.local" \
    "home/.config/git/identity-play" \
    "home/.pi/agent/models.json"     \
    "home/.pi/agent/settings.json";  do

    if [ -f "$REPO/$rel" ]; then
      bad "not committed" "$rel should be machine-local (gitignored)"
    else
      ok "not committed: $(basename "$rel")"
    fi
  done
}

# ── 5. no CRLF line endings in tracked text files ─────────────────────────
{
  crlf=0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    if grep -Pql $'\r$' "$f" 2>/dev/null; then
      bad "no CRLF" "${f#$REPO/} has Windows line endings"
      crlf=$((crlf+1))
    fi
  done < <(find "$REPO" -type f \
    \( -name '*.sh' -o -name '*.toml' -o -name '*.json' \
      -o -name '*.lua' -o -name '*.yml' -o -name '*.md' \
      -o -name '*.ts' \) \
    -not -path '*/.git/*' | sort)
  [ "$crlf" -eq 0 ] && ok "no CRLF in tracked text files"
}

# ── 6. all text files end with a trailing newline ─────────────────────────
{
  missing=0
  while IFS= read -r f; do
    [ -s "$f" ] || continue
    case "$f" in *.lock) continue ;; esac
    last_byte="$(tail -c 1 "$f" | wc -c)"
    if [ "$last_byte" -eq 0 ]; then
      bad "trailing newline" "${f#$REPO/} is missing a trailing newline"
      missing=$((missing+1))
    fi
  done < <(find "$REPO" -type f \
    \( -name '*.sh' -o -name '*.toml' -o -name '*.json' \
      -o -name '*.lua' -o -name '*.md' -o -name '*.ts' \) \
    -not -path '*/.git/*' | sort)
  [ "$missing" -eq 0 ] && ok "all text files have a trailing newline"
}

# ─────────────────────────────────────────────────────────────────────────
if [ "$fail_count" -gt 0 ]; then
  echo
  echo "== $fail_count check(s) failed =="
  exit 1
fi

echo "== all structural property checks passed =="
