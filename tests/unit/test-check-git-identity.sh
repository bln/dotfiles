#!/usr/bin/env bash
# Tests for scripts/check-git-identity.sh

echo "== check:git-identity =="

CHECK_GIT_IDENTITY="$REPO/scripts/check-git-identity.sh"

# Helper: write a complete identity file.
write_id() { # write_id <file> <name> <email>
  git config --file "$1" user.name "$2"
  git config --file "$1" user.email "$3"
}

# Passes when BOTH identity files resolve name+email.
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  write_id "$home/.config/git/identity-personal" "Personal User" "me@x.co"
  write_id "$home/.config/git/identity-work" "Work User" "me@work.co"
  run_capture env HOME="$home" bash "$CHECK_GIT_IDENTITY"
  assert_eq "both resolve -> exit 0" "0" "$RUN_STATUS"
  assert_contains "reports the personal identity" "$(cat "$RUN_STDOUT")" "Personal User"
  assert_contains "reports the work identity" "$(cat "$RUN_STDOUT")" "Work User"
}

# Fails when identity-personal is missing (even if work is present).
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  write_id "$home/.config/git/identity-work" "Work User" "me@work.co"
  run_capture env HOME="$home" bash "$CHECK_GIT_IDENTITY"
  assert_eq "missing identity-personal -> exit 1" "1" "$RUN_STATUS"
  assert_contains "names the fix" "$(cat "$RUN_STDERR")" "setup:git-identity"
}

# Fails when identity-work is missing (the finding: a half-configured pair must
# NOT pass verify - work repos would be unable to commit).
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  write_id "$home/.config/git/identity-personal" "Personal User" "me@x.co"
  run_capture env HOME="$home" bash "$CHECK_GIT_IDENTITY"
  assert_eq "missing identity-work -> exit 1" "1" "$RUN_STATUS"
  assert_contains "names the missing work file" "$(cat "$RUN_STDERR")" "identity-work"
}

# Fails when name present but email missing (personal).
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  git config --file "$home/.config/git/identity-personal" user.name "No Email"
  write_id "$home/.config/git/identity-work" "Work User" "me@work.co"
  run_capture env HOME="$home" bash "$CHECK_GIT_IDENTITY"
  assert_eq "missing personal email -> exit 1" "1" "$RUN_STATUS"
}

# Fails when email present but name missing (personal).
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  git config --file "$home/.config/git/identity-personal" user.email "no-name@x.co"
  write_id "$home/.config/git/identity-work" "Work User" "me@work.co"
  run_capture env HOME="$home" bash "$CHECK_GIT_IDENTITY"
  assert_eq "missing personal name -> exit 1" "1" "$RUN_STATUS"
}
