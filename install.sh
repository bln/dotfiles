#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
mise_bin="${MISE_BIN:-$HOME/.local/bin/mise}"

case "$(uname -s):$(uname -m)" in
  Darwin:arm64)
    ;;
  *)
    printf 'install.sh: this repository requires macOS arm64\n' >&2
    exit 1
    ;;
esac

if [ ! -x "$mise_bin" ]; then
  mkdir -p "$(dirname "$mise_bin")"
  curl -fsSL https://mise.run | MISE_INSTALL_PATH="$mise_bin" sh
fi

if [ ! -x "$mise_bin" ]; then
  printf 'install.sh: mise was not installed at %s\n' "$mise_bin" >&2
  exit 1
fi

# Prefer the standalone mise installation on PATH.
export PATH="$(dirname "$mise_bin"):$PATH"

"$mise_bin" --version
"$mise_bin" trust "$repo/mise.toml"
"$mise_bin" -C "$repo" bootstrap --yes --locked --force-dotfiles
