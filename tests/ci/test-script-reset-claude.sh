#!/usr/bin/env bash
# ci: reset-claude clears session dirs and delegates project state to the CLI.
# Tests use CLAUDE_CONFIG_DIR (the real Claude env var) to point at a sandbox.
# CI exercises structural/safety paths only; real CLI verification is in host/.

echo "== ci: reset-claude =="

RESET="$REPO/scripts/reset-claude.sh"

# Keep-list vs delete: session dirs are cleared, config/auth/plugins/skills survive.
{
  home="$(sandbox)"
  mkdir -p "$home/sessions" "$home/cache" "$home/paste-cache" "$home/session-env" \
           "$home/shell-snapshots" "$home/plans" "$home/plugins" "$home/skills" \
           "$home/backups"
  touch "$home/settings.json" "$home/CLAUDE.md"
  echo '{}' >"$home/sessions/s1.json"
  echo x >"$home/plans/plan1.md"
  # Stub: record that project purge was called, exit 0.
  stub_dir="$(sandbox)"
  cat >"$stub_dir/claude" <<'EOF'
#!/usr/bin/env bash
echo "stub: $*" >>"$CLAUDE_CONFIG_DIR/.claude_stub_calls"
exit 0
EOF
  chmod +x "$stub_dir/claude"
  out="$(CLAUDE_CONFIG_DIR="$home" PATH="$stub_dir:$PATH" bash "$RESET" 2>&1)"; rc=$?
  assert_eq "exits 0" "0" "$rc"
  assert_file "kept settings.json" "$home/settings.json"
  assert_file "kept CLAUDE.md" "$home/CLAUDE.md"
  for keep in plugins skills backups; do
    assert_dir "kept $keep" "$home/$keep"
  done
  assert_not_exists "cleared sessions" "$home/sessions"
  assert_not_exists "cleared cache" "$home/cache"
  assert_not_exists "cleared paste-cache" "$home/paste-cache"
  assert_not_exists "cleared session-env" "$home/session-env"
  assert_not_exists "cleared shell-snapshots" "$home/shell-snapshots"
  assert_not_exists "cleared plans" "$home/plans"
  assert_file "stub was called" "$home/.claude_stub_calls"
  assert_contains "stub got purge args" "$(cat "$home/.claude_stub_calls")" "project purge --all --yes"
}

# An empty project purge is a CLI no-op even though Claude exits 1. The direct
# session cleanup must still run and the reset must still succeed.
{
  home="$(sandbox)"
  mkdir -p "$home/sessions"; touch "$home/sessions/s1.json"
  stub_dir="$(sandbox)"
  cat >"$stub_dir/claude" <<'EOF'
#!/usr/bin/env bash
echo "No Claude Code project state found" >&2
exit 1
EOF
  chmod +x "$stub_dir/claude"
  out="$(CLAUDE_CONFIG_DIR="$home" PATH="$stub_dir:$PATH" bash "$RESET" 2>&1)"; rc=$?
  assert_eq "empty purge exits 0" "0" "$rc"
  assert_not_exists "empty purge still clears sessions" "$home/sessions"
  assert_contains "empty purge reports no-op" "$out" "nothing to purge"
}

# --dry-run deletes nothing and mentions project purge.
{
  home="$(sandbox)"
  mkdir -p "$home/sessions"; touch "$home/sessions/s1.json" "$home/settings.json"
  stub_dir="$(sandbox)"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$stub_dir/claude"; chmod +x "$stub_dir/claude"
  out="$(CLAUDE_CONFIG_DIR="$home" PATH="$stub_dir:$PATH" bash "$RESET" --dry-run 2>&1)"; rc=$?
  assert_eq "dry-run exits 0" "0" "$rc"
  assert_file "dry-run keeps sessions" "$home/sessions/s1.json"
  assert_contains "dry-run says DRY RUN" "$out" "DRY RUN"
  assert_contains "dry-run mentions project purge" "$out" "project purge"
}

# Missing dir is a clean no-op (no CLI call needed).
{
  out="$(CLAUDE_CONFIG_DIR="$(sandbox)/nope" bash "$RESET" 2>&1)"; rc=$?
  assert_eq "missing dir exits 0" "0" "$rc"
  assert_contains "missing dir reports no-op" "$out" "nothing to clear"
}

# CLI absent: warns but still clears session dirs.
{
  home="$(sandbox)"
  mkdir -p "$home/sessions"; touch "$home/sessions/s1.json"
  # Use a stub dir with no `claude` binary so the script cannot find it.
  empty_dir="$(sandbox)"
  out="$(CLAUDE_CONFIG_DIR="$home" PATH="$empty_dir:/usr/bin:/bin" bash "$RESET" 2>&1)"; rc=$?
  assert_eq "missing CLI exits 0" "0" "$rc"
  assert_contains "warns about missing CLI" "$out" "not found"
  assert_not_exists "still cleared sessions" "$home/sessions"
}

# CLAUDE_CONFIG_DIR guard: a catastrophic target is refused.
{
  set +e; out="$(CLAUDE_CONFIG_DIR="/etc" bash "$RESET" 2>&1)"; rc=$?; set -e
  assert_eq "refuses /etc (exit 2)" "2" "$rc"
  assert_contains "names the unsafe target" "$out" "unsafe CLAUDE_CONFIG_DIR"
}

# Depth guard: shallow non-denylisted path is refused.
{
  set +e; out="$(CLAUDE_CONFIG_DIR="/singlesegment" bash "$RESET" 2>&1)"; rc=$?; set -e
  assert_eq "refuses shallow path (exit 2)" "2" "$rc"
  assert_contains "names the unsafe target" "$out" "unsafe CLAUDE_CONFIG_DIR"
}
