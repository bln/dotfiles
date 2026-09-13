#!/usr/bin/env bash

set -euo pipefail

REPO="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST="${VSCODE_EXTENSIONS_MANIFEST:-$REPO/home/.config/vscode/extensions.txt}"

command -v code >/dev/null 2>&1 || exit 0
[ -f "$MANIFEST" ] || exit 1

installed="$(code --list-extensions | tr '[:upper:]' '[:lower:]')"

while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"

    [ -n "$line" ] || continue

    if ! grep -Fxq "$line" <<< "$installed"; then
        echo "Installing $line"
        code --install-extension "$line" --force
    fi
done < "$MANIFEST"
