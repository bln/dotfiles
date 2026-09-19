#!/usr/bin/env bash
# Teardown step 2: uninstall the VS Code extensions this repo declares.
#
# Extensions are declared as `vscode-ext:<id>` tool entries in mise config; the
# no-op backend plugin can't uninstall, so we drive `code` directly - deriving
# the id list the same way apply-vscode-extensions.sh does.
#
# Safe by default: without --apply (or APPLY=true) it dry-runs. No-op (exit 0)
# when code or jq is absent (e.g. Linux CI).
#
# Test seam: VSCODE_EXTENSIONS_SOURCE overrides the command that lists declared
# extension IDs (one per line). Default reads them from mise.
set -euo pipefail

REPO="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
APPLY="${APPLY:-false}"
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    *) printf 'unknown argument: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

# Command that prints declared extension IDs, one per line. Overridable for tests.
declared_source() {
  if [ -n "${VSCODE_EXTENSIONS_SOURCE:-}" ]; then
    eval "$VSCODE_EXTENSIONS_SOURCE"
  else
    mise -C "$REPO" ls -c --json \
      | jq -r 'keys[] | select(startswith("vscode-ext:")) | ltrimstr("vscode-ext:")'
  fi
}

command -v code >/dev/null 2>&1 || { printf 'WARNING: code not found; skipping extension removal\n' >&2; exit 0; }
if [ -z "${VSCODE_EXTENSIONS_SOURCE:-}" ] && ! command -v jq >/dev/null 2>&1; then
  printf 'WARNING: jq not found; skipping extension removal\n' >&2
  exit 0
fi

while IFS= read -r ext; do
  [ -n "$ext" ] || continue
  if [ "$APPLY" = true ]; then
    code --uninstall-extension "$ext" 2>/dev/null || true
  else
    printf '  DRY RUN: would uninstall extension %s\n' "$ext"
  fi
done < <(declared_source)
