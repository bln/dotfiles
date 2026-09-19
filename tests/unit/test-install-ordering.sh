#!/usr/bin/env bash
# Unit: install.sh drives mise in the correct order on a fresh machine.
#
# Targets FM2 (ordering / prereq). The owner hit a converge that ran steps out
# of order. A source grep for "mise trust" proves nothing about order; here we
# put a fake `mise` first on PATH that logs every invocation, run the REAL
# install.sh, and assert the recorded call sequence. No machine mutation: the
# shim exits 0 and touches nothing.
#
# Required order (bootstrap mode):
#   trust config -> trust mise.toml -> trust tasks -> bootstrap -> setup:git-identity
# git-identity must run only when no machine-local git config exists yet.

echo "== install-ordering =="

INSTALL="$REPO/install.sh"

run_install() {
  # $1 = extra args to install.sh, $2 = HOME sandbox
  local args="$1" home="$2" log="$3" binshim="$4"
  set +e
  env -i \
    HOME="$home" \
    PATH="$binshim:/usr/bin:/bin" \
    MISE_LOG="$log" \
    bash "$INSTALL" $args >/dev/null 2>&1  # shellcheck disable=SC2086  # intentional word-split
  RUN_STATUS=$?
  set -e
}

# Fake mise: log "<subcommand chain>" per call, exit 0. Reads $MISE_LOG.
make_mise_shim() {
  local dir="$1"
  cat >"$dir/mise" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$MISE_LOG"
exit 0
EOF
  chmod +x "$dir/mise"
}

# --- fresh machine: no config.local -> git-identity runs, correct order -------
sb="$(sandbox)"
bindir="$sb/bin"; mkdir -p "$bindir" "$sb/home/.config/git"
make_mise_shim "$bindir"
log="$sb/calls.log"; : >"$log"

run_install "" "$sb/home" "$log" "$bindir"
assert_eq "install.sh exits 0 on fresh machine" "0" "$RUN_STATUS"

calls="$(cat "$log")"
assert_contains "trusts the global config"  "$calls" "trust"
assert_contains "runs bootstrap"            "$calls" "bootstrap --yes --force-dotfiles"
assert_contains "runs git-identity setup"   "$calls" "run setup:git-identity"

# Order: last trust line precedes bootstrap; bootstrap precedes git-identity.
last_trust="$(grep -n '^trust ' "$log" | tail -1 | cut -d: -f1 || true)"
boot_line="$(grep -n 'bootstrap ' "$log" | head -1 | cut -d: -f1 || true)"
ident_line="$(grep -n 'setup:git-identity' "$log" | head -1 | cut -d: -f1 || true)"
if [ -n "$last_trust" ] && [ -n "$boot_line" ] && [ "$last_trust" -lt "$boot_line" ]; then
  ok "all trust calls precede bootstrap"
else
  bad "all trust calls precede bootstrap" "trust@$last_trust bootstrap@$boot_line"
fi
if [ -n "$boot_line" ] && [ -n "$ident_line" ] && [ "$boot_line" -lt "$ident_line" ]; then
  ok "bootstrap precedes git-identity"
else
  bad "bootstrap precedes git-identity" "bootstrap@$boot_line identity@$ident_line"
fi

# --- git identity already present -> git-identity is skipped ------------------
sb2="$(sandbox)"
bindir2="$sb2/bin"; mkdir -p "$bindir2" "$sb2/home/.config/git"
make_mise_shim "$bindir2"
: >"$sb2/home/.config/git/config.local"   # pretend identity already set up
log2="$sb2/calls.log"; : >"$log2"

run_install "" "$sb2/home" "$log2" "$bindir2"
assert_eq "install.sh exits 0 when identity present" "0" "$RUN_STATUS"
assert_not_contains "skips git-identity when config.local exists" "$(cat "$log2")" "setup:git-identity"

# --- update mode: installs + runs update task, no bootstrap -------------------
sb3="$(sandbox)"
bindir3="$sb3/bin"; mkdir -p "$bindir3" "$sb3/home"
make_mise_shim "$bindir3"
log3="$sb3/calls.log"; : >"$log3"

run_install "--update" "$sb3/home" "$log3" "$bindir3"
assert_eq "install.sh --update exits 0" "0" "$RUN_STATUS"
calls3="$(cat "$log3")"
assert_contains "update mode runs install"       "$calls3" "install"
assert_contains "update mode runs update task"   "$calls3" "run update"
assert_not_contains "update mode does not bootstrap" "$calls3" "bootstrap"
