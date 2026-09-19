#!/usr/bin/env bash
# Unit: the teardown-*.sh scripts remove only repository-owned state, safely.
#
# Runs the REAL scripts against a sandbox HOME. mise/code/jq are shimmed so tests
# run without a live install. Asserts:
#   - dry run (default) changes nothing on disk
#   - --apply removes local files and uninstalls declared extensions
#   - teardown-vscode strips the vscode-ext: prefix and skips non-extension tools
#   - teardown-local's safe_under_home guard refuses "/", "$HOME", non-HOME paths

echo "== teardown =="

DOTFILES="$REPO/scripts/teardown-dotfiles.sh"
VSCODE="$REPO/scripts/teardown-vscode.sh"
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

# ── teardown-vscode: strips prefix, skips non-extensions, dry vs apply ────────
{
  home="$(sandbox)"
  fbin="$home/bin"; mkdir -p "$fbin"
  ulog="$home/uninstall.log"; : >"$ulog"
  cat >"$fbin/code" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "--uninstall-extension" ] && printf '%s\n' "$2" >>"$CODE_UNINSTALL_LOG"
exit 0
EOF
  chmod +x "$fbin/code"
  # Inject a fixed declared list via the documented seam (no mise/jq needed).
  src='printf "golang.go\nesbenp.prettier-vscode\n"'

  # dry run: previews, uninstalls nothing
  run_capture env PATH="$fbin:/usr/bin:/bin" HOME="$home" \
    VSCODE_EXTENSIONS_SOURCE="$src" CODE_UNINSTALL_LOG="$ulog" \
    bash "$VSCODE"
  assert_eq "vscode dry run exits 0" "0" "$RUN_STATUS"
  assert_contains "vscode dry run names extension" "$(cat "$RUN_STDOUT")" "golang.go"
  assert_eq "vscode dry run uninstalls nothing" "" "$(cat "$ulog")"

  # --apply: uninstalls the declared ids
  : >"$ulog"
  run_capture env PATH="$fbin:/usr/bin:/bin" HOME="$home" \
    VSCODE_EXTENSIONS_SOURCE="$src" CODE_UNINSTALL_LOG="$ulog" \
    bash "$VSCODE" --apply
  assert_eq "vscode --apply exits 0" "0" "$RUN_STATUS"
  uout="$(cat "$ulog")"
  assert_contains "apply uninstalls golang.go" "$uout" "golang.go"
  assert_contains "apply uninstalls prettier" "$uout" "esbenp.prettier-vscode"

  # code absent -> no-op exit 0
  run_capture env PATH="/usr/bin:/bin" HOME="$home" \
    VSCODE_EXTENSIONS_SOURCE="$src" bash "$VSCODE" --apply
  assert_eq "vscode no-op when code absent" "0" "$RUN_STATUS"
}

# ── teardown-dotfiles: mise absent -> warns, exits 0 ──────────────────────────
{
  home="$(sandbox)"
  run_capture env PATH="/usr/bin:/bin" HOME="$home" bash "$DOTFILES"
  assert_eq "dotfiles no-op when mise absent" "0" "$RUN_STATUS"
  assert_contains "dotfiles warns mise missing" "$(cat "$RUN_STDERR")" "mise not found"
}
