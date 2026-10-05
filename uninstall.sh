#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

dry_run=0
case "${1:-}" in
  --dry-run)
    dry_run=1
    ;;
  --yes)
    ;;
  --help|-h)
    printf 'Usage: %s [--dry-run|--yes]\n' "${BASH_SOURCE[0]}"
    printf '  --dry-run  Preview removal without changing the machine\n'
    printf '  --yes      Confirm the destructive teardown\n'
    exit 0
    ;;
  *)
    printf 'Refusing destructive teardown without explicit --yes.\n' >&2
    printf 'Run %s --dry-run to preview or %s --yes to proceed.\n' "${BASH_SOURCE[0]}" "${BASH_SOURCE[0]}" >&2
    exit 2
    ;;
esac

if (($# > 1)); then
  printf 'Usage: %s [--dry-run|--yes]\n' "${BASH_SOURCE[0]}" >&2
  exit 2
fi

if mise_bin="$(command -v mise 2>/dev/null)"; then
  :
elif [ -x "$HOME/.local/bin/mise" ]; then
  mise_bin="$HOME/.local/bin/mise"
else
  printf 'uninstall.sh: mise is not available on PATH or at ~/.local/bin/mise\n' >&2
  exit 1
fi

empty_dir="$(mktemp -d)"
trap 'rmdir "$empty_dir" 2>/dev/null || true' EXIT

if ((dry_run)); then
  dotfile_args=(--dry-run --force --yes)
  package_args=(--dry-run --yes)
  uninstall_args=(--all --dry-run --yes)
  implode_args=(--config --dry-run --yes)
else
  dotfile_args=(--force --yes)
  package_args=(--yes)
  uninstall_args=(--all --yes)
  implode_args=(--config --yes)
fi

# Remove every dotfile and template target declared by this repository.
"$mise_bin" -C "$repo" bootstrap dotfiles unapply "${dotfile_args[@]}"

if (( !dry_run )); then
  # Stop this checkout from being considered by package pruning.
  "$mise_bin" untrust "$repo/mise.toml" || true
fi

# Prune resources only when mise can prove that it owns them and the backend
# supports uninstallation. This intentionally operates on mise-owned packages
# visible from an empty directory and may affect other mise configurations.
"$mise_bin" -C "$empty_dir" bootstrap packages prune --manager brew "${package_args[@]}"
"$mise_bin" -C "$empty_dir" bootstrap packages prune --manager brew-cask "${package_args[@]}"

# Remove every mise-managed tool version. This is machine-wide for the shared
# mise installation, including versions installed by other configurations.
"$mise_bin" -C "$empty_dir" uninstall "${uninstall_args[@]}"

# Remove mise's own CLI, config, installs, state, and cache where supported.
"$mise_bin" implode "${implode_args[@]}"

if ((dry_run)); then
  printf 'Dry run complete; no machine state was changed. Repository: %s\n' "$repo"
else
  printf 'Mise resources removed; repository remains at: %s\n' "$repo"
fi
