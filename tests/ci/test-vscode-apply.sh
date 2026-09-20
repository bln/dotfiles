#!/usr/bin/env bash
# shellcheck disable=SC2153 # REPO is exported by tests/run.sh
# ci: vscode-profiles APPLY, the genuinely-integration behaviors that need a
# `code` process and storage.json - driven against a fake `code` and the
# VSCODE_* seams. The pure decision logic lives in test-vscode-logic.sh; this
# file asserts the OBSERVABLE contract of apply (what gets installed/pruned,
# what is seeded, when it must abort), not permutations of drift.
#
# Every block needs jq (storage.json math); skips cleanly without it.

echo "== ci: vscode apply =="

CLI="$REPO/scripts/vscode-profiles"

# Fake `code`: logs install/uninstall (id<TAB>profile); --status reflects
# CODE_RUNNING like the real binary (which always exits 0, signalling "closed"
# only via a stderr warning); --list-extensions prints $PRESET for the global.
make_code() {
  cat >"$1/code" <<'EOF'
#!/usr/bin/env bash
prof=""; args=("$@")
for i in "${!args[@]}"; do [ "${args[$i]}" = "--profile" ] && prof="${args[$((i+1))]}"; done
case "$1" in
  --list-extensions) [ -n "$prof" ] || printf '%s\n' $PRESET ;;
  --install-extension)   printf '%s\t%s\n' "$2" "$prof" >>"$CODE_INSTALL_LOG" ;;
  --uninstall-extension) printf '%s\t%s\n' "$2" "$prof" >>"$CODE_UNINSTALL_LOG" ;;
  --status) [ "${CODE_RUNNING:-0}" = 1 ] && echo "Version: 1.0.0" \
    || echo "Warning: can only be used if Code is already running." >&2 ;;
esac
exit 0
EOF
  chmod +x "$1/code"
}

if ! command -v jq >/dev/null 2>&1; then skip "vscode apply (jq not installed)"; return 0; fi

# ── apply: install missing, skip present, warn undeclared; --prune removes ───
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud/globalStorage" "$repo" "$bin"; make_code "$bin"
  printf 'esbenp.prettier-vscode\nms-python.python\n' >"$repo/extensions.txt"
  printf '{"editor.tabSize":2}\n' >"$repo/settings.json"
  ilog="$sb/i.log"; ulog="$sb/u.log"; : >"$ilog"; : >"$ulog"
  common=(env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code"
    PRESET="esbenp.prettier-vscode ms-toolsai.jupyter" CODE_INSTALL_LOG="$ilog" CODE_UNINSTALL_LOG="$ulog")

  run_capture "${common[@]}" bash "$CLI" apply
  assert_eq "apply exits 0" "0" "$RUN_STATUS"
  assert_contains "installs missing ms-python.python" "$(cut -f1 <"$ilog")" "ms-python.python"
  assert_not_contains "skips already-present prettier" "$(cut -f1 <"$ilog")" "esbenp.prettier-vscode"
  assert_eq "default prunes nothing" "" "$(cat "$ulog")"
  assert_contains "warns undeclared jupyter" "$(cat "$RUN_STDERR")" "ms-toolsai.jupyter"
  assert_eq "settings.json copied repo->live" "$(cat "$repo/settings.json")" "$(cat "$ud/settings.json")"

  : >"$ulog"
  run_capture "${common[@]}" bash "$CLI" apply --prune
  assert_contains "--prune removes undeclared jupyter" "$(cut -f1 <"$ulog")" "ms-toolsai.jupyter"
}

# ── seed: a named profile is created (storage.json entry + dir) once, and gets
#    its own ids PLUS the inherited global ids ("globals expected everywhere") ──
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud/globalStorage" "$repo/profiles/pyth" "$bin"; make_code "$bin"
  printf 'golang.go\n' >"$repo/extensions.txt"
  printf 'ms-python.python\n' >"$repo/profiles/pyth/extensions.txt"
  ilog="$sb/i.log"; : >"$ilog"
  common=(env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code"
    PRESET="" CODE_INSTALL_LOG="$ilog")

  if command -v uuidgen >/dev/null 2>&1; then
    run_capture "${common[@]}" bash "$CLI" apply
    assert_eq "apply exits 0" "0" "$RUN_STATUS"
    pyth="$(awk -F'\t' '$2=="pyth"' "$ilog")"
    assert_contains "pyth gets its own python"     "$pyth" "ms-python.python"
    assert_contains "pyth inherits global golang"  "$pyth" "golang.go"
    assert_not_contains "global lacks python" "$(awk -F'\t' '$2==""' "$ilog")" "ms-python.python"
    assert_eq "exactly one pyth entry in storage.json" "1" \
      "$(jq -r '[.userDataProfiles[]|select(.name=="pyth")]|length' "$ud/globalStorage/storage.json")"

    # Idempotent: re-apply must not append a duplicate entry.
    run_capture "${common[@]}" bash "$CLI" apply
    assert_eq "re-apply keeps a single pyth entry" "1" \
      "$(jq -r '[.userDataProfiles[]|select(.name=="pyth")]|length' "$ud/globalStorage/storage.json")"
  else
    skip "seed test (uuidgen not installed)"
  fi
}

