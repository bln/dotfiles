#!/usr/bin/env bash
# Bootstrap a fresh macOS machine from this dotfiles repo.
set -euo pipefail

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
die()  { printf "ERROR: %s\n" "$1" >&2; exit 1; }

trap 'printf "FAILED at line %d. Machine state may be partial; re-run install.sh to converge.\n" "$LINENO" >&2' ERR

# ── arguments ─────────────────────────────────────────────────────────────────
# install has no --dry-run: its work is a one-shot converge (mise bootstrap +
# native packages + residual VS Code extensions + uv python + git identity).
# Reject unknown args rather than silently ignore them, and point at the
# preview path.
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      cat <<'EOF'
Usage: ~/dotfiles/install.sh

Bootstrap a fresh macOS machine from this dotfiles checkout. Runs to completion;
there is no dry-run. To preview the heavy convergence step without applying it:

  mise bootstrap --dry-run

EOF
      exit 0
      ;;
    *) die "unknown argument: $1 (install has no dry-run; see 'mise bootstrap --dry-run')" ;;
  esac
  # shellcheck disable=SC2317  # reachable once a non-exiting flag is added
  shift
done

REPO="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$REPO/home/.config/mise/config.toml"
LIVE_CONFIG="$HOME/.config/mise/config.toml"
MIN_MISE_VERSION="2026.9.5"

[ -f "$CONFIG" ] || die "$CONFIG not found. Run install.sh from the dotfiles checkout."

# ── step 1/5: install mise ────────────────────────────────────────────────────
if ! command -v mise >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/mise" ]; then
  bold "== 1/5: Installing mise -> ~/.local/bin =="
  # Pin the version to match min_version in config.toml.
  MISE_VERSION="$MIN_MISE_VERSION" curl -fsSL https://mise.run | sh
else
  bold "== 1/5: mise already installed =="
fi

export PATH="$HOME/.local/bin:$PATH"

# Verify mise version meets minimum requirement.
mise_version="$(mise --version | head -1 | sed 's/[^0-9.]//g')"
bold "== mise $mise_version =="
if [ "$(printf '%s\n%s\n' "$MIN_MISE_VERSION" "$mise_version" | sort -V | head -1)" != "$MIN_MISE_VERSION" ]; then
  die "mise $mise_version is older than required $MIN_MISE_VERSION. Run: mise self-update"
fi

# ── step 2/5: symlink config ─────────────────────────────────────────────────
# On a fresh machine ~/.config/mise/config.toml does not exist yet. Point mise
# at the repo copy for the first bootstrap; the dotfiles step symlinks it.
bold "== 2/5: Linking config =="
export MISE_GLOBAL_CONFIG_FILE="$CONFIG"

mkdir -p "$(dirname "$LIVE_CONFIG")"
if [ -L "$LIVE_CONFIG" ] || [ ! -e "$LIVE_CONFIG" ]; then
  ln -sfn "$CONFIG" "$LIVE_CONFIG"
elif [ -f "$LIVE_CONFIG" ]; then
  # Resolve both paths to compare robustly (handles symlinks in the path).
  real_live="$(cd "$(dirname "$LIVE_CONFIG")" && pwd)/$(basename "$LIVE_CONFIG")"
  real_config="$(cd "$(dirname "$CONFIG")" && pwd)/$(basename "$CONFIG")"
  if [ "$real_live" = "$real_config" ]; then
    : # same file, nothing to do
  else
    die "$LIVE_CONFIG exists and is not a symlink. Move it aside before installing."
  fi
fi

# ── step 3/5: trust config ───────────────────────────────────────────────────
bold "== 3/5: Trusting config =="
mise trust "$CONFIG"
[ -f "$REPO/mise.toml" ] && mise trust "$REPO/mise.toml"
[ -d "$REPO/home/.config/mise/tasks" ] && mise trust "$REPO/home/.config/mise/tasks"

# ── step 4/5: bootstrap ──────────────────────────────────────────────────────
bold "== 4/5: mise bootstrap =="
mise bootstrap --yes --force-dotfiles

[ -d "$HOME/.config/mise/tasks" ] && mise trust "$HOME/.config/mise/tasks"

# ── step 5/5: git identity ───────────────────────────────────────────────────
if [ ! -f "$HOME/.config/git/config.local" ]; then
  bold "== 5/5: Git identity =="
  mise run setup:git-identity
else
  bold "== 5/5: Git identity (already configured) =="
fi

if [ -L "$HOME/.config/mise/config.toml" ]; then
  bold "== Done. Open a new shell: =="
  echo "  exec zsh -l"
else
  echo "WARNING: config symlink missing; check 'mise dotfiles status'."
fi
