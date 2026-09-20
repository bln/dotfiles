#!/usr/bin/env bash
# Static: agent resources have an explicit source allowlist and native mise mappings.

echo "== static: agent layout =="

CONFIG="$REPO/home/.config/mise/config.toml"

for rel in \
  "home/.config/pi/agent/AGENTS.md" \
  "home/.config/codex/AGENTS.md" \
  "home/.config/claude/CLAUDE.md"; do
  assert_file "source file exists: $rel" "$REPO/$rel"
  if [ -L "$REPO/$rel" ]; then
    bad "source file is real: $rel" "source must not be a symlink"
  else
    ok "source file is real: $rel"
  fi
done

for rel in home/.config/skills home/.config/claude/skills; do
  assert_dir "source directory exists: $rel" "$REPO/$rel"
  link="$(find -P "$REPO/$rel" -type l -print -quit 2>/dev/null || true)"
  if [ -n "$link" ]; then
    bad "source directory is real: $rel" "symlink found at $link"
  else
    ok "source directory is real: $rel"
  fi
done

assert_not_exists "old home/.agents source removed" "$REPO/home/.agents"

# The Claude tree is intentionally an independent copy of the user-wide tree.
while IFS= read -r shared; do
  rel="$(printf '%s\n' "$shared" | sed "s|^$REPO/home/.config/skills/||")"
  claude="$REPO/home/.config/claude/skills/$rel"
  if [ -f "$claude" ] && cmp -s "$shared" "$claude"; then
    ok "Claude skill copy matches: $rel"
  else
    bad "Claude skill copy matches: $rel" "missing or differs: $claude"
  fi
done < <(find -P "$REPO/home/.config/skills" -type f -print | sort)

# Check the exact native entries, including explicit copy mode and Git manifests.
for entry in \
  '"~/.config/pi/agent/AGENTS.md" = { source = "~/dotfiles/home/.config/pi/agent/AGENTS.md", mode = "copy" }' \
  '"~/.config/codex/AGENTS.md" = { source = "~/dotfiles/home/.config/codex/AGENTS.md", mode = "copy" }' \
  '"~/.agents/skills" = { source = "~/dotfiles/home/.config/skills", mode = "copy", manifest = "git" }' \
  '"~/.config/claude/CLAUDE.md" = { source = "~/dotfiles/home/.config/claude/CLAUDE.md", mode = "copy" }' \
  '"~/.config/claude/skills" = { source = "~/dotfiles/home/.config/claude/skills", mode = "copy", manifest = "git" }'; do
  if grep -Fq "$entry" "$CONFIG"; then
    ok "native mapping: $entry"
  else
    bad "native mapping: $entry" "entry missing from $CONFIG"
  fi
done

assert_not_ignored() {
  local rel="$1"
  if git -C "$REPO" check-ignore --no-index -q "$rel"; then
    bad "resource is allowlisted: $rel" "path is ignored"
  else
    ok "resource is allowlisted: $rel"
  fi
}

assert_ignored() {
  local rel="$1"
  if git -C "$REPO" check-ignore --no-index -q "$rel"; then
    ok "runtime path is ignored: $rel"
  else
    bad "runtime path is ignored: $rel" "path is not covered by .gitignore"
  fi
}

for rel in \
  home/.config/pi/agent/AGENTS.md \
  home/.config/codex/AGENTS.md \
  home/.config/skills/astro-for-github-pages/SKILL.md \
  home/.config/claude/CLAUDE.md \
  home/.config/claude/skills/astro-for-github-pages/SKILL.md; do
  assert_not_ignored "$rel"
done

for rel in \
  home/.config/pi/agent/settings.json \
  home/.config/pi/agent/auth.json \
  home/.config/codex/config.toml \
  home/.config/codex/auth.json \
  home/.config/codex/skills/.system/example/SKILL.md \
  home/.config/claude/settings.json \
  home/.config/claude/.claude.json \
  home/.config/claude/sessions/example.jsonl; do
  assert_ignored "$rel"
done
