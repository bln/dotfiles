#!/usr/bin/env bash
# ci: RTK setup and teardown converge machine-local integrations and undo them.

echo "== ci: RTK setup/teardown =="

if ! command -v rtk >/dev/null 2>&1; then
  skip "RTK setup/teardown (rtk not installed)"
  return 0
fi
mise_data_dir="${MISE_DATA_DIR:-$HOME/.local/share/mise}"

sb="$(sandbox)"
claude_dir="$sb/claude"
codex_home="$sb/codex"
pi_dir="$sb/pi"
mkdir -p "$claude_dir" "$codex_home" "$pi_dir/extensions"
printf '{"sentinel":true}\n' > "$claude_dir/settings.json"
printf '# sentinel\n' > "$codex_home/AGENTS.md"
printf 'sentinel\n' > "$pi_dir/extensions/keep.ts"

snapshot_dir="$(mktemp -d)"
sandboxes+=("$snapshot_dir")

snapshot_root() {
  local output="$1" name="$2" root="$3" file
  printf '[%s]\n' "$name" >> "$output"
  find -P "$root" -print | LC_ALL=C sort >> "$output"
  while IFS= read -r file; do
    printf 'file %s ' "${file#"$root/"}" >> "$output"
    cksum "$file" | awk '{print $1, $2}' >> "$output"
  done < <(find -P "$root" -type f -print | LC_ALL=C sort)
}

snapshot_state() {
  local output="$1"
  : > "$output"
  snapshot_root "$output" claude "$claude_dir"
  snapshot_root "$output" codex "$codex_home"
  snapshot_root "$output" pi "$pi_dir"
}

run_rtk_task() {
  local task="$1"
  run_capture env \
    HOME="$sb" \
    MISE_DATA_DIR="$mise_data_dir" \
    CLAUDE_CONFIG_DIR="$claude_dir" \
    CODEX_HOME="$codex_home" \
    PI_CODING_AGENT_DIR="$pi_dir" \
    bash "$REPO/tasks/$task/rtk"
}

setup_first="$snapshot_dir/setup-first"
setup_second="$snapshot_dir/setup-second"
teardown_first="$snapshot_dir/teardown-first"
teardown_second="$snapshot_dir/teardown-second"

run_rtk_task setup
assert_eq "setup exits 0" "0" "$RUN_STATUS"
snapshot_state "$setup_first"

run_rtk_task setup
assert_eq "setup is idempotent" "0" "$RUN_STATUS"
snapshot_state "$setup_second"
assert_eq "repeated setup preserves state" "$(cat "$setup_first")" "$(cat "$setup_second")"

run_rtk_task teardown
assert_eq "teardown exits 0" "0" "$RUN_STATUS"
snapshot_state "$teardown_first"
settings="$(cat "$claude_dir/settings.json")"
agents="$(cat "$codex_home/AGENTS.md")"
assert_contains "Claude settings survive teardown" "$settings" "sentinel"
assert_not_contains "Claude hook is removed" "$settings" "rtk hook claude"
assert_eq "Codex instructions survive teardown" "# sentinel" "$agents"
assert_not_exists "Codex RTK instructions are removed" "$codex_home/RTK.md"
assert_not_contains "Codex RTK reference is removed" "$agents" "RTK.md"
assert_file "Pi unrelated extension survives teardown" "$pi_dir/extensions/keep.ts"
assert_not_exists "Pi RTK extension is removed" "$pi_dir/extensions/rtk.ts"
assert_not_exists "Pi RTK ownership state is removed" "$pi_dir/extensions/.rtk-agents"

run_rtk_task teardown
assert_eq "teardown is idempotent" "0" "$RUN_STATUS"
snapshot_state "$teardown_second"
assert_eq "repeated teardown preserves state" "$(cat "$teardown_first")" "$(cat "$teardown_second")"
