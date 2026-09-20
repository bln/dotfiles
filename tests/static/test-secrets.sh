#!/usr/bin/env bash
# Secret hygiene: no machine-local identity or private key material is tracked.
# Uses `git ls-files` so the check reflects what is actually committed.

echo "== static: secret hygiene =="

tracked() { (cd "$REPO" && git ls-files 2>/dev/null); }

# Machine-local identity must never be tracked.
{
  for rel in \
    "home/.config/git/identity-personal" \
    "home/.config/git/identity-work"; do
    if tracked | grep -Fxq "$rel"; then
      bad "not tracked: $(basename "$rel")" "$rel is committed (should be machine-local)"
    else
      ok "not tracked: $(basename "$rel")"
    fi
  done
}

# Agent state roots are intentionally live-only. The paths are checked with
# --no-index so the assertion proves the ignore rules even before a file exists.
{
  for rel in \
    "home/.config/pi/agent/auth.json" \
    "home/.config/pi/agent/settings.json" \
    "home/.config/pi/auth.json" \
    "home/.config/codex/config.toml" \
    "home/.config/codex/auth.json" \
    "home/.config/claude/.claude.json" \
    "home/.config/claude/settings.json"; do
    if git -C "$REPO" check-ignore --no-index -q "$rel"; then
      ok "ignored agent state: $rel"
    else
      bad "ignored agent state: $rel" "$rel is not covered by .gitignore"
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
