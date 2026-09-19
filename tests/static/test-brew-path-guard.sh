#!/usr/bin/env bash
# Regression guard for the Homebrew PATH + zsh plugin wiring.
#
# A refactor once stripped the Homebrew prefix from _.path and dropped the
# .zshrc plugin-prefix fallbacks, which silently unhooked brew-managed CLIs
# (mas, git) and the zsh plugins. mise is a Homebrew *client* into the standard
# prefix - it has no standalone brew - so the prefix must stay on PATH. These
# checks lock that wiring in so it cannot be removed without a failing test.
#
# Uses testlib ok()/bad() - do NOT redefine them here.

echo "== static: brew path + plugin wiring =="

config="$REPO/home/.config/mise/config.toml"
zshrc="$REPO/home/.config/zsh/.zshrc"

# ── 1. _.path keeps a Homebrew prefix so brew-managed CLIs resolve ────────────
{
  path_line="$(grep -E '^_\.path' "$config" || true)"
  if [ -z "$path_line" ]; then
    bad "brew prefix on _.path" "no _.path entry in config.toml"
  elif printf '%s' "$path_line" | grep -qE '/(opt/homebrew|usr/local)/bin'; then
    ok "brew prefix on _.path"
  else
    bad "brew prefix on _.path" "_.path is missing a Homebrew bin prefix: $path_line"
  fi
}

# ── 2. .zshrc keeps plugin-prefix fallbacks (not hard-coded to one prefix) ────
{
  if grep -q '/opt/homebrew/share' "$zshrc" && grep -q '/usr/local/share' "$zshrc"; then
    ok "zsh plugin prefix fallbacks"
  else
    bad "zsh plugin prefix fallbacks" ".zshrc must keep both /opt/homebrew/share and /usr/local/share fallbacks"
  fi
}

# ── 3. both zsh plugins are still sourced ─────────────────────────────────────
{
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    if grep -q "$plugin/$plugin.zsh" "$zshrc"; then
      ok "sources $plugin"
    else
      bad "sources $plugin" ".zshrc no longer sources $plugin"
    fi
  done
}
