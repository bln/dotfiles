#!/usr/bin/env bash
# Test harness for this repo's parameterized shell scripts.
#
# Plain bash (no bats/framework, per AGENTS.md). Each test exercises the REAL
# shipped script - never a copy - by pointing its documented override seam at a
# mktemp sandbox: git-identity via $HOME, pi-config via $PI_AGENT_DIR,
# reset-codex via $CODEX_HOME. This is the pattern AGENTS.md "Script testability"
# prescribes.
set -euo pipefail

REPO="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
GIT_IDENTITY="$REPO/home/.config/mise/tasks/setup/git-identity"
PI_CONFIG="$REPO/home/.config/mise/tasks/setup/pi-config"
RESET_CODEX="$REPO/home/.config/mise/tasks/reset-codex"
CHECK_GIT_IDENTITY="$REPO/.mise/tasks/check/git-identity"
CHECK_VSCODE="$REPO/.mise/tasks/check/vscode-symlink"

pass=0
fail=0
sandboxes=()

cleanup() { for d in "${sandboxes[@]:-}"; do [ -n "$d" ] && rm -rf "$d"; done; return 0; }
trap cleanup EXIT

sandbox() { local d; d="$(mktemp -d)"; sandboxes+=("$d"); printf '%s\n' "$d"; }

ok()   { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL %s\n' "$1"; printf '       %s\n' "$2" >&2; fail=$((fail + 1)); }

# assert_eq LABEL EXPECTED ACTUAL
assert_eq() {
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$2], got [$3]"; fi
}
# assert_contains LABEL HAYSTACK NEEDLE
assert_contains() {
  case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "[$2] does not contain [$3]" ;; esac
}
# assert_file LABEL PATH
assert_file() { if [ -f "$2" ]; then ok "$1"; else bad "$1" "missing file: $2"; fi; }

echo "== git-identity =="

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
  assert_contains "no unfilled placeholder" "$(cat "$cfg")$(cat "$play")" ""
  case "$(cat "$cfg")$(cat "$play")" in
    *"{{"*) bad "placeholders all filled" "found {{ in rendered output" ;;
    *)      ok "placeholders all filled" ;;
  esac
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
  if [ ! -f "$home/.config/git/config.local" ]; then
    ok "bad email writes no config"
  else
    bad "bad email writes no config" "config.local should not exist"
  fi
}

echo "== pi-config =="

# Happy path: secret from env, templates render into $PI_AGENT_DIR, mode 600,
# and the key is substituted (no placeholder left behind).
{
  agent="$(sandbox)/agent"
  out="$(PI_AGENT_DIR="$agent" PI_PROXY_API_KEY="sekret-123" bash "$PI_CONFIG" </dev/null 2>&1)"
  assert_file "models.json written"   "$agent/models.json"
  assert_file "settings.json written" "$agent/settings.json"
  assert_contains "api key substituted" "$(cat "$agent/models.json")" "sekret-123"
  case "$(cat "$agent/models.json")" in
    *"{{"*) bad "no placeholder remains" "found {{ in models.json" ;;
    *)      ok "no placeholder remains" ;;
  esac
  # GNU stat first (Linux/CI), fall back to BSD stat (macOS). BSD `stat -f`
  # means --file-system and exits 0, so trying it first would mask the fallback.
  mode="$(stat -c '%a' "$agent/models.json" 2>/dev/null || stat -f '%Lp' "$agent/models.json")"
  assert_eq "models.json is chmod 600" "600" "$mode"
}

# Idempotency: without --force, an existing file is skipped, not overwritten.
{
  agent="$(sandbox)/agent"
  PI_AGENT_DIR="$agent" PI_PROXY_API_KEY="first" bash "$PI_CONFIG" </dev/null >/dev/null 2>&1
  out="$(PI_AGENT_DIR="$agent" PI_PROXY_API_KEY="second" bash "$PI_CONFIG" </dev/null 2>&1)"
  assert_contains "skips existing without --force" "$out" "skip:"
  assert_contains "original key preserved" "$(cat "$agent/models.json")" "first"
}

# --force overwrites and re-renders with the new secret.
{
  agent="$(sandbox)/agent"
  PI_AGENT_DIR="$agent" PI_PROXY_API_KEY="first" bash "$PI_CONFIG" </dev/null >/dev/null 2>&1
  PI_AGENT_DIR="$agent" PI_PROXY_API_KEY="second" bash "$PI_CONFIG" --force </dev/null >/dev/null 2>&1
  assert_contains "--force re-renders with new key" "$(cat "$agent/models.json")" "second"
}

# Unknown argument is rejected.
{
  agent="$(sandbox)/agent"
  set +e
  PI_AGENT_DIR="$agent" PI_PROXY_API_KEY="x" bash "$PI_CONFIG" --bogus </dev/null >/dev/null 2>&1
  rc=$?
  set -e
  assert_eq "unknown arg exits 2" "2" "$rc"
}

