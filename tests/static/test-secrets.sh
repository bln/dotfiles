#!/usr/bin/env bash
# Secret hygiene: no machine-local identity or private key material is tracked.
# Uses `git ls-files` so the check reflects what is actually committed.

echo "== static: secret hygiene =="

tracked() { (cd "$REPO" && git ls-files 2>/dev/null); }

# Machine-local identity must never be tracked.
{
  for rel in \
    "home/.config/git/config.local" \
    "home/.config/git/identity-play"; do
    if tracked | grep -Fxq "$rel"; then
      bad "not tracked: $(basename "$rel")" "$rel is committed (should be machine-local)"
    else
      ok "not tracked: $(basename "$rel")"
    fi
  done
}

# No PEM private-key material in any tracked file.
{
  leak=0
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    case "$rel" in tests/*) continue ;; esac   # tests may mention the pattern
    [ -f "$REPO/$rel" ] || continue
    if grep -q 'BEGIN [A-Z ]*PRIVATE KEY' "$REPO/$rel" 2>/dev/null; then
      bad "no private key in tracked files" "PEM private-key header in $rel"
      leak=$((leak + 1))
    fi
  done < <(tracked)
  [ "$leak" -eq 0 ] && ok "no PEM private-key material in tracked files"
}
