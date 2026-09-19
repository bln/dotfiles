#!/usr/bin/env bash
# Verify-tier (host only): the vscode-ext no-op backend plugin resolves against
# the live config, so `vscode-ext:` tool keys are usable and `mise install`
# will not hard-error on a missing/mispointed plugin dir.
#
# This guards the failure the owner hit while building this: mise ERRORs
# ("local plugin directory does not exist") on any `mise install` if the
# [plugins] path does not resolve. `{{config_root}}` must expand through the
# symlinked config back to the repo. Read-only: enumerates, never installs.
#
# Host-coupled (needs the live checkout + jq); wired into `verify`, never CI.

echo "== vscode-ext-plugin =="

if ! command -v mise >/dev/null 2>&1; then
  skip "vscode-ext-plugin (mise not installed)"
  return 0
fi
if ! command -v jq >/dev/null 2>&1; then
  skip "vscode-ext-plugin (jq not installed)"
  return 0
fi

# The plugin source must exist in the repo.
assert_dir "plugin dir exists in repo" "$REPO/home/.config/mise/plugins/vscode-ext"
assert_file "plugin metadata.lua exists" "$REPO/home/.config/mise/plugins/vscode-ext/metadata.lua"
for hook in backend_list_versions backend_install backend_exec_env; do
  assert_file "plugin hook $hook.lua exists" \
    "$REPO/home/.config/mise/plugins/vscode-ext/hooks/$hook.lua"
done

# `mise ls -c` against the repo config must resolve vscode-ext keys without the
# "local plugin directory does not exist" error (proves {{config_root}} expands).
run_capture mise -C "$REPO" ls -c --json
assert_eq "mise ls -c resolves (plugin path valid)" "0" "$RUN_STATUS"
assert_not_contains "no missing-plugin error" "$(cat "$RUN_STDERR")" "does not exist"

count="$(jq -r '[keys[] | select(startswith("vscode-ext:"))] | length' "$RUN_STDOUT" 2>/dev/null || echo 0)"
if [ "${count:-0}" -gt 0 ]; then
  ok "vscode-ext tools enumerate ($count declared)"
else
  bad "vscode-ext tools enumerate" "no vscode-ext: keys found in mise ls -c --json"
fi
