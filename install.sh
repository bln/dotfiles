#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

curl -fsSL --proto '=https' https://mise.run | sh

MISE_CONFIG_DIR="$repo/home/.config/mise" \
  "$HOME/.local/bin/mise" -C "$repo" bootstrap --yes --prompt-secrets --force-dotfiles