# ── running-VS-Code guard aborts BEFORE any change; --force overrides ─────────
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud/globalStorage" "$repo/profiles/pyth" "$bin"; make_code "$bin"
  printf 'golang.go\n' >"$repo/extensions.txt"; printf 'ms-python.python\n' >"$repo/profiles/pyth/extensions.txt"
  ilog="$sb/i.log"; : >"$ilog"
  common=(env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code"
    PRESET="" CODE_INSTALL_LOG="$ilog" CODE_RUNNING=1)

  run_capture "${common[@]}" bash "$CLI" apply
  assert_eq "guard aborts with exit 3" "3" "$RUN_STATUS"
  assert_eq "guard installs nothing" "" "$(cat "$ilog")"
  assert_not_exists "guard writes no storage.json" "$ud/globalStorage/storage.json"
  run_capture "${common[@]}" bash "$CLI" apply --force
  assert_eq "--force overrides the guard" "0" "$RUN_STATUS"
}

# ── a failed extension install is nonzero-but-continues (real error, not a
#    tolerable tool signal, and never a mid-loop abort) ───────────────────────
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud/globalStorage" "$bin" "$repo"
  printf 'golang.go\n' >"$repo/extensions.txt"
  for p in aaa bbb; do mkdir -p "$repo/profiles/$p"; printf 'ext.%s\n' "$p" >"$repo/profiles/$p/extensions.txt"; done
  cat >"$bin/code" <<'EOF'
#!/usr/bin/env bash
prof=""; args=("$@")
for i in "${!args[@]}"; do [ "${args[$i]}" = "--profile" ] && prof="${args[$((i+1))]}"; done
case "$1" in
  --list-extensions) [ -n "$prof" ] || printf '%s\n' $PRESET ;;
  --install-extension) printf '%s\t%s\n' "$2" "$prof" >>"$CODE_INSTALL_LOG"; [ "$2" = "ext.aaa" ] && exit 1 ;;
  --status) echo "Warning: can only be used if Code is already running." >&2 ;;
esac
exit 0
EOF
  chmod +x "$bin/code"; ilog="$sb/i.log"; : >"$ilog"
  if command -v uuidgen >/dev/null 2>&1; then
    run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code" \
      PRESET="" CODE_INSTALL_LOG="$ilog" bash "$CLI" apply
    assert_eq "failed install -> nonzero exit" "1" "$RUN_STATUS"
    assert_contains "continued past the failure to bbb" "$(cut -f1 <"$ilog")" "ext.bbb"
    assert_contains "names the failed install" "$(cat "$RUN_STDERR")" "failed to install ext.aaa"
  else
    skip "install-failure test (uuidgen not installed)"
  fi
}

# ── a failed storage.json write IS fatal (no orphan profile dir) ─────────────
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud/globalStorage" "$bin" "$repo"; make_code "$bin"
  printf 'golang.go\n' >"$repo/extensions.txt"
  mkdir -p "$repo/profiles/pyth"; printf 'ms-python.python\n' >"$repo/profiles/pyth/extensions.txt"
  printf '#!/usr/bin/env bash\nexit 1\n' >"$bin/jq"; chmod +x "$bin/jq"   # force the rewrite to fail
  if command -v uuidgen >/dev/null 2>&1; then
    run_capture env PATH="$bin:$PATH" VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" \
      VSCODE_CODE_BIN="$bin/code" PRESET="" bash "$CLI" apply
    assert_eq "fatal write aborts (nonzero)" "1" "$RUN_STATUS"
    assert_not_exists "no orphan profile dir for an unwritten entry" "$ud/profiles/pyth"
  else
    skip "fatal-write test (uuidgen not installed)"
  fi
}

# ── code absent -> apply no-op exit 0; unknown subcommand -> exit 2 ──────────
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; mkdir -p "$ud" "$repo"
  printf 'a\n' >"$repo/extensions.txt"
  run_capture env PATH="/usr/bin:/bin" VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" \
    VSCODE_CODE_BIN="definitely-not-code" bash "$CLI" apply
  assert_eq "apply no-op when code absent" "0" "$RUN_STATUS"
  run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" bash "$CLI" bogus
  assert_eq "unknown subcommand exits 2" "2" "$RUN_STATUS"
}
