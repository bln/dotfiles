#!/usr/bin/env bash
# shellcheck disable=SC2153 # REPO is exported by tests/run.sh
# ci: vscodectl APPLY, the genuinely-integration behaviors that need a
# `code` process and storage.json - driven against a fake `code` and the
# VSCODE_* seams. The pure decision logic lives in test-vscode-logic.sh; this
# file asserts the OBSERVABLE contract of apply (what gets installed/pruned,
# what is seeded, when it must abort), not permutations of drift.
#
# Every block needs jq (storage.json math); skips cleanly without it.

echo "== ci: vscode apply =="

CLI="$REPO/scripts/vscodectl"

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
  printf '%s\n' '{"editor.fontSize":16,"editor.codeActionsOnSave":{"source.fixAll":"explicit"}}' >"$repo/settings.base.json"
  printf '%s\n' '{"editor.tabSize":2,"editor.codeActionsOnSave":{"source.organizeImports":"explicit"}}' >"$repo/settings.json"
  ilog="$sb/i.log"; ulog="$sb/u.log"; : >"$ilog"; : >"$ulog"
  common=(env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code"
    PRESET="esbenp.prettier-vscode ms-toolsai.jupyter" CODE_INSTALL_LOG="$ilog" CODE_UNINSTALL_LOG="$ulog")

  run_capture "${common[@]}" bash "$CLI" apply
  assert_eq "apply exits 0" "0" "$RUN_STATUS"
  assert_contains "installs missing ms-python.python" "$(cut -f1 <"$ilog")" "ms-python.python"
  assert_not_contains "skips already-present prettier" "$(cut -f1 <"$ilog")" "esbenp.prettier-vscode"
  assert_eq "default prunes nothing" "" "$(cat "$ulog")"
  assert_contains "warns undeclared jupyter" "$(cat "$RUN_STDERR")" "ms-toolsai.jupyter"
  expected="$(jq -S -s '.[0] * .[1]' "$repo/settings.base.json" "$repo/settings.json")"
  assert_eq "settings.json receives rendered base plus override" "$expected" "$(jq -S . "$ud/settings.json")"

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
  printf '%s\n' '{"editor.fontFamily":"JetBrains Mono","editor.codeActionsOnSave":{"source.fixAll":"explicit"}}' >"$repo/settings.base.json"
  printf '%s\n' '{"python.analysis.typeCheckingMode":"basic","editor.codeActionsOnSave":{"source.organizeImports":"always"}}' >"$repo/profiles/pyth/settings.json"
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
    loc="$(jq -r '.userDataProfiles[]|select(.name=="pyth")|.location' "$ud/globalStorage/storage.json")"
    expected="$(jq -S -s '.[0] * .[1]' "$repo/settings.base.json" "$repo/profiles/pyth/settings.json")"
    assert_eq "named profile receives rendered settings" "$expected" \
      "$(jq -S . "$ud/profiles/$loc/settings.json")"

    # Idempotent: re-apply must not append a duplicate entry.
    run_capture "${common[@]}" bash "$CLI" apply
    assert_eq "re-apply keeps a single pyth entry" "1" \
      "$(jq -r '[.userDataProfiles[]|select(.name=="pyth")]|length' "$ud/globalStorage/storage.json")"
  else
    skip "seed test (uuidgen not installed)"
  fi
}

# ── pull: live settings become only the profile delta from the shared base ───
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"
  mkdir -p "$ud" "$repo"
  printf '%s\n' '{"editor.fontSize":16,"editor.codeActionsOnSave":{"source.fixAll":"explicit","source.organizeImports":"explicit"}}' >"$repo/settings.base.json"
  printf '%s\n' '{"editor.fontSize":18,"editor.codeActionsOnSave":{"source.fixAll":"explicit","source.organizeImports":"always"},"rust-analyzer.check.command":"clippy"}' >"$ud/settings.json"
  run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" bash "$CLI" pull
  assert_eq "pull exits 0" "0" "$RUN_STATUS"
  assert_eq "pull stores only settings overrides" \
    '{"editor.codeActionsOnSave":{"source.organizeImports":"always"},"editor.fontSize":18,"rust-analyzer.check.command":"clippy"}' \
    "$(jq -S -c . "$repo/settings.json")"
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

