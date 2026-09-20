#!/usr/bin/env bash
# Static: the default and alternate Neovim configurations are present and
# reachable through the declared mise dotfile mappings and shell aliases.
set -euo pipefail

echo "== static: Neovim configurations =="

CONFIG="$REPO/home/.config/mise/config.toml"
config_src="$(<"$CONFIG")"
ZSHRC="$REPO/home/.config/zsh/.zshrc"
zshrc_src="$(<"$ZSHRC")"

for name in nvim nvim-lazyvim nvim-kickstart; do
  assert_file "$name init.lua exists" "$REPO/home/.config/$name/init.lua"
done

assert_file "LazyVim bootstrap exists" "$REPO/home/.config/nvim-lazyvim/lua/config/lazy.lua"
assert_file "Kickstart plugin examples exist" "$REPO/home/.config/nvim-kickstart/lua/kickstart/plugins/debug.lua"

assert_contains "mise maps LazyVim config" "$config_src" '"~/.config/nvim-lazyvim" = {}'
assert_contains "mise maps Kickstart config" "$config_src" '"~/.config/nvim-kickstart" = {}'
assert_contains "vz launches LazyVim" "$zshrc_src" "alias vz='NVIM_APPNAME=nvim-lazyvim nvim'"
assert_contains "vk launches Kickstart" "$zshrc_src" "alias vk='NVIM_APPNAME=nvim-kickstart nvim'"
