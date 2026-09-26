#!/usr/bin/env bash
# Teardown step 2: remove repo-declared system packages via mise, the same
# backend that installed them - never a direct brew/mas call (AGENTS.md: mise is
# the sole control plane).
#
# Why this is not a one-liner: mise has no "remove what this config declares"
# command. `bootstrap unapply` excludes packages by design, and the old
# `packages unapply` is gone. The only primitive is `packages prune`, which
# removes packages that NO trusted, loadable config still declares. So to prune
# the packages THIS repo declares we point mise at a tiny standalone config that
# declares an EMPTY [bootstrap.packages], and untrust the repo configs so no
# tracked config re-declares them. prune then removes what mise installed.
#
# mise removes only what it can prove it owns: brew formulae come off cleanly;
# casks with lifecycle uninstall hooks or unprovable app ownership, and all mas
# apps (which mise cannot prune at all), are declined by mise with a printed
# reason - we surface those, we do not force them (that would mean reaching
# around mise). macOS defaults and the tools table are out of scope here (tools
# go via the manual `mise uninstall` printed by the teardown task).
#
# Safe by default: without --apply (or APPLY=true) it dry-runs.
set -euo pipefail

APPLY="${APPLY:-false}"
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    *) printf 'unknown argument: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

export PATH="$HOME/.local/bin:$PATH"
if ! command -v mise >/dev/null 2>&1; then
  printf 'WARNING: mise not found; skipping package prune\n' >&2
  exit 0
fi

# Derive the repo from this script's path (not the ~/.config symlink, which an
# earlier teardown step removes) - symmetric with teardown-dotfiles.sh.
repo="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
config="$repo/home/.config/mise/config.toml"
root="$repo/mise.toml"

# A standalone config declaring no packages. prune loads this as the desired
# state; everything mise installed for [bootstrap.packages] is then undeclared.
overlay_dir="$(mktemp -d)"
overlay="$overlay_dir/config.toml"
printf '[bootstrap.packages]\n' >"$overlay"

# The trust dance is required in BOTH dry-run and apply: prune keeps any package
# a trusted tracked config still declares, so without untrusting the repo
# configs (and trusting the empty overlay) a dry-run would misleadingly report
# "nothing to prune" - it must mutate trust to compute a truthful preview. That
# mutation is a transient global side effect, so it MUST be fully reverted on
# every exit path. The trap is therefore armed FIRST (before any untrust) and
# covers INT/TERM as well as EXIT, so a crash or Ctrl-C mid-prune still restores
# the trust store to how we found it - the store is unchanged AFTER this step in
# both modes. Guarded on the files existing: after full teardown the repo may be
# the only copy left.
restore_trust() {
  mise trust --untrust "$overlay" >/dev/null 2>&1 || true
  [ -f "$config" ] && mise trust "$config" >/dev/null 2>&1 || true
  [ -f "$root" ]   && mise trust "$root"   >/dev/null 2>&1 || true
}
trap 'restore_trust; rm -rf "$overlay_dir"' EXIT INT TERM
[ -f "$config" ] && mise trust --untrust "$config" >/dev/null 2>&1 || true
[ -f "$root" ]   && mise trust --untrust "$root"   >/dev/null 2>&1 || true
mise trust "$overlay" >/dev/null 2>&1 || true

# brew and brew-cask are the managers with prunable packages; mas does not
# support pruning, so skip it rather than error. mise prints a per-package
# reason for anything it declines (unprovable cask ownership, lifecycle hooks).
# Note: macOS ships bash 3.2, where "${arr[@]}" on an empty array is an unbound
# error under `set -u`; pass --dry-run as a plain string, not an empty-array
# splat, to stay portable.
dry_flag='--dry-run'
[ "$APPLY" = true ] && dry_flag=''
for mgr in brew brew-cask; do
  # shellcheck disable=SC2086 # dry_flag is one optional word, intentional split
  MISE_GLOBAL_CONFIG_FILE="$overlay" mise -C "$overlay_dir" \
    bootstrap packages prune --manager "$mgr" $dry_flag --yes || true
done

printf 'NOTE: mas apps and any casks mise declined above are left installed (App Store / GUI apps mise cannot safely remove).\n' >&2
