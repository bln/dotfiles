#!/usr/bin/env bash
# shellcheck disable=SC2088 # ~ appears only in human-readable labels, not as a path
# ci: .zshenv establishes the XDG + ZDOTDIR + PATH contract every other rc file
# and every script-installed tool depends on.
#
# .zshenv is the one shell file in $HOME; zsh reads it before anything else. If
# ZDOTDIR or the XDG dirs resolve wrong, .zprofile/.zshrc are never found; if
# ~/.local/bin is not FIRST on PATH, a script-installed mise/uv loses to a system
# copy. A grep cannot confirm the exported VALUES - we source the real file in a
# pristine shell and read what it actually exports.

echo "== ci: shell env contract =="

if ! command -v zsh >/dev/null 2>&1; then
  skip "shell env contract (zsh not installed)"
  return 0
fi

ZSHENV="$REPO/home/.zshenv"

# Source .zshenv in a pristine zsh (env -i) with a controlled HOME, then print a
# resulting variable. /usr/bin:/bin keeps zsh's own deps resolvable.
probe() {
  local home="$1" var="$2"
  env -i HOME="$home" PATH="/usr/bin:/bin" \
    zsh -c "source '$ZSHENV' 2>/dev/null; print -r -- \${$var}"
}

sb="$(sandbox)"

assert_eq "XDG_CONFIG_HOME defaults under HOME" "$sb/.config"      "$(probe "$sb" XDG_CONFIG_HOME)"
assert_eq "XDG_DATA_HOME defaults under HOME"   "$sb/.local/share" "$(probe "$sb" XDG_DATA_HOME)"
assert_eq "ZDOTDIR points at ~/.config/zsh"     "$sb/.config/zsh"  "$(probe "$sb" ZDOTDIR)"

# ~/.local/bin present AND first, so script-installed tools win.
path_out="$(probe "$sb" PATH)"
assert_contains "PATH includes ~/.local/bin" "$path_out" "$sb/.local/bin"
case "$path_out" in
  "$sb/.local/bin":*) ok "~/.local/bin is first on PATH" ;;
  *) bad "~/.local/bin is first on PATH" "PATH=$path_out" ;;
esac

# The ${VAR:-default} form must honor a preset value, not clobber it. One
# representative is enough - all four XDG dirs use the identical idiom.
assert_eq "XDG dir honors a preset value" "/custom/cfg" \
  "$(env -i HOME="$sb" XDG_CONFIG_HOME=/custom/cfg PATH="/usr/bin:/bin" \
       zsh -c "source '$ZSHENV' 2>/dev/null; print -r -- \$XDG_CONFIG_HOME")"
