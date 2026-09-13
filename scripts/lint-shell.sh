#!/usr/bin/env bash
# Lint all shell scripts in the repository: syntax check (bash -n) and
# ShellCheck (when available). Bash 3.2 safe (no mapfile).
#
# Script collection strategy:
#   - Top-level *.sh and scripts/*.sh: matched by extension.
#   - mise file-tasks under home/.config/mise/tasks and .mise/tasks: matched
#     by shebang (they have no .sh extension).
#   - Excludes .d/ template dirs (JSON/gitconfig, not shell).
set -euo pipefail

REPO="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

scripts=()
while IFS= read -r f; do
  scripts+=("$f")
done < <(
  {
    find "$REPO" -maxdepth 1 -type f -name '*.sh' -not -path '*/.git/*'
    find "$REPO/scripts" -type f -name '*.sh' -not -path '*/.git/*' 2>/dev/null || true
    find "$REPO/home/.config/mise/tasks" "$REPO/.mise/tasks" -type f -not -path '*/*.d/*' \
      -exec sh -c 'head -1 "$1" | grep -q "^#!.*sh"' _ {} \; -print 2>/dev/null || true
  } | sort -u
)

[ "${#scripts[@]}" -gt 0 ] || { echo "no shell scripts found" >&2; exit 1; }

echo "==> bash -n (syntax) on ${#scripts[@]} scripts"
bash -n "${scripts[@]}"

if command -v shellcheck >/dev/null 2>&1; then
  echo "==> shellcheck"
  shellcheck "${scripts[@]}"
else
  echo "WARNING: shellcheck not installed; skipped (CI enforces it)" >&2
fi

echo "OK: lint passed."
