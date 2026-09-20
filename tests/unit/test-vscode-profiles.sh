#!/usr/bin/env bash
# Unit: scripts/vscode-profiles apply/check logic against a sandbox, with a fake
# `code` (no live VS Code) and the VSCODE_* seams. Runs the REAL shipped CLI.
# Asserts:
#   - apply installs declared-but-missing, skips present, warns (not prunes)
#     undeclared by default; --prune uninstalls undeclared
#   - profile files (settings.json) are copied repo -> live
#   - named profiles are seeded (storage.json + dir) and get globals + own exts
#   - the running-VS-Code guard aborts apply before any change; --force overrides
#   - check reports match / drift / missing / symlink states
#   - unknown subcommand -> exit 2; code absent -> apply no-op exit 0

echo "== vscode-profiles =="

CLI="$REPO/scripts/vscode-profiles"

# Fake `code`: --list-extensions prints $PRESET; install/uninstall log to files;
# --status reflects $CODE_RUNNING - it mimics the real binary, which ALWAYS
# exits 0 and only signals "closed" via a stderr warning. CODE_RUNNING=1 =>
# running (diagnostics, no warning); unset/0 => closed (emit the warning).
make_code() {
  cat >"$1/code" <<'EOF'
#!/usr/bin/env bash
# Track a --profile selector so tests can see per-profile calls.
prof=""
args=("$@")
for i in "${!args[@]}"; do
  [ "${args[$i]}" = "--profile" ] && prof="${args[$((i+1))]}"
done
case "$1" in
  --list-extensions) printf '%s\n' $PRESET ;;
  --install-extension)   printf '%s\t%s\n' "$2" "$prof" >>"$CODE_INSTALL_LOG" ;;
  --uninstall-extension) printf '%s\t%s\n' "$2" "$prof" >>"$CODE_UNINSTALL_LOG" ;;
  --status)
    if [ "${CODE_RUNNING:-0}" = 1 ]; then
      echo "Version: 1.0.0"
    else
      echo "Warning: The --status argument can only be used if Code is already running. Please run it again after Code has started." >&2
    fi ;;
esac
exit 0
EOF
  chmod +x "$1/code"
}

# ── global profile: install missing, skip present, warn undeclared ───────────
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud" "$repo" "$bin"
  make_code "$bin"
  printf '{"editor.tabSize":2}\n' >"$repo/settings.json"
  printf 'esbenp.prettier-vscode\nms-python.python\n# c\nEditorConfig.EditorConfig\n' >"$repo/extensions.txt"
  ilog="$sb/i.log"; ulog="$sb/u.log"; : >"$ilog"; : >"$ulog"

  common=(env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code"
    PRESET="esbenp.prettier-vscode ms-toolsai.jupyter"
    CODE_INSTALL_LOG="$ilog" CODE_UNINSTALL_LOG="$ulog")

  run_capture "${common[@]}" bash "$CLI" apply
  assert_eq "apply exits 0" "0" "$RUN_STATUS"
  inst="$(cut -f1 <"$ilog")"
  assert_contains "installs missing ms-python.python" "$inst" "ms-python.python"
  assert_contains "installs missing editorconfig (normalized)" "$inst" "editorconfig.editorconfig"
  assert_not_contains "skips present prettier" "$inst" "esbenp.prettier-vscode"
  assert_eq "default uninstalls nothing" "" "$(cat "$ulog")"
  assert_contains "warns undeclared jupyter" "$(cat "$RUN_STDERR")" "ms-toolsai.jupyter"
  assert_eq "settings.json copied repo->live" "$(cat "$repo/settings.json")" "$(cat "$ud/settings.json")"

  # --prune uninstalls the undeclared one, keeps declared
  : >"$ilog"; : >"$ulog"
  run_capture "${common[@]}" bash "$CLI" apply --prune
  assert_eq "prune exits 0" "0" "$RUN_STATUS"
  assert_contains "prunes undeclared jupyter" "$(cut -f1 <"$ulog")" "ms-toolsai.jupyter"
  assert_not_contains "does not prune declared prettier" "$(cut -f1 <"$ulog")" "esbenp.prettier-vscode"
}

# ── named profile: seed + globals-expected-everywhere ────────────────────────
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud/globalStorage" "$repo/profiles/pyth" "$bin"
  make_code "$bin"
  printf 'golang.go\n' >"$repo/extensions.txt"
  printf 'ms-python.python\n' >"$repo/profiles/pyth/extensions.txt"
  ilog="$sb/i.log"; : >"$ilog"

  if command -v jq >/dev/null 2>&1 && command -v uuidgen >/dev/null 2>&1; then
    run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code" \
      PRESET="" CODE_INSTALL_LOG="$ilog" bash "$CLI" apply
    assert_eq "apply w/ profile exits 0" "0" "$RUN_STATUS"
    # pyth gets its own ext AND the global (globals expected everywhere)
    pyth_installs="$(grep -P '\tpyth$' "$ilog" 2>/dev/null || awk -F'\t' '$2=="pyth"' "$ilog")"
    assert_contains "pyth gets own ms-python.python" "$pyth_installs" "ms-python.python"
    assert_contains "pyth gets global golang.go" "$pyth_installs" "golang.go"
    # global profile does NOT get python
    global_installs="$(awk -F'\t' '$2==""' "$ilog")"
    assert_not_contains "global lacks python" "$global_installs" "ms-python.python"
    # profile was seeded
    assert_dir "pyth profile dir created" "$ud/profiles/$(jq -r '.userDataProfiles[0].location' "$ud/globalStorage/storage.json")"
    assert_eq "resolve prints pyth location" \
      "$(jq -r '.userDataProfiles[0].location' "$ud/globalStorage/storage.json")" \
      "$(env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" bash "$CLI" resolve pyth)"
  else
    skip "named-profile seeding (jq/uuidgen not installed)"
  fi
}