echo "== reset-codex =="

# Keeps config/auth, deletes session state. The keep-list is the data-loss
# guard, so assert both sides: kept files survive, everything else is gone.
{
  home="$(sandbox)"
  mkdir -p "$home/sessions" "$home/skills" "$home/rules" "$home/history"
  for keep in auth.json config.toml AGENTS.md AGENTS.override.md; do touch "$home/$keep"; done
  touch "$home/sessions/s1.json" "$home/history/h.log" "$home/scratch.tmp"
  out="$(CODEX_HOME="$home" bash "$RESET_CODEX" 2>&1)"; rc=$?
  assert_eq "exits 0" "0" "$rc"
  for keep in auth.json config.toml AGENTS.md AGENTS.override.md skills rules; do
    if [ -e "$home/$keep" ]; then ok "kept $keep"; else bad "kept $keep" "$keep was deleted"; fi
  done
  for gone in sessions history scratch.tmp; do
    if [ ! -e "$home/$gone" ]; then ok "cleared $gone"; else bad "cleared $gone" "$gone survived"; fi
  done
}

# Missing CODEX_HOME dir is a clean no-op, not an error.
{
  home="$(sandbox)/does-not-exist"
  out="$(CODEX_HOME="$home" bash "$RESET_CODEX" 2>&1)"; rc=$?
  assert_eq "missing dir exits 0" "0" "$rc"
  assert_contains "missing dir reports no-op" "$out" "nothing to clear"
}

echo "== check:git-identity =="

# Passes when config.local resolves name+email; fails loudly otherwise. Seam: HOME.
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  git config --file "$home/.config/git/config.local" user.name "Work User"
  git config --file "$home/.config/git/config.local" user.email "w@x.co"
  out="$(HOME="$home" bash "$CHECK_GIT_IDENTITY" 2>&1)"; rc=$?
  assert_eq "resolves -> exit 0" "0" "$rc"
  assert_contains "reports the identity" "$out" "Work User"
}
{
  home="$(sandbox)"   # no config.local at all
  set +e; out="$(HOME="$home" bash "$CHECK_GIT_IDENTITY" 2>&1)"; rc=$?; set -e
  assert_eq "missing config.local -> exit 1" "1" "$rc"
  assert_contains "names the fix" "$out" "setup:git-identity"
}
{
  home="$(sandbox)"; mkdir -p "$home/.config/git"
  git config --file "$home/.config/git/config.local" user.name "No Email"   # name but no email
  set +e; out="$(HOME="$home" bash "$CHECK_GIT_IDENTITY" 2>&1)"; rc=$?; set -e
  assert_eq "missing email -> exit 1" "1" "$rc"
}

echo "== check:vscode-symlink =="

# Seams: VSCODE_SETTINGS_LIVE / VSCODE_SETTINGS_REPO.
{
  d="$(sandbox)"; repo="$d/repo.json"; live="$d/live.json"; echo "{}" > "$repo"
  ln -s "$repo" "$live"
  out="$(VSCODE_SETTINGS_LIVE="$live" VSCODE_SETTINGS_REPO="$repo" bash "$CHECK_VSCODE" 2>&1)"; rc=$?
  assert_eq "intact symlink -> exit 0" "0" "$rc"
  assert_contains "reports intact" "$out" "intact"
}
{
  d="$(sandbox)"; repo="$d/repo.json"; live="$d/live.json"; echo "{}" > "$repo"; echo '{"x":1}' > "$live"
  set +e; out="$(VSCODE_SETTINGS_LIVE="$live" VSCODE_SETTINGS_REPO="$repo" bash "$CHECK_VSCODE" 2>&1)"; rc=$?; set -e
  assert_eq "clobbered (regular file) -> exit 1" "1" "$rc"
  assert_contains "names the clobber" "$out" "replaced the settings.json symlink"
}
{
  d="$(sandbox)"; repo="$d/repo.json"; live="$d/live.json"; other="$d/other.json"
  echo "{}" > "$repo"; echo "{}" > "$other"
  ln -s "$other" "$live"   # symlink to a real file that is not the repo copy
  set +e; out="$(VSCODE_SETTINGS_LIVE="$live" VSCODE_SETTINGS_REPO="$repo" bash "$CHECK_VSCODE" 2>&1)"; rc=$?; set -e
  assert_eq "wrong-target symlink -> exit 1" "1" "$rc"
}
{
  d="$(sandbox)"; repo="$d/repo.json"; live="$d/missing.json"; echo "{}" > "$repo"
  out="$(VSCODE_SETTINGS_LIVE="$live" VSCODE_SETTINGS_REPO="$repo" bash "$CHECK_VSCODE" 2>&1)"; rc=$?
  assert_eq "missing live -> exit 0 (warn only)" "0" "$rc"
  assert_contains "warns on missing" "$out" "missing"
}

echo
echo "== summary: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
