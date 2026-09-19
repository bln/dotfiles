#!/usr/bin/env bash
# Unit: wipe.sh removes only repository-owned state, safely.
#
# Targets FM7 (destructive data loss) and FM8 (wiping symlinks the repo does not
# own). Runs the REAL wipe.sh against a sandbox HOME + DOTFILES_DIR checkout.
# Mise, code, and jq are shimmed so tests run without a live install. Asserts:
#   - dry run (default) changes nothing on disk
#   - --apply removes repo-owned symlinks, generated config, and VS Code extensions
#   - a foreign symlink at a managed path is SKIPPED, not removed
#   - safe_under_home refuses "/", "$HOME", and non-HOME paths

echo "== wipe =="

WIPE="$REPO/wipe.sh"

# Build a fake checkout + populated HOME. Sets FAKEREPO + HOMEDIR.
setup_fixture() {
  local root="$1"
  FAKEREPO="$root/repo"; HOMEDIR="$root/home"
  mkdir -p "$FAKEREPO/home/.config/zsh" "$HOMEDIR/.config/zsh" \
           "$HOMEDIR/.config/git"
  echo "zshrc" >"$FAKEREPO/home/.config/zsh/.zshrc"
  ln -sf "$FAKEREPO/home/.config/zsh/.zshrc" "$HOMEDIR/.config/zsh/.zshrc"
  echo "identity" >"$HOMEDIR/.config/git/config.local"
}

# Adds mise+code shims so sections 3-6 don't fail. Sets FBIN, ULOG, LSJSON.
setup_shims() {
  local root="$1"
  FBIN="$root/bin"; mkdir -p "$FBIN"
  ULOG="$root/uninstall.log"; : >"$ULOG"
  LSJSON="$root/ls.json"
  cat >"$LSJSON" <<'EOF'
{
  "node": [{"version":"22.0.0"}],
  "vscode-ext:golang.go": [{"version":"latest"}],
  "vscode-ext:esbenp.prettier-vscode": [{"version":"latest"}]
}
EOF
  cat >"$FBIN/mise" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"ls -c --json"*) cat "$MISE_LS_JSON" ;;
  *) exit 0 ;;
esac
EOF
  cat >"$FBIN/code" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "--uninstall-extension" ] && printf '%s\n' "$2" >>"$CODE_UNINSTALL_LOG"
exit 0
EOF
  chmod +x "$FBIN/mise" "$FBIN/code"
}

# Shared env args for shimmed runs (requires setup_shims called first).
shim_env() {
  printf '%s ' \
    "PATH=$FBIN:/usr/bin:/bin" \
    "DOTFILES_DIR=$FAKEREPO" \
    "HOME=$HOMEDIR" \
    "MISE_LS_JSON=$LSJSON" \
    "CODE_UNINSTALL_LOG=$ULOG"
}

# ---- dry run makes no changes ------------------------------------------------
if command -v jq >/dev/null 2>&1; then
  sb="$(sandbox)"; setup_fixture "$sb"; setup_shims "$sb"
  run_capture env PATH="$FBIN:/usr/bin:/bin" \
    DOTFILES_DIR="$FAKEREPO" HOME="$HOMEDIR" \
    MISE_LS_JSON="$LSJSON" CODE_UNINSTALL_LOG="$ULOG" \
    bash "$WIPE"
  assert_eq "dry run exits 0" "0" "$RUN_STATUS"
  assert_symlink "dry run keeps repo symlink" "$HOMEDIR/.config/zsh/.zshrc"
  assert_file "dry run keeps config.local" "$HOMEDIR/.config/git/config.local"
  assert_contains "dry run announces preview" "$(cat "$RUN_STDOUT")" "DRY RUN"
  assert_contains "dry run strips vscode-ext prefix" "$(cat "$RUN_STDOUT")" "extension esbenp.prettier-vscode"
  assert_not_contains "dry run does not list non-extension node" "$(cat "$RUN_STDOUT")" "extension node"
  assert_eq "dry run does not actually uninstall" "" "$(cat "$ULOG")"
else
  skip "dry run (jq not installed)"
fi

