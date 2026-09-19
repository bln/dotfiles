#!/usr/bin/env bash
# Tests for the zsh machine-local override seam.
#
# .zshrc must source $ZDOTDIR/.zshrc.local last (so it can override anything),
# guarded so a fresh machine without the file is fine, and the file must be
# gitignored so per-machine tweaks never get committed. Sourcing the full
# real .zshrc at runtime would drag in mise/compinit/starship and is not
# host-independent (CI runs on Linux), so assert the seam statically instead.

echo "== unit: zsh local overrides =="

zshrc="$REPO/home/.config/zsh/.zshrc"
gitignore="$REPO/.gitignore"

# Sources the local override, guarded and last.
{
  line="$(grep -E '\.zshrc\.local' "$zshrc" || true)"
  assert_ne ".zshrc references .zshrc.local" "" "$line"
  assert_contains "guarded with -r test" "$line" "-r"
  assert_contains "sources it" "$line" "source"
}

# The last non-blank line of .zshrc is the override source (so it wins).
{
  last="$(grep -vE '^\s*$' "$zshrc" | tail -1)"
  assert_contains "override is sourced last" "$last" ".zshrc.local"
}

# The local file is gitignored.
{
  assert_contains "gitignored" "$(cat "$gitignore")" "home/.config/zsh/.zshrc.local"
}
