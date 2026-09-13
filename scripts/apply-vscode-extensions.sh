#!/usr/bin/env bash
# Install declared VS Code extensions, skipping those already present.
# Reads a plain-text manifest (one extension ID per line, # comments allowed).
#
# Usage:
#   scripts/apply-vscode-extensions.sh                   # install missing
#   scripts/apply-vscode-extensions.sh --dry-run          # show what would install
#   scripts/apply-vscode-extensions.sh --prune            # also remove undeclared
#   scripts/apply-vscode-extensions.sh --prune --dry-run  # show prune plan
set -euo pipefail

REPO="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST="${VSCODE_EXTENSIONS_MANIFEST:-$REPO/home/.config/vscode/extensions.txt}"

dry_run=false
prune=false

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) dry_run=true ;;
    --prune) prune=true ;;
    -h|--help)
      echo "usage: apply-vscode-extensions.sh [--dry-run] [--prune]" >&2
      echo "  Installs missing VS Code extensions from extensions.txt." >&2
      echo "  --prune removes extensions not in the manifest." >&2
      exit 0
      ;;
    *) echo "ERROR: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if ! command -v code >/dev/null 2>&1; then
  echo "WARNING: code not found; skipping VS Code extension management" >&2
  exit 0
fi

[ -f "$MANIFEST" ] || { echo "ERROR: manifest not found: $MANIFEST" >&2; exit 1; }

# Load declared extension IDs (lowercase for case-insensitive comparison)
declared=()
while IFS= read -r line; do
  line="${line%%#*}"           # strip comments
  line="${line// /}"           # strip whitespace
  [ -n "$line" ] || continue
  declared+=("$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')")
done < "$MANIFEST"

# Load installed extensions (lowercase)
installed=()
while IFS= read -r ext; do
  [ -n "$ext" ] && installed+=("$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')")
done < <(code --list-extensions 2>/dev/null || true)

# Install missing
install_count=0
for ext in "${declared[@]}"; do
  found=false
  for inst in "${installed[@]}"; do
    [ "$ext" = "$inst" ] && { found=true; break; }
  done
  if [ "$found" = false ]; then
    if [ "$dry_run" = true ]; then
      printf 'DRY RUN: code --install-extension %s\n' "$ext"
    else
      code --install-extension "$ext" --force 2>/dev/null || true
    fi
    install_count=$((install_count + 1))
  fi
done

# Prune undeclared (only with --prune)
prune_count=0
if [ "$prune" = true ]; then
  for inst in "${installed[@]}"; do
    found=false
    for ext in "${declared[@]}"; do
      [ "$inst" = "$ext" ] && { found=true; break; }
    done
    if [ "$found" = false ]; then
      if [ "$dry_run" = true ]; then
        printf 'DRY RUN: code --uninstall-extension %s\n' "$inst"
      else
        code --uninstall-extension "$inst" 2>/dev/null || true
      fi
      prune_count=$((prune_count + 1))
    fi
  done
fi

echo "VS Code extensions: $install_count to install, $prune_count to prune (${#installed[@]} installed, ${#declared[@]} declared)"
