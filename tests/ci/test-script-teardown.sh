#!/usr/bin/env bash
# shellcheck disable=SC2153 # REPO is exported by tests/run.sh
# ci: teardown removes ONLY repository-owned state, and its rm-scope guard
# refuses anything outside HOME. This is destructive code; the guard is the
# data-loss safety net, so it and the dry-run default are the priority.
#
# Seam: HOME points at a sandbox; the REAL safe_under_home is sourced (the
# script's bottom BASH_SOURCE guard makes sourcing load-only), never copied.

echo "== ci: teardown =="

LOCAL="$REPO/scripts/teardown-local.sh"
DOTFILES="$REPO/scripts/teardown-dotfiles.sh"

# ── dry-run default vs --apply, HOME-scoped ──────────────────────────────────
{
  home="$(sandbox)"; mkdir -p "$home/.config/git" "$home/.local/share/uv" "$home/.local/bin"
  echo p >"$home/.config/git/identity-personal"
  echo w >"$home/.config/git/identity-work"
  # uv python install --default leaves a ~/.local/bin/python symlink; teardown
  # must remove it. Point it at a real file under HOME so the guard accepts it.
  echo py >"$home/.local/share/uv/python-real"
  ln -s "$home/.local/share/uv/python-real" "$home/.local/bin/python"

  run_capture env HOME="$home" bash "$LOCAL"
  assert_eq "dry-run exits 0" "0" "$RUN_STATUS"
  assert_file "dry-run keeps identity-personal" "$home/.config/git/identity-personal"
  assert_contains "dry-run previews" "$(cat "$RUN_STDOUT")" "DRY RUN"

  run_capture env HOME="$home" bash "$LOCAL" --apply
  assert_eq "--apply exits 0" "0" "$RUN_STATUS"
  assert_not_exists "apply removes identity-personal" "$home/.config/git/identity-personal"
  assert_not_exists "apply removes uv share" "$home/.local/share/uv"
  assert_not_exists "apply removes uv python symlink" "$home/.local/bin/python"
  outside="$(grep 'removed: ' "$RUN_STDOUT" | grep -vc "$home" || true)"
  assert_eq "every removed path under sandbox HOME" "0" "$outside"

  # A user-managed executable at the same conventional path is not the uv
  # symlink and must survive teardown.
  printf 'user-managed python\n' >"$home/.local/bin/python"
  run_capture env HOME="$home" bash "$LOCAL" --apply
  assert_eq "regular python teardown exits 0" "0" "$RUN_STATUS"
  assert_file "regular python survives" "$home/.local/bin/python"
}

# ── the real safe_under_home guard ───────────────────────────────────────────
{
  guard_says() { ( HOME="$1"; \
    # shellcheck source=/dev/null
    source "$LOCAL"; safe_under_home "$2" && echo ok || echo fail ); }
  h="$(sandbox)"
  assert_eq "guard refuses /"             "fail" "$(guard_says "$h" '/')"
  assert_eq "guard refuses HOME itself"   "fail" "$(guard_says "$h" "$h")"
  assert_eq "guard refuses non-HOME path" "fail" "$(guard_says "$h" '/etc/passwd')"
  assert_eq "guard accepts under HOME"    "ok"   "$(guard_says "$h" "$h/.config")"

  # Symlink escape: lexically under HOME but resolves outside -> must refuse.
  escape="$(sandbox)"; mkdir -p "$escape/real"; ln -s "$escape" "$h/link-out"
  assert_eq "guard refuses symlink escaping HOME" "fail" "$(guard_says "$h" "$h/link-out/real")"
}

# ── teardown-dotfiles no-ops (does not error) when mise is absent ────────────
{
  home="$(sandbox)"
  run_capture env PATH="/usr/bin:/bin" HOME="$home" bash "$DOTFILES"
  assert_eq "no-op when mise absent" "0" "$RUN_STATUS"
  assert_contains "warns mise missing" "$(cat "$RUN_STDERR")" "mise not found"
}

