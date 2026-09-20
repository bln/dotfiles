#!/usr/bin/env bash
# shellcheck disable=SC2153 # REPO is exported by tests/run.sh, which sources this file
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

# ── regression: empty/comment-only extensions.txt must NOT abort apply ────────
# A named profile may declare no ids of its own (e.g. the go profile: its only
# extension is the inherited global). Its extensions.txt is comment-only, so the
# `grep -v '^$'` in declared_extensions matches nothing and exits 1. Also covers
# the sibling case: `code --list-extensions --profile X` exiting 1 ("not found")
# for a freshly-seeded profile VS Code has not registered yet. Both are normal
# nonzero signals the script must tolerate. This asserts the observable contract
# (apply exits 0 and seeds EVERY named profile), not any particular error-policy
# implementation, so it holds whether the tolerance comes from `|| true` hatches
# or from dropping errexit outright.
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud/globalStorage" "$bin" "$repo"
  printf 'golang.go\n' >"$repo/extensions.txt"
  # aaa: comment-only (no ids) - the declared_extensions grep-exits-1 trigger.
  mkdir -p "$repo/profiles/aaa"; printf '# only inherits the global\n' >"$repo/profiles/aaa/extensions.txt"
  # bbb, ccc: normal, must still be reached and seeded after aaa.
  for p in bbb ccc; do
    mkdir -p "$repo/profiles/$p"; printf 'ext.%s\n' "$p" >"$repo/profiles/$p/extensions.txt"
  done

  # Fake code: --list-extensions for a named profile exits 1 ("not found"), like
  # the real binary for a profile it has not registered yet. Global list is 0.
  cat >"$bin/code" <<'EOF'
#!/usr/bin/env bash
prof=""; args=("$@")
for i in "${!args[@]}"; do
  [ "${args[$i]}" = "--profile" ] && prof="${args[$((i+1))]}"
done
case "$1" in
  --list-extensions)
    if [ -n "$prof" ]; then echo "Profile '$prof' not found."; exit 1; fi
    printf '%s\n' $PRESET ;;
  --install-extension)   printf '%s\t%s\n' "$2" "$prof" >>"$CODE_INSTALL_LOG" ;;
  --uninstall-extension) : ;;
  --status) echo "Warning: The --status argument can only be used if Code is already running." >&2 ;;
esac
exit 0
EOF
  chmod +x "$bin/code"
  ilog="$sb/i.log"; : >"$ilog"

  if command -v jq >/dev/null 2>&1 && command -v uuidgen >/dev/null 2>&1; then
    run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code" \
      PRESET="" CODE_INSTALL_LOG="$ilog" bash "$CLI" apply
    assert_eq "apply survives comment-only + not-found" "0" "$RUN_STATUS"
    for p in aaa bbb ccc; do
      assert_eq "profile $p seeded past the abort point" "1" \
        "$(jq -r --arg n "$p" '[.userDataProfiles[]|select(.name==$n)]|length' "$ud/globalStorage/storage.json")"
    done
    # aaa (comment-only) still inherits the global into its own profile.
    assert_contains "comment-only aaa still gets global golang.go" \
      "$(awk -F'\t' '$2=="aaa"' "$ilog")" "golang.go"
  else
    skip "empty-extensions/not-found regression (jq/uuidgen not installed)"
  fi
}

# ── failing extension install mid-loop: continue, but exit nonzero ────────────
# `code --install-extension` can fail for one id (network, bad id) while others
# succeed. That is not fleet-fatal: the run must continue and still seed/serve
# every profile. But it IS a real failure, so apply aggregates it and returns
# nonzero. This locks in both halves: no mid-loop abort, no silently-swallowed error.
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud/globalStorage" "$bin" "$repo"
  printf 'golang.go\n' >"$repo/extensions.txt"
  for p in aaa bbb; do
    mkdir -p "$repo/profiles/$p"; printf 'ext.%s\n' "$p" >"$repo/profiles/$p/extensions.txt"
  done

  # Fake code: --install-extension exits 1 for the FIRST profile's own id but 0
  # otherwise; --list-extensions for a named profile returns empty (exit 0 here,
  # the not-found path is covered by the regression block above).
  cat >"$bin/code" <<'EOF'