# ── C1 regression: apply replaces a symlinked live settings.json, not writes ──
# through it. A live settings.json that is a symlink must become a real file so
# `check`'s symlink guard can clear; the outside target must be left untouched.
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud" "$repo" "$bin"; make_code "$bin"
  printf '%s\n' '{"editor.fontSize":16}' >"$repo/settings.base.json"
  outside="$sb/outside.json"; printf '%s\n' '{"stolen":true}' >"$outside"
  ln -s "$outside" "$ud/settings.json"
  run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" \
    VSCODE_CODE_BIN="$bin/code" PRESET="" bash "$CLI" apply
  assert_eq "apply exits 0 over a symlinked settings" "0" "$RUN_STATUS"
  if [ -L "$ud/settings.json" ]; then bad "live settings.json is no longer a symlink" "still a symlink"; else ok "live settings.json is no longer a symlink"; fi
  assert_file "live settings.json is a real file" "$ud/settings.json"
  assert_contains "live settings.json holds rendered repo value" "$(cat "$ud/settings.json")" '"editor.fontSize": 16'
  assert_contains "outside target left untouched" "$(cat "$outside")" '{"stolen":true}'
}

# ── C2: apply prunes a live snippet the repo no longer declares ───────────────
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud/snippets" "$repo/snippets" "$bin"; make_code "$bin"
  printf '{}\n' >"$repo/snippets/js.json"          # repo declares js
  printf '{}\n' >"$ud/snippets/js.json"
  printf '{}\n' >"$ud/snippets/stale.json"         # live-only, repo does not declare
  run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" \
    VSCODE_CODE_BIN="$bin/code" PRESET="" bash "$CLI" apply
  assert_eq "apply exits 0 with snippet prune" "0" "$RUN_STATUS"
  assert_file "declared snippet remains live" "$ud/snippets/js.json"
  assert_not_exists "live-only snippet pruned by apply" "$ud/snippets/stale.json"
}

# ── teardown: dry-run default touches nothing (mandatory per docs/TESTING.md) ─
{
  if ! command -v jq >/dev/null 2>&1 || ! command -v uuidgen >/dev/null 2>&1; then
    skip "teardown tests (jq/uuidgen not installed)"
  else
    sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
    mkdir -p "$ud/globalStorage" "$repo" "$bin"; make_code "$bin"
    printf 'golang.go\n' >"$repo/extensions.txt"
    mkdir -p "$repo/profiles/pyth"; printf 'ms-python.python\n' >"$repo/profiles/pyth/extensions.txt"
    ilog="$sb/i.log"; ulog="$sb/u.log"; : >"$ilog"; : >"$ulog"
    common=(env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code"
      PRESET="" CODE_INSTALL_LOG="$ilog" CODE_UNINSTALL_LOG="$ulog")
    # apply first to seed the named profile so teardown has something to remove.
    run_capture "${common[@]}" bash "$CLI" apply
    loc="$("${common[@]}" bash "$CLI" resolve pyth)"
    assert_dir "seeded profile dir exists before teardown" "$ud/profiles/$loc"

    # dry-run default: no --apply. Must touch nothing.
    : >"$ulog"
    run_capture "${common[@]}" bash "$CLI" teardown
    assert_eq "teardown dry-run exits 0" "0" "$RUN_STATUS"
    assert_contains "teardown dry-run announces DRY RUN" "$(cat "$RUN_STDOUT")" "DRY RUN"
    assert_eq "teardown dry-run uninstalls nothing" "" "$(cat "$ulog")"
    assert_dir "teardown dry-run leaves profile dir" "$ud/profiles/$loc"
    assert_contains "teardown dry-run leaves storage entry" "$(cat "$ud/globalStorage/storage.json")" "pyth"

    # --apply: uninstalls declared extensions, removes the storage entry, rm -rf's dir.
    : >"$ulog"
    run_capture "${common[@]}" bash "$CLI" teardown --apply
    assert_eq "teardown --apply exits 0" "0" "$RUN_STATUS"
    assert_contains "teardown --apply uninstalls declared ext" "$(cut -f1 <"$ulog")" "ms-python.python"
    assert_not_exists "teardown --apply removes profile dir" "$ud/profiles/$loc"
    assert_not_contains "teardown --apply removes storage entry" "$(cat "$ud/globalStorage/storage.json")" "pyth"
  fi
}

# ── teardown --apply rm -rf stays inside profiles/ (containment guard) ────────
{
  if ! command -v jq >/dev/null 2>&1 || ! command -v uuidgen >/dev/null 2>&1; then
    skip "teardown containment test (jq/uuidgen not installed)"
  else
    sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
    mkdir -p "$ud/globalStorage" "$repo" "$bin"; make_code "$bin"
    mkdir -p "$repo/profiles/pyth"; printf 'ms-python.python\n' >"$repo/profiles/pyth/extensions.txt"
    common=(env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code" PRESET="")
    run_capture "${common[@]}" bash "$CLI" apply
    # A sentinel beside profiles/ must survive teardown (proves rm -rf is scoped).
    printf 'keep\n' >"$ud/sentinel.txt"
    run_capture "${common[@]}" bash "$CLI" teardown --apply
    assert_eq "teardown --apply exits 0" "0" "$RUN_STATUS"
    assert_file "sentinel outside profiles/ survives teardown" "$ud/sentinel.txt"
  fi
}
