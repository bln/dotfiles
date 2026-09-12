#!/usr/bin/env bash
# Destructively remove this dotfiles-managed machine state, then print rebuild steps.
set -euo pipefail

REPO="${DOTFILES_DIR:-$HOME/dotfiles}"
BREWFILE="$REPO/home/.config/homebrew/Brewfile"
DRY_RUN=false

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
warn() { printf "WARNING: %s\n" "$1" >&2; }
die() { printf "ERROR: %s\n" "$1" >&2; exit 1; }

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
echo "  - mise-managed dotfile symlinks when mise is available"
echo "  - Brewfile-managed Homebrew formulae, casks, and VSCode extensions"
echo "  - Brewfile-managed Mac App Store apps (needs sudo)"
echo "  - mise-managed tools, runtimes, mise itself, and uv cache state"
echo
echo "Does NOT revert macOS system defaults (dock/finder/keyboard) written at"
echo "install - defaults write records no prior value, so there is nothing to"
echo "restore. Also leaves Homebrew itself installed."
echo
if [ "$DRY_RUN" != true ]; then
  read -r -p "Proceed with wipe? [type 'yes' to proceed]: " ans
  [ "$ans" = "yes" ] || { echo "Aborted."; exit 1; }
fi

bold "== 1/4: remove machine-local git identity =="
for path in \
  "$HOME/.config/git/config.local" \
  "$HOME/.config/git/identity-play"
do
  if [ "$DRY_RUN" = true ]; then
    printf 'DRY RUN: rm -rf %q\n' "$path"
  elif [ -e "$path" ] || [ -L "$path" ]; then
    rm -rf "$path"
    printf '  removed: %s\n' "$path"
  fi
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
fi

bold "== 3/4: remove mise packages and residual VS Code extensions =="
if command -v mise >/dev/null 2>&1; then
  if [ "$DRY_RUN" = true ]; then
    mise bootstrap packages unapply --dry-run --yes || true
  else
    mise bootstrap packages unapply --yes || true
  fi
else
  warn "mise not found; skipping native package cleanup"
fi

if command -v brew >/dev/null 2>&1 && [ -f "$BREWFILE" ]; then
  extensions=()
  while IFS= read -r extension; do
    [ -n "$extension" ] && extensions+=("$extension")
  done < <(brew bundle list --file "$BREWFILE" --vscode 2>/dev/null || true)
  for extension in "${extensions[@]}"; do
    if [ "$DRY_RUN" = true ]; then
      printf 'DRY RUN: code --uninstall-extension %q\n' "$extension"
    elif command -v code >/dev/null 2>&1; then
      code --uninstall-extension "$extension" || true
    fi
  done
else
  warn "brew or residual Brewfile not found; skipping VS Code extension cleanup"
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
fi

for path in \
  "$HOME/.local/share/uv" \
  "$HOME/.cache/uv"
do
  if [ "$DRY_RUN" = true ]; then
    printf 'DRY RUN: rm -rf %q\n' "$path"
  elif [ -e "$path" ] || [ -L "$path" ]; then
    rm -rf "$path"
    printf '  removed: %s\n' "$path"
  fi
done

echo
bold "== WIPE COMPLETE =="
echo "Next: open a fresh terminal and run:"
echo "  $REPO/install.sh"
echo "  exec zsh -l"
echo "  mise -C $REPO verify"
