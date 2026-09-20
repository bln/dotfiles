#!/usr/bin/env bash
# ci: machine-local git identity - generation, remote routing, and the verify
# guard. All three are real logic mise does not provide, and a wrong result
# silently blocks commits (config sets user.useConfigOnly=true).
#
# Seam: every path derives from $HOME; tests point it at a sandbox.

echo "== ci: git identity =="

GEN="$REPO/tasks/setup/git-identity"
CHECK="$REPO/scripts/check-git-identity.sh"
GITCFG="$REPO/home/.config/git/config"

# ── generator ────────────────────────────────────────────────────────────────
# Happy path: 4 prompts write both files at 0600 with the right content.
{
  home="$(sandbox)"
  printf 'Personal User\nme@personal.com\nWork User\nwork@corp.example\n' \
    | HOME="$home" bash "$GEN" >/dev/null 2>&1
  p="$home/.config/git/identity-personal"; w="$home/.config/git/identity-work"
  assert_file "identity-personal created" "$p"
  assert_file "identity-work created" "$w"
  assert_mode "identity-personal is 600" "$p" "600"
  assert_contains "personal content" "$(cat "$p")" "me@personal.com"
  assert_contains "work content"     "$(cat "$w")" "work@corp.example"
}

# Idempotency: both present -> no-op, no re-prompt, unchanged.
{
  home="$(sandbox)"
  printf 'A\na@x.co\nB\nb@x.co\n' | HOME="$home" bash "$GEN" >/dev/null 2>&1
  before="$(cat "$home/.config/git/identity-personal")"
  out="$(HOME="$home" bash "$GEN" </dev/null 2>&1)"; rc=$?
  assert_eq "re-run exits 0" "0" "$rc"
  assert_contains "re-run reports existing" "$out" "already exist"
  assert_eq "re-run leaves file unchanged" "$before" "$(cat "$home/.config/git/identity-personal")"
}

# Half-configured recovery: personal present, work missing must NOT no-op.
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  printf '[user]\n\tname = P\n\temail = me@personal.com\n' >"$home/.config/git/identity-personal"
  out="$(printf 'P\nme@personal.com\nW\nwork@corp.example\n' | HOME="$home" bash "$GEN" 2>&1)"; rc=$?
  assert_eq "half-config re-run exits 0" "0" "$rc"
  assert_not_contains "did not treat half-config as done" "$out" "already exist"
  assert_file "re-run creates the missing work file" "$home/.config/git/identity-work"
}

# Validation: a malformed email is rejected (exit 2) and writes nothing.
{
  home="$(sandbox)"
  set +e; printf 'P\nnot-an-email\n' | HOME="$home" bash "$GEN" >/dev/null 2>&1; rc=$?; set -e
  assert_eq "bad email exits 2" "2" "$rc"
  assert_not_exists "bad email writes no identity" "$home/.config/git/identity-personal"
}

# Metacharacters round-trip through git-config's own read (not just the bytes).
{
  home="$(sandbox)"
  printf "O'Brien & Sons\nwork@x.co\nP\nplay@x.co\n" | HOME="$home" bash "$GEN" >/dev/null 2>&1
  assert_eq "apostrophe/ampersand round-trips" "O'Brien & Sons" \
    "$(git config --file "$home/.config/git/identity-personal" user.name)"
}

# ── remote routing (the crux of the two-file design) ─────────────────────────
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  cp "$GITCFG" "$home/.config/git/config"
  printf '[user]\n\temail = me@personal.com\n' >"$home/.config/git/identity-personal"
  printf '[user]\n\temail = work@corp.example\n' >"$home/.config/git/identity-work"
  resolve() {
    local url="$1" dir; dir="$(sandbox)"; git -C "$dir" init -q
    [ -n "$url" ] && git -C "$dir" remote add origin "$url"
    HOME="$home" GIT_CONFIG_GLOBAL="$home/.config/git/config" \
      git -C "$dir" config user.email 2>/dev/null || true
  }
  assert_eq "SAP remote -> work"        "work@corp.example" "$(resolve 'git@github.tools.sap:o/r.git')"
  assert_eq "github.com -> personal"    "me@personal.com"   "$(resolve 'https://github.com/bln/x.git')"
  assert_eq "no remote -> personal"     "me@personal.com"   "$(resolve '')"
  assert_eq "spoofed SAP host -> personal" "me@personal.com" "$(resolve 'https://github.tools.sap.evil.com/x.git')"
}

# ── verify guard ─────────────────────────────────────────────────────────────
# check-git-identity gates verify: both complete -> pass; either missing/partial
# -> fail (a half-configured pair must not pass, or work repos cannot commit).
{
  wid() { git config --file "$1" user.name "$2"; git config --file "$1" user.email "$3"; }
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  wid "$home/.config/git/identity-personal" "P" "me@x.co"
  wid "$home/.config/git/identity-work" "W" "me@work.co"
  run_capture env HOME="$home" bash "$CHECK"
  assert_eq "both complete -> exit 0" "0" "$RUN_STATUS"

  home="$(sandbox)"; mkdir -p "$home/.config/git"
  wid "$home/.config/git/identity-personal" "P" "me@x.co"   # work missing
  run_capture env HOME="$home" bash "$CHECK"
  assert_eq "half-configured -> exit 1" "1" "$RUN_STATUS"
  assert_contains "names the fix" "$(cat "$RUN_STDERR")" "setup:git-identity"
}
