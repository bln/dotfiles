#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ${1:-} != --yes ]]; then
  printf 'Usage: %s --yes\n' "$0" >&2
  exit 2
fi

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
mise_bin="$HOME/.local/bin/mise"

if [[ ! -x "$mise_bin" ]]; then
  mise_bin="$(command -v mise 2>/dev/null || true)"
fi

if [[ -z "$mise_bin" ]]; then
  printf 'uninstall.sh: mise is not available on PATH or at ~/.local/bin/mise\n' >&2
  exit 1
fi

empty_dir="$(mktemp -d)"
trap 'rmdir "$empty_dir" 2>/dev/null || true' EXIT

"$mise_bin" -C "$repo" bootstrap dotfiles unapply --force --yes
"$mise_bin" untrust "$repo/mise.toml" || true
"$mise_bin" -C "$empty_dir" bootstrap packages prune --manager brew --yes
"$mise_bin" -C "$empty_dir" bootstrap packages prune --manager brew-cask --yes
"$mise_bin" -C "$empty_dir" uninstall --all --yes
"$mise_bin" implode --config --yes

printf 'Mise resources removed; repository remains at: %s\n' "$repo"