#!/usr/bin/env bash
prof=""; args=("$@")
for i in "${!args[@]}"; do
  [ "${args[$i]}" = "--profile" ] && prof="${args[$((i+1))]}"
done
case "$1" in
  --list-extensions) [ -n "$prof" ] || printf '%s\n' $PRESET ;;
  --install-extension)
    printf '%s\t%s\n' "$2" "$prof" >>"$CODE_INSTALL_LOG"
    [ "$2" = "ext.aaa" ] && exit 1 ;;
  --status) echo "Warning: can only be used if Code is already running." >&2 ;;
esac
exit 0
EOF
  chmod +x "$bin/code"
  ilog="$sb/i.log"; : >"$ilog"

  if command -v jq >/dev/null 2>&1 && command -v uuidgen >/dev/null 2>&1; then
    run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code" \
      PRESET="" CODE_INSTALL_LOG="$ilog" bash "$CLI" apply
    # Contract: apply finishes every profile even when one install fails, but
    # aggregates the failure and exits nonzero (a failed install is a real error,
    # not an ignorable tool signal).
    assert_eq "apply reports the failing install (nonzero)" "1" "$RUN_STATUS"
    # The failed install was attempted (aaa) AND the loop continued to bbb.
    assert_contains "attempted the failing install (aaa)" "$(cut -f1 <"$ilog")" "ext.aaa"
    assert_contains "continued past failure to bbb" "$(cut -f1 <"$ilog")" "ext.bbb"
    assert_contains "names the failed install in output" "$(cat "$RUN_STDERR")" "failed to install ext.aaa"
    for p in aaa bbb; do
      assert_eq "profile $p seeded despite install failure" "1" \
        "$(jq -r --arg n "$p" '[.userDataProfiles[]|select(.name==$n)]|length' "$ud/globalStorage/storage.json")"
    done
  else
    skip "failing-install regression (jq/uuidgen not installed)"
  fi
}

# ── a failing storage.json write IS fatal ─────────────────────────────────────
# The one class errexit used to cover for us: without it, a failed `jq`/`mv` must
# be caught by `|| die`, NOT fall through to registering a profile dir/location
# for an entry that was never written. Force the write to fail by making
# globalStorage a read-only directory (mktemp/jq write into it cannot complete)
# and assert apply exits nonzero, emits the die message, and creates no profile dir.
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud/globalStorage" "$bin" "$repo"
  make_code "$bin"
  printf 'golang.go\n' >"$repo/extensions.txt"
  mkdir -p "$repo/profiles/pyth"; printf 'ms-python.python\n' >"$repo/profiles/pyth/extensions.txt"

  # Stub jq on PATH ahead of the real one so the storage rewrite fails. seed_profile
  # gates on `command -v jq`, so jq must exist but fail when it runs the write.
  cat >"$bin/jq" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$bin/jq"

  # Only run where we can guarantee the stub jq wins (prepend $bin to PATH). uuidgen
  # is still needed for the location; skip if absent.
  if command -v uuidgen >/dev/null 2>&1; then
    run_capture env PATH="$bin:$PATH" VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" \
      VSCODE_CODE_BIN="$bin/code" PRESET="" bash "$CLI" apply
    assert_eq "failing storage write aborts apply (nonzero)" "1" "$RUN_STATUS"
    assert_contains "names the fatal write in the error" "$(cat "$RUN_STDERR")" "failed to write"
    assert_not_exists "no profile dir left for an unwritten entry" "$ud/profiles/pyth"
  else
    skip "fatal-write test (uuidgen not installed)"
  fi
}

