#!/usr/bin/env bash
# Tests for home/.config/mise/tasks/setup/git-identity

echo "== git-identity =="

GIT_IDENTITY="$REPO/tasks/setup/git-identity"

# Happy path: four prompted values render both identity files with correct content.
{
  home="$(sandbox)"
  out="$(printf 'Work User\nwork@example.com\nPlay User\nplay@example.com\n' \
    | HOME="$home" bash "$GIT_IDENTITY" 2>&1)"
  cfg="$home/.config/git/config.local"
  play="$home/.config/git/identity-play"
  assert_file "config.local created" "$cfg"
  assert_file "identity-play created" "$play"
  assert_contains "work name rendered"  "$(cat "$cfg")"  "Work User"
  assert_contains "work email rendered" "$(cat "$cfg")"  "work@example.com"
  assert_contains "play name rendered"  "$(cat "$play")" "Play User"
  assert_no_placeholder "placeholders all filled" "$(cat "$cfg")$(cat "$play")"
}

# Idempotency: a second run with an existing config.local is a no-op (exit 0),
# does not re-prompt, and leaves the file untouched.
{
  home="$(sandbox)"
  printf 'A\na@x.co\nB\nb@x.co\n' | HOME="$home" bash "$GIT_IDENTITY" >/dev/null 2>&1
  before="$(cat "$home/.config/git/config.local")"
  out="$(HOME="$home" bash "$GIT_IDENTITY" </dev/null 2>&1)"; rc=$?
  assert_eq "re-run exits 0" "0" "$rc"
  assert_contains "re-run reports existing" "$out" "already exists"
  assert_eq "re-run leaves file unchanged" "$before" "$(cat "$home/.config/git/config.local")"
}

# Validation: a malformed email is rejected with a non-zero exit and no files.
{
  home="$(sandbox)"
  set +e
  printf 'Work User\nnot-an-email\n' | HOME="$home" bash "$GIT_IDENTITY" >/dev/null 2>&1
  rc=$?
  set -e
  assert_eq "bad email exits non-zero" "2" "$rc"
  assert_not_exists "bad email writes no config" "$home/.config/git/config.local"
}

# Edge case: shell metacharacters in name values.
{
  home="$(sandbox)"
  printf "O'Brien & Sons\nwork@x.co\nPlay \$User\nplay@x.co\n" \
    | HOME="$home" bash "$GIT_IDENTITY" 2>&1 >/dev/null
  cfg="$home/.config/git/config.local"
  if [ -f "$cfg" ]; then
    assert_contains "apostrophe preserved" "$(cat "$cfg")" "O'Brien & Sons"
    assert_no_placeholder "metachar no placeholder" "$(cat "$cfg")"
  else
    bad "metachar test: config created" "config.local missing"
  fi
}
