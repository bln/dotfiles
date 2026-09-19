#!/usr/bin/env bash
# Unit: apply-vscode-extensions syncs `code` against the declared extension set
# (FM11 / drift). The declared set is injected via the VSCODE_EXTENSIONS_SOURCE
# seam so no live mise is needed. A fake `code` records install/uninstall calls
# and reports a fixed set as already installed. Runs the REAL script. Asserts:
#   - declared-but-missing extensions ARE installed
#   - declared-and-present extensions are NOT reinstalled (idempotent)
#   - undeclared installed extensions WARN by default, are NOT uninstalled
#   - --prune / VSCODE_EXTENSIONS_PRUNE=true uninstalls undeclared ones
#   - no-op (exit 0) when `code` is absent

echo "== apply-vscode-extensions =="

SCRIPT="$REPO/scripts/apply-vscode-extensions.sh"

# Fake `code`: --list-extensions prints $PREINSTALLED; --install-extension logs
# to $CODE_INSTALL_LOG; --uninstall-extension logs to $CODE_UNINSTALL_LOG.
make_code_shim() {
  local dir="$1"
  cat >"$dir/code" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  --list-extensions)     printf '%s\n' $PREINSTALLED ;;
  --install-extension)   printf '%s\n' "$2" >>"$CODE_INSTALL_LOG" ;;
  --uninstall-extension) printf '%s\n' "$2" >>"$CODE_UNINSTALL_LOG" ;;
esac
exit 0
EOF
  chmod +x "$dir/code"
}

sb="$(sandbox)"
bindir="$sb/bin"; mkdir -p "$bindir"
make_code_shim "$bindir"
ilog="$sb/install.log"
ulog="$sb/uninstall.log"

# Declared set injected via the source seam.
# esbenp.prettier-vscode is declared AND installed; ms-python.python and
# editorconfig.editorconfig are declared but missing. ms-toolsai.jupyter is
# installed but NOT declared (prune candidate).
DECLARED='printf "%s\n" esbenp.prettier-vscode ms-python.python EditorConfig.EditorConfig'
PRESET="esbenp.prettier-vscode ms-toolsai.jupyter"

run_sync() {
  # Usage: run_sync [ENV=val ...] [-- --flag ...]
  local -a env_args=() script_args=()
  local past_sep=false
  for arg in "$@"; do
    if [ "$arg" = "--" ]; then past_sep=true; continue; fi
    if $past_sep; then script_args+=("$arg"); else env_args+=("$arg"); fi
  done
  : >"$ilog"; : >"$ulog"
  run_capture env \
    PATH="$bindir:/usr/bin:/bin" \
    PREINSTALLED="$PRESET" \
    CODE_INSTALL_LOG="$ilog" \
    CODE_UNINSTALL_LOG="$ulog" \
    VSCODE_EXTENSIONS_SOURCE="$DECLARED" \
    "${env_args[@]+"${env_args[@]}"}" \
    bash "$SCRIPT" "${script_args[@]+"${script_args[@]}"}"
}

# ── default: install missing, skip present, warn (not prune) undeclared ──────
run_sync
assert_eq "exits 0" "0" "$RUN_STATUS"
installed="$(cat "$ilog")"
assert_contains "installs missing ms-python.python" "$installed" "ms-python.python"
assert_contains "installs missing editorconfig (normalized)" "$installed" "editorconfig.editorconfig"
assert_not_contains "does not reinstall present prettier" "$installed" "esbenp.prettier-vscode"
assert_eq "default does not uninstall anything" "" "$(cat "$ulog")"
assert_contains "warns about undeclared jupyter" "$(cat "$RUN_STDERR")" "ms-toolsai.jupyter"

# ── PRUNE=true: uninstall undeclared, leave declared ─────────────────────────
run_sync VSCODE_EXTENSIONS_PRUNE=true
assert_eq "prune exits 0" "0" "$RUN_STATUS"
assert_contains "prunes undeclared jupyter" "$(cat "$ulog")" "ms-toolsai.jupyter"
assert_not_contains "does not prune declared prettier" "$(cat "$ulog")" "esbenp.prettier-vscode"

# ── --prune flag equals the env var ──────────────────────────────────────────
run_sync -- --prune
assert_eq "--prune exits 0" "0" "$RUN_STATUS"
assert_contains "--prune flag uninstalls undeclared" "$(cat "$ulog")" "ms-toolsai.jupyter"

# ── no `code` on PATH -> clean no-op (exit 0) ────────────────────────────────
run_capture env PATH="/usr/bin:/bin" VSCODE_EXTENSIONS_SOURCE="$DECLARED" bash "$SCRIPT"
assert_eq "no-op exit 0 when code absent" "0" "$RUN_STATUS"

# ── unknown argument -> exit 2 ───────────────────────────────────────────────
run_capture env PATH="$bindir:/usr/bin:/bin" bash "$SCRIPT" --bogus
assert_eq "unknown arg exits 2" "2" "$RUN_STATUS"

# ── default enumeration path: real `mise ls -c --json | jq` (no source seam) ─
# Guards against mise JSON-shape / jq-filter drift.
if command -v jq >/dev/null 2>&1; then
  edir="$(sandbox)"; ebin="$edir/bin"; mkdir -p "$ebin"
  make_code_shim "$ebin"
  cat >"$ebin/mise" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"ls -c --json"*|*"ls --json -c"*) cat "$MISE_LS_JSON" ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$ebin/mise"
  lsjson="$edir/ls.json"
  cat >"$lsjson" <<'EOF'
{
  "node": [{"version":"22.0.0","requested_version":"lts","installed":true,"active":true}],
  "vscode-ext:esbenp.prettier-vscode": [{"version":"latest","requested_version":"latest","installed":true,"active":true}],
  "vscode-ext:ms-python.python": [{"version":"latest","requested_version":"latest","installed":true,"active":true}],
  "jq": [{"version":"1.7.1","requested_version":"latest","installed":true,"active":true}]
}
EOF
  eilog="$edir/install.log"; eulog="$edir/uninstall.log"
  run_capture env \
    PATH="$ebin:/usr/bin:/bin" \
    PREINSTALLED="" \
    CODE_INSTALL_LOG="$eilog" \
    CODE_UNINSTALL_LOG="$eulog" \
    MISE_LS_JSON="$lsjson" \
    bash "$SCRIPT"
  assert_eq "default-path exits 0" "0" "$RUN_STATUS"
  di="$(cat "$eilog")"
  assert_contains "default path enumerates prettier from mise json" "$di" "esbenp.prettier-vscode"
  assert_contains "default path enumerates ms-python.python from mise json" "$di" "ms-python.python"
  assert_not_contains "default path strips vscode-ext: prefix" "$di" "vscode-ext:"
  assert_not_contains "default path ignores non-extension tools (node)" "$di" "node"
else
  skip "default enumeration path (jq not installed)"
fi
