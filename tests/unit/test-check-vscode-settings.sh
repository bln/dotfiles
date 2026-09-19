#!/usr/bin/env bash
# Tests for scripts/check-vscode-settings.sh (copy-mode drift detection).

echo "== check:vscode-settings =="

CHECK_VSCODE="$REPO/scripts/check-vscode-settings.sh"

# Matching live copy -> OK, exit 0.
{
  d="$(sandbox)"
  printf '{"a":1}\n' >"$d/repo.json"
  printf '{"a":1}\n' >"$d/live.json"
  run_capture env VSCODE_SETTINGS_LIVE="$d/live.json" VSCODE_SETTINGS_REPO="$d/repo.json" bash "$CHECK_VSCODE"
  assert_eq "match -> exit 0" "0" "$RUN_STATUS"
  assert_contains "reports match" "$(cat "$RUN_STDOUT")" "matches the repo copy"
}

# Divergent live copy -> warns with resync path, still exit 0 (drift is not fatal).
{
  d="$(sandbox)"
  printf '{"a":1}\n' >"$d/repo.json"
  printf '{"a":2}\n' >"$d/live.json"
  run_capture env VSCODE_SETTINGS_LIVE="$d/live.json" VSCODE_SETTINGS_REPO="$d/repo.json" bash "$CHECK_VSCODE"
  assert_eq "drift -> exit 0" "0" "$RUN_STATUS"
  assert_contains "names the resync path" "$(cat "$RUN_STDERR")" "mise dotfiles add --changed"
}

# Missing live file -> warns to apply, exit 0.
{
  d="$(sandbox)"
  printf '{"a":1}\n' >"$d/repo.json"   # no live.json
  run_capture env VSCODE_SETTINGS_LIVE="$d/live.json" VSCODE_SETTINGS_REPO="$d/repo.json" bash "$CHECK_VSCODE"
  assert_eq "missing live -> exit 0" "0" "$RUN_STATUS"
  assert_contains "tells you to apply" "$(cat "$RUN_STDERR")" "dotfiles apply"
}

# Live file is a leftover symlink -> error, exit 1 (copy mode expects a real file).
{
  d="$(sandbox)"
  printf '{"a":1}\n' >"$d/repo.json"
  ln -s "$d/repo.json" "$d/live.json"
  run_capture env VSCODE_SETTINGS_LIVE="$d/live.json" VSCODE_SETTINGS_REPO="$d/repo.json" bash "$CHECK_VSCODE"
  assert_eq "symlink -> exit 1" "1" "$RUN_STATUS"
  assert_contains "flags copy mode" "$(cat "$RUN_STDERR")" "copy mode"
}
