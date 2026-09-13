#!/usr/bin/env bash
# Destructively remove this dotfiles-managed machine state, then print rebuild steps.
set -euo pipefail

REPO="${DOTFILES_DIR:-$HOME/dotfiles}"
DRY_RUN=false

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
warn() { printf "WARNING: %s\n" "$1" >&2; }
die()  { printf "ERROR: %s\n" "$1" >&2; exit 1; }

# Guard: refuse to rm -rf anything that is not strictly under $HOME.
safe_under_home() {
  local path="$1"
  [ -n "$path" ] && [ "$path" != "/" ] && [ "$path" != "$HOME" ] && \
    case "$path" in "$HOME/"*) return 0 ;; esac
  return 1
}

# Safe removal: checks path is under HOME before deleting.
safe_remove() {
  local path="$1"
  if ! safe_under_home "$path"; then
    warn "refusing to remove path outside HOME: $path"
    return 1
  fi
  if [ "$DRY_RUN" = true ]; then
    printf 'DRY RUN: rm -rf %q\n' "$path"
  elif [ -e "$path" ] || [ -L "$path" ]; then
    rm -rf "$path"
    printf '  removed: %s\n' "$path"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=true ;;
    -h|--help)
      cat <<'EOF'
Usage: ~/dotfiles/wipe.sh [--dry-run]

Destructively remove the state installed by this dotfiles repo.
EOF
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

bold "== This will PERMANENTLY remove: =="
echo "  - machine-local git identity files"
echo "  - mise-managed dotfile symlinks"
echo "  - mise-managed packages (formulae, casks, and Mac App Store apps)"
echo "  - declared VS Code extensions"
echo "  - mise-managed tools, runtimes, mise itself, and uv cache state"
echo
echo "Does NOT revert macOS system defaults (dock/finder/keyboard) written at"
echo "install - defaults write records no prior value, so there is nothing to restore"
echo
if [ "$DRY_RUN" != true ]; then
  read -r -p "Proceed with wipe? [type 'yes' to proceed]: " ans
  [ "$ans" = "yes" ] || { echo "Aborted."; exit 1; }
fi

removed=0
skipped=0

bold "== 1/4: remove machine-local git identity =="
for path in \
  "$HOME/.config/git/config.local" \
  "$HOME/.config/git/identity-play"
do
  safe_remove "$path" && removed=$((removed + 1)) || skipped=$((skipped + 1))
done

bold "== 2/4: unapply mise-managed dotfiles =="
export PATH="$HOME/.local/bin:$PATH"
if command -v mise >/dev/null 2>&1; then
  if [ "$DRY_RUN" = true ]; then
    mise bootstrap dotfiles unapply --dry-run --yes
  else
    mise bootstrap dotfiles unapply --yes
  fi
else
  warn "mise not found; skipping dotfiles unapply"
  skipped=$((skipped + 1))
fi

bold "== 3/4: remove VS Code extensions and Homebrew =="
# VS Code extensions must go first: 'code' is a brew cask and will be gone
# once Homebrew is uninstalled.
extensions_manifest="$REPO/home/.config/vscode/extensions.txt"
if command -v code >/dev/null 2>&1 && [ -f "$extensions_manifest" ]; then
  while IFS= read -r line; do
    line="${line%%#*}"     # strip comments
    line="${line// /}"    # strip spaces
    [ -n "$line" ] || continue
    if [ "$DRY_RUN" = true ]; then
      printf 'DRY RUN: code --uninstall-extension %s\n' "$line"
    else
      code --uninstall-extension "$line" 2>/dev/null || true
    fi
  done < "$extensions_manifest"
else
  warn "code not found or extensions manifest missing; skipping VS Code extension cleanup"
  skipped=$((skipped + 1))
fi

# Homebrew's own uninstall script removes all formulae, casks, and the brew
# binary in the correct dependency order.
if command -v brew >/dev/null 2>&1; then
  if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN: would uninstall all Homebrew packages and Homebrew itself"
  else
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" \
      -- --force || warn "Homebrew uninstall reported failures; some packages may remain"
  fi
else
  warn "brew not found; skipping Homebrew removal"
  skipped=$((skipped + 1))
fi

bold "== 4/4: remove mise tools, mise, and uv state =="
if command -v mise >/dev/null 2>&1; then
  if [ "$DRY_RUN" = true ]; then
    mise uninstall --all --dry-run || true
    mise implode --dry-run --config || true
  else
    mise uninstall --all --yes || true
    mise implode --yes --config || true
  fi
else
  warn "mise not found; skipping mise cleanup"
  skipped=$((skipped + 1))
fi

for path in \
  "$HOME/.local/share/uv" \
  "$HOME/.cache/uv"
do
  safe_remove "$path" && removed=$((removed + 1)) || skipped=$((skipped + 1))
done

echo
bold "== WIPE COMPLETE =="
echo "  $removed items removed, $skipped items skipped/warned"

  if [ "$DRY_RUN" = true ]; then
    echo "Next: run the wipe if dry-run previewed expected behavior:"
  else
    echo "Next: open a fresh terminal and run:"
    echo "  $REPO/install.sh"
    echo "  exec zsh -l"
    echo "  mise -C $REPO verify"
  fi
