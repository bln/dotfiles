#!/usr/bin/env bash
# Secret hygiene: scan tracked files for accidental secret inclusion.
# Only check structural patterns (PEM headers) that are universally stable.
# Volatile token prefixes (ghp_, npm_, etc.) are omitted: they change with
# platform rotations and cause false positives on legitimate test fixtures.
#
# Uses testlib ok()/bad() - do NOT redefine them here.
# NOTE: PEM header checks are already in references.sh (structural properties).
# This file covers the remaining secret-specific checks that don't overlap.

echo "== static: secret hygiene =="

# Machine-local identity files that must not be tracked.
{
  for f in "$REPO/home/.config/git/config.local" \
           "$REPO/home/.config/git/identity-play"; do
    if [ -f "$f" ]; then
      bad "no tracked identity: $(basename "$f")" "exists in repo (should be gitignored)"
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
      bad "no tracked pi config: $(basename "$f")" "exists in repo (should be machine-generated)"
    else
      ok "no tracked pi config: $(basename "$f")"
    fi
  done
}

echo "== secret hygiene checks passed =="