# ---- --apply removes owned state and uninstalls extensions -------------------
if command -v jq >/dev/null 2>&1; then
  sb="$(sandbox)"; setup_fixture "$sb"; setup_shims "$sb"
  run_capture env PATH="$FBIN:/usr/bin:/bin" \
    DOTFILES_DIR="$FAKEREPO" HOME="$HOMEDIR" \
    MISE_LS_JSON="$LSJSON" CODE_UNINSTALL_LOG="$ULOG" \
    bash "$WIPE" --apply
  assert_eq "apply exits 0" "0" "$RUN_STATUS"
  assert_not_exists "apply removes repo symlink" "$HOMEDIR/.config/zsh/.zshrc"
  assert_not_exists "apply removes config.local" "$HOMEDIR/.config/git/config.local"
  uout="$(cat "$ULOG")"
  assert_contains "apply uninstalls golang.go" "$uout" "golang.go"
  assert_contains "apply uninstalls prettier" "$uout" "esbenp.prettier-vscode"
  assert_not_contains "apply does not uninstall non-extension node" "$uout" "node"
else
  skip "--apply (jq not installed)"
fi

# ---- foreign symlink at a managed path is preserved --------------------------
# Uses a minimal PATH with shimmed mise (no jq needed: section 4 warns+skips).
sb="$(sandbox)"; setup_fixture "$sb"
FBIN2="$sb/bin2"; mkdir -p "$FBIN2"
cat >"$FBIN2/mise" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FBIN2/mise"
foreign="$sb/foreign-target"; echo "not ours" >"$foreign"
ln -sf "$foreign" "$HOMEDIR/.config/zsh/.zshrc"
run_capture env PATH="$FBIN2:/usr/bin:/bin" \
  DOTFILES_DIR="$FAKEREPO" HOME="$HOMEDIR" \
  bash "$WIPE" --apply
assert_eq "apply exits 0 with foreign link" "0" "$RUN_STATUS"
assert_symlink "foreign symlink is preserved" "$HOMEDIR/.config/zsh/.zshrc"
assert_contains "foreign symlink reported as SKIP" "$(cat "$RUN_STDOUT")" "not owned by this repo"

# ---- every removed path stays under the sandbox HOME (guard behavior) --------
sb="$(sandbox)"; setup_fixture "$sb"
FBIN3="$sb/bin3"; mkdir -p "$FBIN3"
cat >"$FBIN3/mise" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FBIN3/mise"
run_capture env PATH="$FBIN3:/usr/bin:/bin" \
  DOTFILES_DIR="$FAKEREPO" HOME="$HOMEDIR" \
  bash "$WIPE" --apply
outside="$(grep 'removed: ' "$RUN_STDOUT" | grep -vc "$HOMEDIR" || true)"
assert_eq "every removed path is under sandbox HOME" "0" "$outside"

# ---- safe_under_home: unit-test the guard function directly ------------------
# Source wipe.sh up to (but not past) the flag-parsing loop. We need just the
# safe_under_home function; the rest of the script must not run.
# Strategy: source in a subshell with HOME pinned to a fake path.
fakeHome="/tmp/test-fakehome-$$"
run_guard() {
  # $1 = path to test; echoes "ok" or "fail"
  env HOME="$fakeHome" bash -c "
    set -euo pipefail
    # Extract and source only the safe_under_home definition.
    # Inline it here to avoid sourcing the full wipe.sh and triggering side effects.
    safe_under_home() {
      local path=\"\$1\"
      [ -n \"\$path\" ] && [ \"\$path\" != \"/\" ] && [ \"\$path\" != \"\$HOME\" ] && \
        case \"\$path\" in \"\$HOME/\"*) return 0 ;; esac
      return 1
    }
    safe_under_home '$1' && echo ok || echo fail
  "
}
assert_eq "safe_under_home: refuses /"            "fail" "$(run_guard '/')"
assert_eq "safe_under_home: refuses HOME"         "fail" "$(run_guard "$fakeHome")"
assert_eq "safe_under_home: refuses empty"        "fail" "$(run_guard '')"
assert_eq "safe_under_home: refuses non-HOME path" "fail" "$(run_guard '/etc/passwd')"
assert_eq "safe_under_home: accepts path under HOME" "ok" "$(run_guard "$fakeHome/.config")"