# ── teardown-dotfiles points mise at the checkout config, not the symlink ─────
# The [dotfiles] table in the machine config is the only record of owned links;
# unapply must find it via the repo (this script's path), so it stays correct
# after the ~/.config/mise/config.toml symlink is gone. Stub mise, record argv.
{
  home="$(sandbox)"; stub_dir="$(sandbox)"; calls="$(sandbox)/mise-calls.txt"
  cat >"$stub_dir/mise" <<'EOF'
#!/usr/bin/env bash
printf 'config=%s args=%s\n' "$MISE_GLOBAL_CONFIG_FILE" "$*" >>"$MISE_LOG"
exit 0
EOF
  chmod +x "$stub_dir/mise"

  run_capture env HOME="$home" MISE_LOG="$calls" PATH="$stub_dir:/usr/bin:/bin" \
    bash "$DOTFILES"
  assert_eq "unapply exits 0" "0" "$RUN_STATUS"
  log="$(cat "$calls")"
  assert_contains "uses repository machine config" "$log" "config=$REPO/home/.config/mise/config.toml"
  assert_contains "unapplies from repo context (dry-run)" "$log" "args=-C $REPO bootstrap dotfiles unapply --dry-run --yes"

  : >"$calls"
  run_capture env HOME="$home" MISE_LOG="$calls" PATH="$stub_dir:/usr/bin:/bin" \
    bash "$DOTFILES" --apply
  assert_contains "unapplies for real under --apply" "$(cat "$calls")" "args=-C $REPO bootstrap dotfiles unapply --yes"
}

# ── teardown-packages prunes via mise against an empty-packages overlay ───────
# mise has no "remove what this config declares"; the only primitive is prune,
# which removes UNdeclared packages. So the script points prune at a standalone
# config declaring an empty [bootstrap.packages] and untrusts the repo configs,
# restoring trust after. Stub mise: record argv + the overlay's contents.
PACKAGES="$REPO/scripts/teardown-packages.sh"
{
  home="$(sandbox)"; stub_dir="$(sandbox)"; calls="$(sandbox)/mise-calls.txt"
  # The stub records the config path AND, for prune, dumps that config's body so
  # we can assert it declares an empty packages table (not the real one).
  cat >"$stub_dir/mise" <<'EOF'
#!/usr/bin/env bash
printf 'args=%s\n' "$*" >>"$MISE_LOG"
if [ "$3" = "bootstrap" ]; then
  printf 'overlay<<%s>>\n' "$(cat "$MISE_GLOBAL_CONFIG_FILE" 2>/dev/null | tr '\n' ' ')" >>"$MISE_LOG"
fi
exit 0
EOF
  chmod +x "$stub_dir/mise"

  run_capture env HOME="$home" MISE_LOG="$calls" PATH="$stub_dir:/usr/bin:/bin" \
    bash "$PACKAGES"
  assert_eq "prune exits 0" "0" "$RUN_STATUS"
  log="$(cat "$calls")"
  assert_contains "untrusts the machine config" "$log" "args=trust --untrust $REPO/home/.config/mise/config.toml"
  assert_contains "untrusts the repo mise.toml" "$log" "args=trust --untrust $REPO/mise.toml"
  assert_contains "prunes brew (dry-run)" "$log" "bootstrap packages prune --manager brew --dry-run --yes"
  assert_contains "prunes brew-cask (dry-run)" "$log" "bootstrap packages prune --manager brew-cask --dry-run --yes"
  assert_contains "overlay declares empty packages" "$log" "overlay<<[bootstrap.packages] >>"
  assert_contains "restores machine config trust" "$log" "args=trust $REPO/home/.config/mise/config.toml"

  : >"$calls"
  run_capture env HOME="$home" MISE_LOG="$calls" PATH="$stub_dir:/usr/bin:/bin" \
    bash "$PACKAGES" --apply
  assert_contains "prunes brew for real under --apply" "$(cat "$calls")" "bootstrap packages prune --manager brew"
  assert_not_contains "apply is not a dry-run" "$(cat "$calls")" "--dry-run"
}

# ── teardown-packages no-ops (does not error) when mise is absent ─────────────
{
  home="$(sandbox)"
  run_capture env PATH="/usr/bin:/bin" HOME="$home" bash "$PACKAGES"
  assert_eq "no-op when mise absent" "0" "$RUN_STATUS"
  assert_contains "warns mise missing" "$(cat "$RUN_STDERR")" "mise not found"
}
