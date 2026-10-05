#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

dry_run=0
case "${1:-}" in
  '')
    ;;
  --dry-run)
    dry_run=1
    ;;
  --help|-h)
    printf 'Usage: %s [--dry-run]\n' "${BASH_SOURCE[0]}"
    printf '  --dry-run  Preview bootstrap after ensuring mise is available\n'
    exit 0
    ;;
  *)
    printf 'Usage: %s [--dry-run]\n' "${BASH_SOURCE[0]}" >&2
    exit 2
    ;;
esac

# Reuse an existing native mise installation. This keeps repeated installs
# offline with respect to the installer itself and avoids replacing a working
# binary unnecessarily.
if [ -x "$HOME/.local/bin/mise" ]; then
  mise_bin="$HOME/.local/bin/mise"
elif mise_bin="$(command -v mise 2>/dev/null)"; then
  :
else
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
    https://mise.run | sh
  mise_bin="$HOME/.local/bin/mise"
fi

if [ ! -x "$mise_bin" ]; then
  printf 'install.sh: mise installation was not found at %s\n' "$mise_bin" >&2
  exit 1
fi

if ((dry_run)); then
  bootstrap_args=(--dry-run --yes)
else
  bootstrap_args=(--yes --prompt-secrets --force-dotfiles)
  "$mise_bin" trust "$repo/mise.toml"
fi

"$mise_bin" -C "$repo" bootstrap "${bootstrap_args[@]}"
