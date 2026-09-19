#!/usr/bin/env bash
# Tests for scripts/check-git-identity.sh

echo "== check:git-identity =="

CHECK_GIT_IDENTITY="$REPO/scripts/check-git-identity.sh"

# Passes when identity-personal resolves name+email.
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  git config --file "$home/.config/git/identity-personal" user.name "Personal User"
  git config --file "$home/.config/git/identity-personal" user.email "me@x.co"
  run_capture env HOME="$home" bash "$CHECK_GIT_IDENTITY"
  assert_eq "resolves -> exit 0" "0" "$RUN_STATUS"
  assert_contains "reports the identity" "$(cat "$RUN_STDOUT")" "Personal User"
}

# Fails when identity-personal is missing.
{
  home="$(sandbox)"   # no identity-personal at all
  run_capture env HOME="$home" bash "$CHECK_GIT_IDENTITY"
  assert_eq "missing identity-personal -> exit 1" "1" "$RUN_STATUS"
  assert_contains "names the fix" "$(cat "$RUN_STDERR")" "setup:git-identity"
}

# Fails when name present but email missing.
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  git config --file "$home/.config/git/identity-personal" user.name "No Email"
  run_capture env HOME="$home" bash "$CHECK_GIT_IDENTITY"
  assert_eq "missing email -> exit 1" "1" "$RUN_STATUS"
}

# Fails when email present but name missing.
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  git config --file "$home/.config/git/identity-personal" user.email "no-name@x.co"
  run_capture env HOME="$home" bash "$CHECK_GIT_IDENTITY"
  assert_eq "missing name -> exit 1" "1" "$RUN_STATUS"
}
