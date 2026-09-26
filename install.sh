#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# install.sh - first-run bootstrap of this dotfiles workstation via mise.
#
# Run from the checkout at ~/dotfiles. Install mise if absent, point it at the
# repository's machine config, trust the repo task files, and run the 8-phase
# bootstrap - tools, packages, dotfiles, macOS defaults, and the repo's own
# bootstrap task. Finally prompt for a machine-local git identity.
#
# Re-converge is mise run update (or dot run update), not this script.
# -------------------------------------------------------------------

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 2
}

# The machine config intentionally uses ~/dotfiles/home as its source root.
# Refuse another checkout location before mise can install partial state.
if [ -n "${DOTFILES_DIR:-}" ]; then
  repo="$DOTFILES_DIR"
else
  case "${BASH_SOURCE[0]}" in
    /dev/stdin|/dev/fd/*|bash|-)
      die 'install.sh must be run from a checkout at ~/dotfiles; clone the repository first'
      ;;
    *)
      repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      ;;
  esac
fi

expected_repo="$HOME/dotfiles"
[ "$repo" = "$expected_repo" ] || die "checkout must be at $expected_repo (got $repo)"

config="$repo/home/.config/mise/config.toml"
[ -f "$config" ] || die "missing machine config: $config"

# Fail before convergence when the interactive identity task cannot obtain a
# terminal. This avoids leaving a freshly bootstrapped host half-configured.
personal_identity="$HOME/.config/git/identity-personal"
work_identity="$HOME/.config/git/identity-work"
identity_input_fd=''
if [ ! -f "$personal_identity" ] || [ ! -f "$work_identity" ]; then
  if [ -t 0 ]; then
    identity_input_fd=0
  elif { exec 3</dev/tty; } 2>/dev/null; then
    identity_input_fd=3
  else
    die 'git identity setup requires an interactive terminal; run install.sh from a terminal'
  fi
fi

# Install the latest mise if absent. config.toml's min_version is the single
# source of truth for the mise floor; bootstrap enforces it once loaded.
if ! command -v mise >/dev/null 2>&1; then
  curl -fsSL https://mise.run | sh
fi
export PATH="$HOME/.local/bin:$PATH"
command -v mise >/dev/null 2>&1 || die 'mise not found after install'

# The repository keeps machine state under home/.config/mise while mise loads
# repo tasks from the root mise.toml. Make both explicit so this works after
# teardown and regardless of the caller's current directory.
export MISE_GLOBAL_CONFIG_FILE="$config"
# Trust the global machine config (it carries bootstrap hooks + templates, so
# --yes would otherwise skip it) and the repo's local mise.toml. tasks/ needs
# no separate trust: its file-tasks inherit trust via mise.toml's includes.
mise trust "$config"
mise trust "$repo/mise.toml"
mise -C "$repo" bootstrap --yes --force-dotfiles

if [ -n "$identity_input_fd" ]; then
  if [ "$identity_input_fd" = 3 ]; then
    mise -C "$repo" run setup:git-identity <&3
  else
    mise -C "$repo" run setup:git-identity
  fi
fi
