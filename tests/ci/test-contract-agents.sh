#!/usr/bin/env bash
# ci: agent resources are copy-managed correctly.
#
# Two real invariants that no tool enforces and that a symlink would silently
# break (mise applies these in `mode = "copy"`; `git config --global` and agent
# CLIs rewrite through symlinks, putting machine state into the repo):
#   1. The tracked SOURCES are real files/dirs, never symlinks.
#   2. The Claude skill tree is a byte-for-byte copy of the shared skill tree.
#      It is deliberately duplicated (Claude reads a separate root) rather than
#      generated at converge, because AGENTS.md forbids touching these trees in
#      automation. So a drift guard is the safety net. See docs/TESTING.md.
#
# Read-only: this test never writes under home/.config/skills or claude/skills.

echo "== ci: agent copy layout =="

# 1. The single shared instruction source is a real file (copy-mode integrity).
#    All three agents (claude CLAUDE.md, codex/pi AGENTS.md) copy from this one
#    file, so it can never drift; a symlink here would put machine state in the
#    repo via agent/`git config` rewrites.
rel="home/.config/agents/INSTRUCTIONS.md"
if [ ! -f "$REPO/$rel" ]; then
  bad "source exists: $rel" "missing"
elif [ -L "$REPO/$rel" ]; then
  bad "source is a real file: $rel" "must not be a symlink (copy mode)"
else
  ok "source is a real file: $rel"
fi

# 2. Claude skill tree mirrors the shared skill tree exactly.
shared="$REPO/home/.config/skills"
claude="$REPO/home/.config/claude/skills"
if [ ! -d "$shared" ] || [ ! -d "$claude" ]; then
  bad "skill trees exist" "missing $shared or $claude"
else
  drift=0
  while IFS= read -r f; do
    rel="${f#"$shared"/}"
    if ! cmp -s "$f" "$claude/$rel"; then
      bad "claude skill copy matches: $rel" "missing or differs"
      drift=$((drift + 1))
    fi
  done < <(find -P "$shared" -type f | sort)
  [ "$drift" -eq 0 ] && ok "claude skill tree mirrors the shared skill tree"
fi
