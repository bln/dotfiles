#!/usr/bin/env bash
# shellcheck disable=SC2153 # REPO is exported by tests/run.sh, which sources this file
# Verify-tier (host only): exercise scripts/vscode-profiles against a REAL,
# fully isolated `code` instance - never the user's live VS Code. Isolation is
# via `code --user-data-dir <tmp> --extensions-dir <tmp>`, so installs, profile
# seeding, and prune all happen inside throwaway dirs with zero risk to the
# real profile.
#
# Extensions are installed from a synthetic .vsix built on the fly (a minimal
# zip with package.json + extension.vsixmanifest + [Content_Types].xml), so the
# real install path is exercised OFFLINE - no marketplace, no network, no
# committed binary fixtures.
#
# Host-coupled (needs `code`, `zip`, `jq`, `uuidgen`); host tier only (run by
# `mise run verify`), never CI. Skips cleanly when any dependency or a headless probe is missing.

echo "== vscode-real-code =="

for dep in code zip jq uuidgen; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    skip "vscode-real-code ($dep not installed)"
    return 0
  fi
done

CLI="$REPO/scripts/vscode-profiles"

# Isolated `code`: wrap the real binary so every call is pinned to sandbox dirs.
vrc_ud="$(sandbox)/ud"; vrc_ed="$(sandbox)/ed"
mkdir -p "$vrc_ud" "$vrc_ed"
vrc_bin="$(sandbox)/bin"; mkdir -p "$vrc_bin"
cat >"$vrc_bin/code" <<EOF
#!/usr/bin/env bash
exec command code --user-data-dir "$vrc_ud" --extensions-dir "$vrc_ed" "\$@"
EOF
chmod +x "$vrc_bin/code"

# Headless probe: a fresh isolated list must succeed and be empty. If VS Code
# can't run headless here (no GUI session), skip rather than fail.
if ! "$vrc_bin/code" --list-extensions >/dev/null 2>&1; then
  skip "vscode-real-code (isolated code cannot run headless here)"
  return 0
fi
if [ -n "$("$vrc_bin/code" --list-extensions 2>/dev/null)" ]; then
  skip "vscode-real-code (isolated env not empty; unexpected state)"
  return 0
fi
ok "fresh isolated env lists no extensions"

# Build a synthetic .vsix for extension id <publisher>.<name>.
make_vsix() {
  local pub="$1" name="$2" out="$3" b
  b="$(sandbox)/vsix-$pub-$name"; mkdir -p "$b/extension"
  cat >"$b/extension/package.json" <<EOF
{ "name": "$name", "publisher": "$pub", "version": "0.0.1",
  "engines": { "vscode": "^1.0.0" }, "main": "./x.js" }
EOF
  printf 'module.exports={activate(){}};\n' >"$b/extension/x.js"
  cat >"$b/extension.vsixmanifest" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata><Identity Language="en-US" Id="$name" Version="0.0.1" Publisher="$pub"/><DisplayName>$name</DisplayName><Description>t</Description></Metadata>
  <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>
  <Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json"/></Assets>
</PackageManifest>
EOF
  cat >"$b/[Content_Types].xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="json" ContentType="application/json"/><Default Extension="js" ContentType="application/javascript"/><Default Extension="vsixmanifest" ContentType="text/xml"/></Types>
EOF
  ( cd "$b" && zip -q -r "$out" . )
}

# Repo fixture: global declares acme.galpha; pyth declares acme.pbeta - by ID
# (production always declares ids). To keep the test offline we PRE-INSTALL the
# matching synthetic .vsix files first, so the CLI's "install missing" step
# finds them already present and never reaches the marketplace. This exercises
# the real list / skip-present / prune / seed / teardown paths against genuine
# `code`, just not a live network fetch.
repo="$(sandbox)/repo"; mkdir -p "$repo/profiles/pyth"
gvsix="$(sandbox)/galpha.vsix"; pvsix="$(sandbox)/pbeta.vsix"
make_vsix acme galpha "$gvsix"
make_vsix acme pbeta "$pvsix"
printf 'acme.galpha\n' >"$repo/extensions.txt"
printf 'acme.pbeta\n' >"$repo/profiles/pyth/extensions.txt"
printf '{"editor.tabSize":2}\n' >"$repo/settings.json"

