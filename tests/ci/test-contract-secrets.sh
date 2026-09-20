#!/usr/bin/env bash
# ci: no machine-local identity or credential material is committed.
#
# A safety guard, not a restatement: it reads what git ACTUALLY tracks
# (git ls-files) and what .gitignore ACTUALLY covers (check-ignore --no-index),
# so it proves the real repo state, not that a config line exists. Loss here is
# a leaked secret, so this stays even though it is "obvious".

echo "== ci: secret hygiene =="

tracked() { (cd "$REPO" && git ls-files 2>/dev/null); }

# Machine-local git identity must never be committed.
for rel in "home/.config/git/identity-personal" "home/.config/git/identity-work"; do
  if tracked | grep -Fxq "$rel"; then
    bad "not tracked: $(basename "$rel")" "$rel is committed (must be machine-local)"
  else
    ok "not tracked: $(basename "$rel")"
  fi
done

# Agent credential/state roots must be ignored (checked with --no-index so the
# rule is proven even before such a file exists live). One representative per
# agent - the point is the ignore rule works, not to enumerate every path.
for rel in \
  "home/.config/pi/agent/auth.json" \
  "home/.config/codex/auth.json" \
  "home/.config/claude/.claude.json"; do
  if git -C "$REPO" check-ignore --no-index -q "$rel"; then
    ok "ignored agent credential: $rel"
  else
    bad "ignored agent credential: $rel" "$rel is not covered by .gitignore"
  fi
done

# No PEM private-key material in any tracked file.
leak=0
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  case "$rel" in tests/*) continue ;; esac   # tests may mention the pattern
  [ -f "$REPO/$rel" ] || continue
  if grep -q 'BEGIN [A-Z ]*PRIVATE KEY' "$REPO/$rel" 2>/dev/null; then
    bad "no private key in tracked files" "PEM header in $rel"
    leak=$((leak + 1))
  fi
done < <(tracked)
[ "$leak" -eq 0 ] && ok "no PEM private-key material in tracked files"
