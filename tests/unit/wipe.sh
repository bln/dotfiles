#!/usr/bin/env bash
# Behavioral tests for wipe.sh: dry-run fidelity and git identity cleanup.

echo "== unit: wipe =="

WIPE="$REPO/wipe.sh"

# dry-run leaves files in place
{
  h="$(sandbox)"
  mkdir -p "$h/.config/git"
  touch "$h/.config/git/config.local" "$h/.config/git/identity-play"

  DOTFILES_DIR="$REPO" HOME="$h" bash "$WIPE" --dry-run >/dev/null 2>&1

  assert_file "dry-run: config.local preserved"  "$h/.config/git/config.local"
  assert_file "dry-run: identity-play preserved" "$h/.config/git/identity-play"
}

# dry-run output contains DRY RUN marker
{
  h="$(sandbox)"
  mkdir -p "$h/.config/git" && touch "$h/.config/git/config.local"
  out="$(DOTFILES_DIR="$REPO" HOME="$h" bash "$WIPE" --dry-run 2>&1)"
  assert_contains "dry-run: output says DRY RUN" "$out" "DRY RUN"
}

# dry-run exits 0 on an empty HOME
{
  h="$(sandbox)"
  run_capture env DOTFILES_DIR="$REPO" HOME="$h" bash "$WIPE" --dry-run
  assert_eq "dry-run on empty HOME exits 0" "0" "$RUN_STATUS"
}

# full wipe (sandbox HOME, no mise): git identity files are removed
{
  h="$(sandbox)"
  mkdir -p "$h/.config/git"
  touch "$h/.config/git/config.local" "$h/.config/git/identity-play"
  printf 'yes\n' | DOTFILES_DIR="$REPO" HOME="$h" bash "$WIPE" >/dev/null 2>&1 || true
  assert_not_exists "full wipe: config.local removed"  "$h/.config/git/config.local"
  assert_not_exists "full wipe: identity-play removed" "$h/.config/git/identity-play"
}

# unknown flag exits non-zero
{
  run_capture bash "$WIPE" --not-a-flag
  assert_ne "unknown flag: exits non-zero" "0" "$RUN_STATUS"
}
