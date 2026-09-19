#!/usr/bin/env bash
# Declarative sync of VS Code extensions against the set declared in mise
# config.toml as `vscode-ext:<id>` tool entries.
#
#   - installs declared extensions that are missing
#   - prune: extensions installed in `code` but not declared. Default WARNS only
#     (prints what would be pruned). --prune or VSCODE_EXTENSIONS_PRUNE=true actually
#     uninstalls. Opt-in so ad-hoc UI-installed extensions are not silently lost.
#   - no-op (exit 0) when `code` is absent (e.g. Linux CI).
#
# Upgrading extensions is handled by `code --update-extensions` in the update
# task; this script only installs missing ones and optionally prunes undeclared.
#
# Test seam: VSCODE_EXTENSIONS_SOURCE overrides the command that lists declared
# extension IDs (one per line). Default reads them from mise. Tests inject a
# fixed list so no live mise is required.

set -euo pipefail

REPO="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PRUNE="${VSCODE_EXTENSIONS_PRUNE:-false}"

for arg in "$@"; do
    case "$arg" in
        --prune) PRUNE=true ;;
        *) printf 'unknown argument: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

# Command that prints declared extension IDs, one per line. Overridable for tests.
# Default: strip the `vscode-ext:` prefix off the tool keys mise reports.
declared_source() {
    if [ -n "${VSCODE_EXTENSIONS_SOURCE:-}" ]; then
        eval "$VSCODE_EXTENSIONS_SOURCE"
    else
        mise -C "$REPO" ls -c --json \
            | jq -r 'keys[] | select(startswith("vscode-ext:")) | ltrimstr("vscode-ext:")'
    fi
}

command -v code >/dev/null 2>&1 || exit 0

declared="$(declared_source | tr '[:upper:]' '[:lower:]' | sort -u)"
installed="$(code --list-extensions | tr '[:upper:]' '[:lower:]' | sort -u)"

# ── install missing declared extensions ──────────────────────────────────────
while IFS= read -r ext; do
    [ -n "$ext" ] || continue
    if ! grep -Fxq "$ext" <<< "$installed"; then
        echo "Installing $ext"
        code --install-extension "$ext"
    fi
done <<< "$declared"

# ── prune installed-but-not-declared ─────────────────────────────────────────
while IFS= read -r ext; do
    [ -n "$ext" ] || continue
    if ! grep -Fxq "$ext" <<< "$declared"; then
        if [ "$PRUNE" = "true" ]; then
            echo "Pruning untracked $ext"
            code --uninstall-extension "$ext"
        else
            echo "WARNING: installed extension not declared: $ext (pass --prune to remove)" >&2
        fi
    fi
done <<< "$installed"