run_cli() {
  env VSCODE_USER_DIR="$vrc_ud/User" VSCODE_REPO_DIR="$repo" \
      VSCODE_CODE_BIN="$vrc_bin/code" "$@"
}

# The CLI seeds a missing named profile headlessly (storage.json entry + dir) as
# the first step of apply. apply then installs each profile's declared-missing
# extensions in the same run - and offline, installing pyth's not-yet-present
# .vsix from the marketplace fails, so this first apply exits nonzero. That is
# expected; what we assert here is that the *seed* landed regardless. We then
# pre-install the .vsix into the now-seeded pyth (offline) and re-apply for a
# clean exit-0 idempotent run below.
"$vrc_bin/code" --install-extension "$gvsix" >/dev/null 2>&1
run_capture run_cli bash "$CLI" apply   # seeds pyth; pyth ext install fails offline (expected)
loc="$(run_cli bash "$CLI" resolve pyth)"
if [ -z "$loc" ]; then
  bad "pyth profile seeded by apply" "resolve pyth returned empty after apply"
  return 0
fi
ok "apply seeds pyth profile headlessly (location resolved)"
assert_dir "apply created pyth profile dir" "$vrc_ud/User/profiles/$loc"
# Install pyth's declared ext + the inherited global ext into pyth from .vsix.
"$vrc_bin/code" --install-extension "$pvsix" --profile pyth >/dev/null 2>&1
"$vrc_bin/code" --install-extension "$gvsix" --profile pyth >/dev/null 2>&1

# ── re-apply is idempotent, files synced, membership correct ─────────────────
run_capture run_cli bash "$CLI" apply
assert_eq "re-apply exits 0" "0" "$RUN_STATUS"
global_list="$("$vrc_bin/code" --list-extensions 2>/dev/null)"
assert_contains "global has acme.galpha" "$global_list" "acme.galpha"
assert_not_contains "global lacks acme.pbeta" "$global_list" "acme.pbeta"
assert_file "settings.json synced into live global" "$vrc_ud/User/settings.json"
pyth_list="$("$vrc_bin/code" --list-extensions --profile pyth 2>/dev/null)"
assert_contains "pyth has own acme.pbeta" "$pyth_list" "acme.pbeta"
assert_contains "pyth inherits global acme.galpha" "$pyth_list" "acme.galpha"

# ── prune: an undeclared ext is warned by default, removed with --prune ───────
extra_vsix="$(sandbox)/extra.vsix"; make_vsix acme extra "$extra_vsix"
"$vrc_bin/code" --install-extension "$extra_vsix" >/dev/null 2>&1

run_capture run_cli bash "$CLI" apply
assert_contains "default warns undeclared acme.extra" "$(cat "$RUN_STDERR")" "acme.extra"
assert_contains "default leaves acme.extra installed" "$("$vrc_bin/code" --list-extensions)" "acme.extra"

run_capture run_cli bash "$CLI" apply --prune
assert_eq "prune exits 0" "0" "$RUN_STATUS"
assert_not_contains "prune removes undeclared acme.extra" "$("$vrc_bin/code" --list-extensions)" "acme.extra"
assert_contains "prune keeps declared acme.galpha" "$("$vrc_bin/code" --list-extensions)" "acme.galpha"

# ── teardown --apply: uninstalls and deletes the seeded pyth profile ──────────
run_capture run_cli env APPLY=true bash "$CLI" teardown --apply
assert_eq "teardown exits 0" "0" "$RUN_STATUS"
assert_eq "teardown deletes pyth (resolve empty)" "" "$(run_cli bash "$CLI" resolve pyth)"