# ── seed idempotency + resolve against a pre-existing storage.json ────────────
# apply must not create a second userDataProfiles entry for an already-seeded
# name, and resolve must round-trip an existing entry (the jq read/write math).
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud/globalStorage" "$repo/profiles/pyth" "$bin"
  make_code "$bin"
  printf 'golang.go\n' >"$repo/extensions.txt"
  printf 'ms-python.python\n' >"$repo/profiles/pyth/extensions.txt"
  # Pre-seed pyth so apply should reuse it, not append a duplicate.
  printf '{"userDataProfiles":[{"location":"pyth0001","name":"pyth"}]}\n' \
    >"$ud/globalStorage/storage.json"
  mkdir -p "$ud/profiles/pyth0001"
  ilog="$sb/i.log"; : >"$ilog"

  if command -v jq >/dev/null 2>&1; then
    assert_eq "resolve round-trips existing entry" "pyth0001" \
      "$(env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" bash "$CLI" resolve pyth)"

    run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code" \
      PRESET="" CODE_INSTALL_LOG="$ilog" bash "$CLI" apply
    assert_eq "apply over seeded profile exits 0" "0" "$RUN_STATUS"
    assert_eq "no duplicate userDataProfiles entry" "1" \
      "$(jq -r '[.userDataProfiles[] | select(.name=="pyth")] | length' "$ud/globalStorage/storage.json")"
    assert_eq "location unchanged after re-apply" "pyth0001" \
      "$(jq -r '.userDataProfiles[] | select(.name=="pyth") | .location' "$ud/globalStorage/storage.json")"
    # effective_declared: pyth (own ∪ global) installs into the SEEDED location,
    # not a new one; global profile still lacks python.
    pyth_installs="$(awk -F'\t' '$2=="pyth"' "$ilog")"
    assert_contains "seeded pyth gets own python" "$pyth_installs" "ms-python.python"
    assert_contains "seeded pyth inherits global golang.go" "$pyth_installs" "golang.go"
    assert_not_contains "global still lacks python" "$(awk -F'\t' '$2==""' "$ilog")" "ms-python.python"
  else
    skip "seed idempotency (jq not installed)"
  fi
}

# ── running-VS-Code guard aborts apply before any change ─────────────────────
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud/globalStorage" "$repo/profiles/pyth" "$bin"
  make_code "$bin"
  printf 'golang.go\n' >"$repo/extensions.txt"
  printf 'ms-python.python\n' >"$repo/profiles/pyth/extensions.txt"
  ilog="$sb/i.log"; : >"$ilog"

  if command -v jq >/dev/null 2>&1; then
    run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code" \
      PRESET="" CODE_INSTALL_LOG="$ilog" CODE_RUNNING=1 bash "$CLI" apply
    assert_eq "guard aborts with exit 3" "3" "$RUN_STATUS"
    assert_contains "guard names the cause" "$(cat "$RUN_STDERR")" "VS Code appears to be running"
    assert_eq "guard installs nothing" "" "$(cat "$ilog")"
    assert_not_exists "guard leaves storage.json unwritten" "$ud/globalStorage/storage.json"

    # --force overrides the guard
    run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code" \
      PRESET="" CODE_INSTALL_LOG="$ilog" CODE_RUNNING=1 bash "$CLI" apply --force
    assert_eq "force overrides guard (exit 0)" "0" "$RUN_STATUS"
  else
    skip "guard test (jq not installed)"
  fi
}

# ── check: match / drift / missing / symlink ─────────────────────────────────
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"
  mkdir -p "$ud" "$repo"
  printf 'x\n' >"$repo/settings.json"
  printf 'a\n' >"$repo/extensions.txt"

  # missing live -> warn to apply, exit 0
  run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" bash "$CLI" check
  assert_eq "check missing exits 0" "0" "$RUN_STATUS"
  assert_contains "check missing warns apply" "$(cat "$RUN_STDERR")" "vscode-profiles apply"

  # matching -> OK exit 0
  printf 'x\n' >"$ud/settings.json"
  run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" bash "$CLI" check
  assert_eq "check match exits 0" "0" "$RUN_STATUS"
  assert_contains "check match says OK" "$(cat "$RUN_STDOUT")" "match the repo copy"

  # drift -> warn with pull path, exit 0
  printf 'y\n' >"$ud/settings.json"
  run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" bash "$CLI" check
  assert_eq "check drift exits 0" "0" "$RUN_STATUS"
  assert_contains "check drift names pull" "$(cat "$RUN_STDERR")" "vscode-profiles pull"

  # symlink -> error exit 1
  rm -f "$ud/settings.json"; ln -s "$repo/settings.json" "$ud/settings.json"
  run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" bash "$CLI" check
  assert_eq "check symlink exits 1" "1" "$RUN_STATUS"
  assert_contains "check symlink flags copy mode" "$(cat "$RUN_STDERR")" "copy mode"
}

# ── code absent -> apply no-op exit 0; unknown subcommand -> exit 2 ───────────
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; mkdir -p "$ud" "$repo"
  printf 'a\n' >"$repo/extensions.txt"
  run_capture env PATH="/usr/bin:/bin" VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" \
    VSCODE_CODE_BIN="definitely-not-code" bash "$CLI" apply
  assert_eq "apply no-op when code absent" "0" "$RUN_STATUS"

  run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" bash "$CLI" bogus
  assert_eq "unknown subcommand exits 2" "2" "$RUN_STATUS"
}
