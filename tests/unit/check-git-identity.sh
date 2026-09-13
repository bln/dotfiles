#!/usr/bin/env bash
# Tests for .mise/tasks/check/git-identity

echo "== check:git-identity =="

CHECK_GIT_IDENTITY="$REPO/.mise/tasks/check/git-identity"

# Passes when config.local resolves name+email.
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  git config --file "$home/.config/git/config.local" user.name "Work User"
  git config --file "$home/.config/git/config.local" user.email "w@x.co"
  run_capture env HOME="$home" bash "$CHECK_GIT_IDENTITY"
  assert_eq "resolves -> exit 0" "0" "$RUN_STATUS"
  assert_contains "reports the identity" "$(cat "$RUN_STDOUT")" "Work User"
}

# Fails when config.local is missing.
{
  home="$(sandbox)"   # no config.local at all
  run_capture env HOME="$home" bash "$CHECK_GIT_IDENTITY"
  assert_eq "missing config.local -> exit 1" "1" "$RUN_STATUS"
  assert_contains "names the fix" "$(cat "$RUN_STDERR")" "setup:git-identity"
}

# Fails when name present but email missing.
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  git config --file "$home/.config/git/config.local" user.name "No Email"
  run_capture env HOME="$home" bash "$CHECK_GIT_IDENTITY"
  assert_eq "missing email -> exit 1" "1" "$RUN_STATUS"
}

# Fails when email present but name missing.
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  git config --file "$home/.config/git/config.local" user.email "no-name@x.co"
  run_capture env HOME="$home" bash "$CHECK_GIT_IDENTITY"
  assert_eq "missing name -> exit 1" "1" "$RUN_STATUS"
}