# ── check: file match / drift / missing / symlink ────────────────────────────
# Focuses on profile-FILE drift; code is absent (VSCODE_CODE_BIN points nowhere)
# so extension drift is out of scope here - it has its own block below.
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"
  mkdir -p "$ud" "$repo"
  printf 'x\n' >"$repo/settings.json"
  printf 'a\n' >"$repo/extensions.txt"
  nocode=(env PATH="/usr/bin:/bin" VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo"
    VSCODE_CODE_BIN="definitely-not-code")

  # missing live -> drift: warn to apply, exit 1 (gates verify)
  run_capture "${nocode[@]}" bash "$CLI" check
  assert_eq "check missing exits 1" "1" "$RUN_STATUS"
  assert_contains "check missing warns apply" "$(cat "$RUN_STDERR")" "vscode-profiles apply"

  # matching -> OK exit 0
  printf 'x\n' >"$ud/settings.json"
  run_capture "${nocode[@]}" bash "$CLI" check
  assert_eq "check match exits 0" "0" "$RUN_STATUS"
  assert_contains "check match says OK" "$(cat "$RUN_STDOUT")" "match the repo copy"

  # drift -> warn with pull path, exit 1 (gates verify)
  printf 'y\n' >"$ud/settings.json"
  run_capture "${nocode[@]}" bash "$CLI" check
  assert_eq "check drift exits 1" "1" "$RUN_STATUS"
  assert_contains "check drift names pull" "$(cat "$RUN_STDERR")" "vscode-profiles pull"

  # symlink -> error exit 1
  rm -f "$ud/settings.json"; ln -s "$repo/settings.json" "$ud/settings.json"
  run_capture "${nocode[@]}" bash "$CLI" check
  assert_eq "check symlink exits 1" "1" "$RUN_STATUS"
  assert_contains "check symlink flags copy mode" "$(cat "$RUN_STDERR")" "copy mode"
}

# ── malformed profile .location is never trusted as a path (teardown rm -rf) ───
# A hand-edited or corrupt storage.json whose .location contains "../.." must not
# let teardown escape the profiles dir. resolve_location rejects it (so resolve
# prints nothing and warns) and teardown never builds a deletion path from it.
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud/globalStorage" "$repo/profiles/evil" "$bin"
  printf 'golang.go\n' >"$repo/extensions.txt"
  printf 'ms-python.python\n' >"$repo/profiles/evil/extensions.txt"
  make_code "$bin"
  # A canary OUTSIDE the profiles dir that a "../../canary" escape would delete.
  mkdir -p "$ud/canary"; printf 'keep\n' >"$ud/canary/keep.txt"

  if command -v jq >/dev/null 2>&1; then
    printf '{"userDataProfiles":[{"name":"evil","location":"../../canary"}]}\n' \
      >"$ud/globalStorage/storage.json"

    run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code" \
      bash "$CLI" resolve evil
    assert_eq "resolve rejects malformed location (empty)" "" "$(cat "$RUN_STDOUT")"
    assert_contains "resolve warns on malformed location" "$(cat "$RUN_STDERR")" "malformed profile location"

    # teardown --apply must not delete the canary via the malformed location.
    run_capture env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code" \
      APPLY=true VSCODE_PROFILES_FORCE=true bash "$CLI" teardown --apply
    assert_file "canary survives malformed-location teardown" "$ud/canary/keep.txt"
  else
    skip "malformed-location guard (jq not installed)"
  fi
}

