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

bold "== 3/4: remove Brewfile-managed Homebrew and Mac App Store state =="
if command -v brew >/dev/null 2>&1; then
  if [ -f "$BREWFILE" ]; then
    vscode_extensions=()
    while IFS= read -r extension; do
      [ -n "$extension" ] && vscode_extensions+=("$extension")
    done < <(brew bundle list --file "$BREWFILE" --vscode 2>/dev/null || true)
    if [ "${#vscode_extensions[@]}" -gt 0 ]; then
      if command -v code >/dev/null 2>&1; then
        for extension in "${vscode_extensions[@]}"; do
          if [ "$DRY_RUN" = true ]; then
            printf 'DRY RUN: code --uninstall-extension %q\n' "$extension"
          else
            code --uninstall-extension "$extension" || true
          fi
        done
      else
        warn "code not found; skipping VSCode extension cleanup"
      fi
    fi

    # Mac App Store apps. brew bundle list --mas prints names, but `mas
    # uninstall` needs numeric IDs, so read them straight from the Brewfile's
    # `mas "...", id: NNNN` lines. Uninstalling MAS apps needs root (mas moves
    # the bundle to the Trash via sudo).
    mas_ids=()
    while IFS= read -r mas_id; do
      [ -n "$mas_id" ] && mas_ids+=("$mas_id")
    done < <(sed -nE 's/^[[:space:]]*mas[[:space:]].*id:[[:space:]]*([0-9]+).*/\1/p' "$BREWFILE")
    if [ "${#mas_ids[@]}" -gt 0 ]; then
      if command -v mas >/dev/null 2>&1; then
        for mas_id in "${mas_ids[@]}"; do
          if [ "$DRY_RUN" = true ]; then
            printf 'DRY RUN: sudo mas uninstall %q\n' "$mas_id"
          else
            sudo mas uninstall "$mas_id" || warn "mas uninstall $mas_id failed (already gone?)"
          fi
        done
      else
        warn "mas not found; skipping Mac App Store app cleanup"
      fi
    fi

    casks=()
    while IFS= read -r cask; do
      [ -n "$cask" ] && casks+=("$cask")
    done < <(brew bundle list --file "$BREWFILE" --cask 2>/dev/null || true)
    if [ "${#casks[@]}" -gt 0 ]; then
      if [ "$DRY_RUN" = true ]; then
        printf 'DRY RUN: brew uninstall --cask --force'
        printf ' %q' "${casks[@]}"
        printf '\n'
      else
        brew uninstall --cask --force "${casks[@]}"
      fi
    fi

    formulae=()
    while IFS= read -r formula; do
      [ -n "$formula" ] && formulae+=("$formula")
    done < <(brew bundle list --file "$BREWFILE" --formula 2>/dev/null || true)
    if [ "${#formulae[@]}" -gt 0 ]; then
      if [ "$DRY_RUN" = true ]; then
        printf 'DRY RUN: brew uninstall --formula --force'
        printf ' %q' "${formulae[@]}"
        printf '\n'
      else
        brew uninstall --formula --force "${formulae[@]}" 2>/dev/null || true
      fi
    fi

    if [ "$DRY_RUN" = true ]; then
      echo "DRY RUN: brew autoremove"
    else
      brew autoremove || true
    fi
  else
    warn "$BREWFILE not found; skipping Homebrew cleanup"
  fi
else
  warn "brew not found; skipping Homebrew cleanup"
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
