#!/usr/bin/env bash
# Tests for tasks/setup/git-identity (two-file, remote-routed identity).

echo "== git-identity =="

GIT_IDENTITY="$REPO/tasks/setup/git-identity"
GITCFG="$REPO/home/.config/git/config"

# Happy path: 4 prompts write both identity files, 600, correct content.
{
  home="$(sandbox)"
  printf 'Personal User\nme@personal.com\nWork User\nwork@corp.example\n' \
    | HOME="$home" bash "$GIT_IDENTITY" >/dev/null 2>&1
  personal="$home/.config/git/identity-personal"
  work="$home/.config/git/identity-work"
  assert_file "identity-personal created" "$personal"
  assert_file "identity-work created" "$work"
  assert_mode "identity-personal is 600" "$personal" "600"
  assert_mode "identity-work is 600" "$work" "600"
  assert_contains "personal name"  "$(cat "$personal")" "Personal User"
  assert_contains "personal email" "$(cat "$personal")" "me@personal.com"
  assert_contains "work name"      "$(cat "$work")" "Work User"
  assert_contains "work email"     "$(cat "$work")" "work@corp.example"
}

# Idempotency: a second run with identity-personal present is a no-op (exit 0),
# does not re-prompt, and leaves the file untouched.
{
  home="$(sandbox)"
  printf 'A\na@x.co\nB\nb@x.co\n' | HOME="$home" bash "$GIT_IDENTITY" >/dev/null 2>&1
  before="$(cat "$home/.config/git/identity-personal")"
  out="$(HOME="$home" bash "$GIT_IDENTITY" </dev/null 2>&1)"; rc=$?
  assert_eq "re-run exits 0" "0" "$rc"
  assert_contains "re-run reports existing" "$out" "already exists"
  assert_eq "re-run leaves file unchanged" "$before" "$(cat "$home/.config/git/identity-personal")"
}

# Validation: a malformed email is rejected with a non-zero exit and no files.
{
  home="$(sandbox)"
  set +e
  printf 'Personal User\nnot-an-email\n' | HOME="$home" bash "$GIT_IDENTITY" >/dev/null 2>&1
  rc=$?
  set -e
  assert_eq "bad email exits non-zero" "2" "$rc"
  assert_not_exists "bad email writes no identity" "$home/.config/git/identity-personal"
}

# Edge case: shell metacharacters in name values are preserved literally.
{
  home="$(sandbox)"
  printf "O'Brien & Sons\nwork@x.co\nPlay \$User\nplay@x.co\n" \
    | HOME="$home" bash "$GIT_IDENTITY" >/dev/null 2>&1
  personal="$home/.config/git/identity-personal"
  if [ -f "$personal" ]; then
    assert_contains "apostrophe/ampersand preserved" "$(cat "$personal")" "O'Brien & Sons"
  else
    bad "metachar test: identity created" "identity-personal missing"
  fi
}

# Routing: the tracked git config + generated identity files pick the right
# identity per remote host. This is the crux of the redesign - verify it live.
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  cp "$GITCFG" "$home/.config/git/config"
  printf '[user]\n\temail = me@personal.com\n' >"$home/.config/git/identity-personal"
  printf '[user]\n\temail = work@corp.example\n' >"$home/.config/git/identity-work"

  resolve() { # $1 = remote url ("" = no remote); echoes resolved email
    local url="$1" dir; dir="$(sandbox)"
    git -C "$dir" init -q
    [ -n "$url" ] && git -C "$dir" remote add origin "$url"
    HOME="$home" GIT_CONFIG_GLOBAL="$home/.config/git/config" \
      git -C "$dir" config user.email 2>/dev/null || true
  }
  assert_eq "https SAP -> work"  "work@corp.example" "$(resolve 'https://github.tools.sap/o/r.git')"
  assert_eq "scp SAP -> work"    "work@corp.example" "$(resolve 'git@github.tools.sap:o/r.git')"
  assert_eq "ssh SAP -> work"    "work@corp.example" "$(resolve 'ssh://git@github.tools.sap/o/r.git')"
  assert_eq "github.com -> personal" "me@personal.com" "$(resolve 'https://github.com/bln/x.git')"
  assert_eq "scp github.com -> personal" "me@personal.com" "$(resolve 'git@github.com:bln/x.git')"
  assert_eq "no remote -> personal" "me@personal.com" "$(resolve '')"
  assert_eq "lookalike host -> personal" "me@personal.com" "$(resolve 'https://notgithub.tools.sap/x.git')"
  assert_eq "spoofed host -> personal" "me@personal.com" "$(resolve 'https://github.tools.sap.evil.com/x.git')"
}