# ── check: snippet drift (missing / differing / repo-only) ────────────────────
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"
  mkdir -p "$ud/snippets" "$repo/snippets"
  printf 'x\n' >"$repo/settings.json"; printf 'x\n' >"$ud/settings.json"
  printf '{"a":1}\n' >"$repo/snippets/py.json"
  nocode=(env PATH="/usr/bin:/bin" VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo"
    VSCODE_CODE_BIN="definitely-not-code")

  # repo snippet missing live -> drift
  run_capture "${nocode[@]}" bash "$CLI" check
  assert_eq "snippet missing live -> exit 1" "1" "$RUN_STATUS"
  assert_contains "names the missing snippet" "$(cat "$RUN_STDERR")" "snippet missing live: py.json"

  # present and identical -> OK
  printf '{"a":1}\n' >"$ud/snippets/py.json"
  run_capture "${nocode[@]}" bash "$CLI" check
  assert_eq "matching snippet -> exit 0" "0" "$RUN_STATUS"

  # differing content -> drift
  printf '{"a":2}\n' >"$ud/snippets/py.json"
  run_capture "${nocode[@]}" bash "$CLI" check
  assert_eq "snippet differs -> exit 1" "1" "$RUN_STATUS"
  assert_contains "names the differing snippet" "$(cat "$RUN_STDERR")" "snippet differs: py.json"

  # a live snippet not declared in the repo -> drift
  printf '{"a":1}\n' >"$ud/snippets/py.json"     # re-sync the shared one
  printf '{"b":1}\n' >"$ud/snippets/extra.json"  # live-only
  run_capture "${nocode[@]}" bash "$CLI" check
  assert_eq "live-only snippet -> exit 1" "1" "$RUN_STATUS"
  assert_contains "names the live-only snippet" "$(cat "$RUN_STDERR")" "live snippet not in repo: extra.json"
}

# ── check: extension drift (declared-not-installed / installed-not-declared) ──
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"; bin="$sb/bin"
  mkdir -p "$ud" "$repo" "$bin"
  printf 'x\n' >"$repo/settings.json"; printf 'x\n' >"$ud/settings.json"
  printf 'esbenp.prettier-vscode\n' >"$repo/extensions.txt"
  make_code "$bin"
  common=(env VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo" VSCODE_CODE_BIN="$bin/code")

  # installed matches declared -> OK
  run_capture "${common[@]}" PRESET="esbenp.prettier-vscode" bash "$CLI" check
  assert_eq "extensions match -> exit 0" "0" "$RUN_STATUS"

  # declared but not installed -> drift
  run_capture "${common[@]}" PRESET="" bash "$CLI" check
  assert_eq "declared-not-installed -> exit 1" "1" "$RUN_STATUS"
  assert_contains "names the missing extension" "$(cat "$RUN_STDERR")" "declared but not installed: esbenp.prettier-vscode"

  # installed but not declared -> drift
  run_capture "${common[@]}" PRESET="esbenp.prettier-vscode ms-python.python" bash "$CLI" check
  assert_eq "installed-not-declared -> exit 1" "1" "$RUN_STATUS"
  assert_contains "names the undeclared extension" "$(cat "$RUN_STDERR")" "installed but not declared: ms-python.python"
}

# ── pull: capture a newly-present managed file + mirror/prune snippets ─────────
{
  sb="$(sandbox)"; ud="$sb/User"; repo="$sb/repo"
  mkdir -p "$ud/snippets" "$repo/snippets"
  # Repo tracks only settings; live has settings + a NEW keybindings the repo
  # never tracked, and snippet churn (new live one, stale repo one).
  printf 'old\n' >"$repo/settings.json"
  printf 'new\n' >"$ud/settings.json"
  printf 'keys\n' >"$ud/keybindings.json"      # live-only managed file
  printf '{"live":1}\n' >"$ud/snippets/live.json"   # live-only snippet
  printf '{"stale":1}\n' >"$repo/snippets/stale.json" # repo-only snippet (deleted upstream)
  nocode=(env PATH="/usr/bin:/bin" VSCODE_USER_DIR="$ud" VSCODE_REPO_DIR="$repo"
    VSCODE_CODE_BIN="definitely-not-code")

  run_capture "${nocode[@]}" bash "$CLI" pull
  assert_eq "pull exits 0" "0" "$RUN_STATUS"
  assert_eq "pull updates existing settings" "new" "$(cat "$repo/settings.json")"
  assert_file "pull captures the new managed file" "$repo/keybindings.json"
  assert_eq "captured file has live content" "keys" "$(cat "$repo/keybindings.json")"
  assert_file "pull captures the new live snippet" "$repo/snippets/live.json"
  assert_not_exists "pull prunes the stale repo snippet" "$repo/snippets/stale.json"
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
