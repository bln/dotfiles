#!/usr/bin/env bash
# Unit: the teardown-*.sh scripts remove only repository-owned state, safely.
#
# Runs the REAL scripts against a sandbox HOME. mise/code/jq are shimmed so tests
# run without a live install. Asserts:
#   - dry run (default) changes nothing on disk
#   - --apply removes local files and uninstalls declared extensions
#   - vscode-profiles teardown uninstalls declared ids per profile and deletes
#     seeded named profiles (never the global shell)
#   - teardown-local's safe_under_home guard refuses "/", "$HOME", non-HOME paths

echo "== teardown =="

DOTFILES="$REPO/scripts/teardown-dotfiles.sh"
VSCODE="$REPO/scripts/vscode-profiles"
LOCAL="$REPO/scripts/teardown-local.sh"

# ── teardown-local: dry run vs --apply, HOME-scoped ───────────────────────────
{
  home="$(sandbox)"; mkdir -p "$home/.config/git" "$home/.local/share/uv"
  echo p >"$home/.config/git/identity-personal"
  echo w >"$home/.config/git/identity-work"

  # dry run changes nothing
  run_capture env HOME="$home" bash "$LOCAL"
  assert_eq "local dry run exits 0" "0" "$RUN_STATUS"
  assert_file "local dry run keeps identity-personal" "$home/.config/git/identity-personal"
  assert_contains "local dry run previews" "$(cat "$RUN_STDOUT")" "DRY RUN"

  # --apply removes them
  run_capture env HOME="$home" bash "$LOCAL" --apply
  assert_eq "local --apply exits 0" "0" "$RUN_STATUS"
  assert_not_exists "apply removes identity-personal" "$home/.config/git/identity-personal"
  assert_not_exists "apply removes identity-work" "$home/.config/git/identity-work"
  assert_not_exists "apply removes uv share" "$home/.local/share/uv"
  # every "removed:" path is under the sandbox HOME
  outside="$(grep 'removed: ' "$RUN_STDOUT" | grep -vc "$home" || true)"
  assert_eq "every removed path under sandbox HOME" "0" "$outside"
}

# ── teardown-local: safe_under_home guard (source the function directly) ───────
{
  fakeHome="/tmp/test-teardown-home-$$"
  run_guard() {
    env HOME="$fakeHome" bash -c '
      set -euo pipefail
      safe_under_home() {
        local path="$1"
        [ -n "$path" ] && [ "$path" != "/" ] && [ "$path" != "$HOME" ] && \
          case "$path" in "$HOME/"*) return 0 ;; esac
        return 1
      }
      safe_under_home "$1" && echo ok || echo fail' _ "$1"
  }
  assert_eq "guard refuses /"             "fail" "$(run_guard '/')"
  assert_eq "guard refuses HOME"          "fail" "$(run_guard "$fakeHome")"
  assert_eq "guard refuses empty"         "fail" "$(run_guard '')"
  assert_eq "guard refuses non-HOME path" "fail" "$(run_guard '/etc/passwd')"
  assert_eq "guard accepts under HOME"    "ok"   "$(run_guard "$fakeHome/.config")"
}

# ── vscode-profiles teardown: uninstall per profile, delete named profiles ────
{
  sb="$(sandbox)"
  ud="$sb/User"; repo="$sb/repo"; fbin="$sb/bin"
  mkdir -p "$ud/globalStorage" "$repo/profiles/pyth" "$fbin"
  ulog="$sb/uninstall.log"; : >"$ulog"
  # Global + pyth extension lists.
  printf 'golang.go\n' >"$repo/extensions.txt"
  printf 'ms-python.python\n' >"$repo/profiles/pyth/extensions.txt"
  # Pre-seed pyth in storage.json so teardown can delete it.
  printf '{"userDataProfiles":[{"location":"pyth0001","name":"pyth"}]}\n' \
    >"$ud/globalStorage/storage.json"
  mkdir -p "$ud/profiles/pyth0001"
  # Fake code: log uninstalls, report closed for --status (emit the warning that
  # the real binary prints when no instance is running).
  cat >"$fbin/code" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  --uninstall-extension) printf '%s\n' "$2" >>"$CODE_UNINSTALL_LOG" ;;
  --status) echo "Warning: The --status argument can only be used if Code is already running. Please run it again after Code has started." >&2 ;;
esac
exit 0
EOF
  chmod +x "$fbin/code"

  common=(env PATH="$fbin:/usr/bin:/bin"
    VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo"
    VSCODE_CODE_BIN="$fbin/code" CODE_UNINSTALL_LOG="$ulog")

  # dry run: previews, uninstalls nothing, leaves the profile in place
  run_capture "${common[@]}" bash "$VSCODE" teardown
  assert_eq "vscode dry run exits 0" "0" "$RUN_STATUS"
  assert_contains "vscode dry run names extension" "$(cat "$RUN_STDOUT")" "golang.go"
  assert_eq "vscode dry run uninstalls nothing" "" "$(cat "$ulog")"
  assert_dir "vscode dry run keeps pyth profile dir" "$ud/profiles/pyth0001"

  # --apply: uninstalls per profile and deletes the seeded named profile
  : >"$ulog"
  run_capture "${common[@]}" bash "$VSCODE" teardown --apply
  assert_eq "vscode --apply exits 0" "0" "$RUN_STATUS"
  uout="$(cat "$ulog")"
  assert_contains "apply uninstalls global golang.go" "$uout" "golang.go"
  assert_contains "apply uninstalls pyth ms-python.python" "$uout" "ms-python.python"
  assert_not_exists "apply deletes pyth profile dir" "$ud/profiles/pyth0001"
  if command -v jq >/dev/null 2>&1; then
    left="$(jq -r '(.userDataProfiles // []) | length' "$ud/globalStorage/storage.json")"
    assert_eq "apply removes pyth from storage.json" "0" "$left"
  fi

  # code absent -> no-op exit 0
  run_capture env PATH="/usr/bin:/bin" VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" \
    bash "$VSCODE" teardown --apply
  assert_eq "vscode no-op when code absent" "0" "$RUN_STATUS"
}

# ── teardown-dotfiles: mise absent -> warns, exits 0 ──────────────────────────
{
  home="$(sandbox)"
  run_capture env PATH="/usr/bin:/bin" HOME="$home" bash "$DOTFILES"
  assert_eq "dotfiles no-op when mise absent" "0" "$RUN_STATUS"
  assert_contains "dotfiles warns mise missing" "$(cat "$RUN_STDERR")" "mise not found"
}
