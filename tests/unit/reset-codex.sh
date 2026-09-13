#!/usr/bin/env bash
# Tests for home/.config/mise/tasks/reset-codex

echo "== reset-codex =="

RESET_CODEX="$REPO/tasks/reset-codex"

# Keeps config/auth, deletes session state. The keep-list is the data-loss
# guard, so assert both sides: kept files survive, everything else is gone.
{
  home="$(sandbox)"
  mkdir -p "$home/sessions" "$home/skills" "$home/rules" "$home/history"
  for keep in auth.json config.toml AGENTS.md AGENTS.override.md; do touch "$home/$keep"; done
  touch "$home/sessions/s1.json" "$home/history/h.log" "$home/scratch.tmp"
  out="$(CODEX_HOME="$home" bash "$RESET_CODEX" 2>&1)"; rc=$?
  assert_eq "exits 0" "0" "$rc"
  for keep in auth.json config.toml AGENTS.md AGENTS.override.md skills rules; do
    if [ -e "$home/$keep" ]; then ok "kept $keep"; else bad "kept $keep" "$keep was deleted"; fi
  done
  for gone in sessions history scratch.tmp; do
    if [ ! -e "$home/$gone" ]; then ok "cleared $gone"; else bad "cleared $gone" "$gone survived"; fi
  done
}

# Missing CODEX_HOME dir is a clean no-op, not an error.
{
  home="$(sandbox)/does-not-exist"
  out="$(CODEX_HOME="$home" bash "$RESET_CODEX" 2>&1)"; rc=$?
  assert_eq "missing dir exits 0" "0" "$rc"
  assert_contains "missing dir reports no-op" "$out" "nothing to clear"
}

# Nested content inside kept directories survives.
{
  home="$(sandbox)"
  mkdir -p "$home/skills/my-skill" "$home/rules/custom"
  echo "content" > "$home/skills/my-skill/SKILL.md"
  echo "rule" > "$home/rules/custom/rule.txt"
  touch "$home/auth.json" "$home/scratch.tmp"
  CODEX_HOME="$home" bash "$RESET_CODEX" >/dev/null 2>&1
  assert_file "nested skill file survives" "$home/skills/my-skill/SKILL.md"
  assert_file "nested rule file survives" "$home/rules/custom/rule.txt"
  assert_not_exists "scratch still cleared" "$home/scratch.tmp"
}
