#!/usr/bin/env bash
# Static: the vscode-ext no-op backend plugin is well-formed.
#
# The plugin makes `vscode-ext:<id>` legal under [tools]; if a required hook is
# missing or returns the wrong shape, `mise install` breaks (hard error) while
# nothing else catches it. This validates the plugin's structure without a live
# mise. When a Lua interpreter is available it additionally loads each hook and
# calls it, asserting the returned table shape; otherwise it falls back to
# structural (grep) checks so the suite stays green on CI (no Lua).

echo "== vscode-ext-plugin-hooks =="

PLUGIN_DIR="$REPO/home/.config/mise/plugins/vscode-ext"

# ── files present ───────────────────────────────────────────────────────────
assert_file "metadata.lua present" "$PLUGIN_DIR/metadata.lua"
assert_file "backend_list_versions hook present" "$PLUGIN_DIR/hooks/backend_list_versions.lua"
assert_file "backend_install hook present" "$PLUGIN_DIR/hooks/backend_install.lua"
assert_file "backend_exec_env hook present" "$PLUGIN_DIR/hooks/backend_exec_env.lua"

# ── metadata declares the plugin name ────────────────────────────────────────
meta="$(cat "$PLUGIN_DIR/metadata.lua")"
assert_contains "metadata sets PLUGIN table" "$meta" "PLUGIN"
assert_contains "metadata names vscode-ext" "$meta" 'name = "vscode-ext"'

# ── each hook defines the correct PLUGIN: function ───────────────────────────
assert_contains "list_versions defines BackendListVersions" \
  "$(cat "$PLUGIN_DIR/hooks/backend_list_versions.lua")" "function PLUGIN:BackendListVersions"
assert_contains "install defines BackendInstall" \
  "$(cat "$PLUGIN_DIR/hooks/backend_install.lua")" "function PLUGIN:BackendInstall"
assert_contains "exec_env defines BackendExecEnv" \
  "$(cat "$PLUGIN_DIR/hooks/backend_exec_env.lua")" "function PLUGIN:BackendExecEnv"

# ── if a Lua interpreter exists, load + call each hook and check return shape ──
LUA=""
for cand in lua luajit lua5.1 lua5.4; do
  if command -v "$cand" >/dev/null 2>&1; then LUA="$cand"; break; fi
done

if [ -n "$LUA" ]; then
  # Harness: define a global PLUGIN table, load the hook (which attaches the
  # method), call it with a dummy ctx, and print an assertion about the result.
  lua_check() {
    local hook="$1" call="$2" expect="$3" label="$4" out
    out="$("$LUA" -e "
      PLUGIN = {}
      dofile('$PLUGIN_DIR/hooks/$hook')
      local r = PLUGIN:$call
      $expect
    " 2>&1)"
    if [ "$out" = "OK" ]; then ok "$label"; else bad "$label" "$out"; fi
  }
  # BackendListVersions -> { versions = { "latest" } }
  lua_check "backend_list_versions.lua" 'BackendListVersions({})' \
    'if type(r)=="table" and type(r.versions)=="table" and r.versions[1]=="latest" then print("OK") else print("bad list_versions shape") end' \
    "BackendListVersions returns {versions={\"latest\"}}"
  # BackendInstall -> {} (empty table)
  lua_check "backend_install.lua" 'BackendInstall({tool="x", version="latest"})' \
    'if type(r)=="table" and next(r)==nil then print("OK") else print("BackendInstall should return empty table") end' \
    "BackendInstall returns empty table (no-op)"
  # BackendExecEnv -> { env_vars = {} }
  lua_check "backend_exec_env.lua" 'BackendExecEnv({})' \
    'if type(r)=="table" and type(r.env_vars)=="table" and next(r.env_vars)==nil then print("OK") else print("bad exec_env shape") end' \
    "BackendExecEnv returns {env_vars={}}"
else
  skip "plugin hook return-shape checks (no Lua interpreter; structural checks ran)"
fi
