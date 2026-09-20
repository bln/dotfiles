#!/usr/bin/env bash
# shellcheck disable=SC2088 # ~ appears only in human-readable pass/fail labels, not as a path
# Unit: .zshenv establishes the XDG + ZDOTDIR + PATH contract every other rc
# file depends on.
#
# .zshenv is the one shell file that must live in $HOME; zsh reads it before any
# other rc. If ZDOTDIR or the XDG dirs resolve wrong, .zprofile/.zshrc are never
# found or write cache to the wrong place, and ~/.local/bin missing from PATH
# means script-installed mise/uv are invisible to .zprofile shims. A grep cannot
# confirm the exported *values*; we source the real file in a clean shell and
# read what it actually exports.
#
# Sourced with zsh (its target interpreter) so parameter syntax matches; skips
# cleanly if zsh is absent.

echo "== zshenv-contract =="

if ! command -v zsh >/dev/null 2>&1; then
  skip "zshenv-contract (zsh not installed)"
  return 0
fi

ZSHENV="$REPO/home/.zshenv"
assert_file ".zshenv exists" "$ZSHENV"

# Source .zshenv in a clean zsh with a controlled HOME and no pre-set XDG/PATH,
# then print the resulting variables. env -i gives a pristine environment;
# /usr/bin:/bin keeps zsh's own dependencies resolvable.
probe() {
  local home="$1" var="$2"
  env -i HOME="$home" PATH="/usr/bin:/bin" \
    zsh -c "source '$ZSHENV' 2>/dev/null; print -r -- \${$var}"
}

sb="$(sandbox)"

assert_eq "XDG_CONFIG_HOME defaults under HOME" "$sb/.config"        "$(probe "$sb" XDG_CONFIG_HOME)"
assert_eq "XDG_CACHE_HOME defaults under HOME"  "$sb/.cache"         "$(probe "$sb" XDG_CACHE_HOME)"
assert_eq "XDG_DATA_HOME defaults under HOME"   "$sb/.local/share"   "$(probe "$sb" XDG_DATA_HOME)"
assert_eq "XDG_STATE_HOME defaults under HOME"  "$sb/.local/state"   "$(probe "$sb" XDG_STATE_HOME)"
assert_eq "ZDOTDIR points at ~/.config/zsh"     "$sb/.config/zsh"    "$(probe "$sb" ZDOTDIR)"
assert_eq "NPM config relocated into XDG"       "$sb/.config/npm/npmrc" "$(probe "$sb" NPM_CONFIG_USERCONFIG)"
assert_eq "Pi config relocated into XDG"         "$sb/.config/pi/agent" "$(probe "$sb" PI_CODING_AGENT_DIR)"
assert_eq "Codex config relocated into XDG"      "$sb/.config/codex" "$(probe "$sb" CODEX_HOME)"
assert_eq "Claude config relocated into XDG"     "$sb/.config/claude" "$(probe "$sb" CLAUDE_CONFIG_DIR)"

# ~/.local/bin must be present AND ahead of the inherited PATH so script-installed
# mise/uv win over any system copy.
path_out="$(probe "$sb" PATH)"
assert_contains "PATH includes ~/.local/bin" "$path_out" "$sb/.local/bin"
case "$path_out" in
  "$sb/.local/bin":*) ok "~/.local/bin is first on PATH" ;;
  *) bad "~/.local/bin is first on PATH" "PATH=$path_out" ;;
esac

# XDG dirs respect a pre-existing value (the ${VAR:-default} form must not clobber).
assert_eq "XDG_CONFIG_HOME honors a preset value" "/custom/cfg" \
  "$(env -i HOME="$sb" XDG_CONFIG_HOME=/custom/cfg PATH="/usr/bin:/bin" \
       zsh -c "source '$ZSHENV' 2>/dev/null; print -r -- \$XDG_CONFIG_HOME")"
assert_eq "XDG_CACHE_HOME honors a preset value" "/custom/cache" \
  "$(env -i HOME="$sb" XDG_CACHE_HOME=/custom/cache PATH="/usr/bin:/bin" \
       zsh -c "source '$ZSHENV' 2>/dev/null; print -r -- \$XDG_CACHE_HOME")"
assert_eq "XDG_DATA_HOME honors a preset value" "/custom/data" \
  "$(env -i HOME="$sb" XDG_DATA_HOME=/custom/data PATH="/usr/bin:/bin" \
       zsh -c "source '$ZSHENV' 2>/dev/null; print -r -- \$XDG_DATA_HOME")"
assert_eq "XDG_STATE_HOME honors a preset value" "/custom/state" \
  "$(env -i HOME="$sb" XDG_STATE_HOME=/custom/state PATH="/usr/bin:/bin" \
       zsh -c "source '$ZSHENV' 2>/dev/null; print -r -- \$XDG_STATE_HOME")"
