#!/usr/bin/env bash
# Bootstrap a fresh macOS machine from this dotfiles repo.
set -euo pipefail

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
die() { printf "ERROR: %s\n" "$1" >&2; exit 1; }

# install has no --dry-run: its work is a one-shot converge (mise bootstrap +
# brew bundle + uv python + git identity). Reject unknown args rather than
# silently ignore them, and point at the preview path.
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
done

REPO="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$REPO/home/.config/mise/config.toml"
LIVE_CONFIG="$HOME/.config/mise/config.toml"

[ -f "$CONFIG" ] || die "$CONFIG not found. Run install.sh from the dotfiles checkout."

if ! command -v mise >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/mise" ]; then
  bold "== Installing mise -> ~/.local/bin =="
  curl -fsSL https://mise.run | sh
fi

export PATH="$HOME/.local/bin:$PATH"
bold "== mise $(mise --version) =="

# On a fresh machine ~/.config/mise/config.toml does not exist yet. Point mise
# at the repo copy for the first bootstrap; the dotfiles step symlinks it.
export MISE_GLOBAL_CONFIG_FILE="$CONFIG"

mkdir -p "$(dirname "$LIVE_CONFIG")"
if [ -L "$LIVE_CONFIG" ] || [ ! -e "$LIVE_CONFIG" ]; then
  ln -sfn "$CONFIG" "$LIVE_CONFIG"
elif [ "$(cd "$(dirname "$LIVE_CONFIG")" && pwd)/$(basename "$LIVE_CONFIG")" != "$CONFIG" ]; then
  die "$LIVE_CONFIG exists and is not a symlink. Move it aside before installing."
fi

bold "== Trusting config =="
mise trust "$CONFIG"
[ -f "$REPO/mise.toml" ] && mise trust "$REPO/mise.toml"
[ -d "$REPO/home/.config/mise/tasks" ] && mise trust "$REPO/home/.config/mise/tasks"

bold "== mise bootstrap =="
mise bootstrap --yes --force-dotfiles

[ -d "$HOME/.config/mise/tasks" ] && mise trust "$HOME/.config/mise/tasks"

if [ ! -f "$HOME/.config/git/config.local" ]; then
  bold "== Git identity =="
  mise run setup:git-identity
fi

if [ -L "$HOME/.config/mise/config.toml" ]; then
  bold "== Done. Open a new shell: =="
  echo "  exec zsh -l"
else
  echo "WARNING: config symlink missing; check 'mise dotfiles status'."
fi
