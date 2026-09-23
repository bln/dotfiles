#!/usr/bin/env bash
# shellcheck disable=SC2153 # REPO is exported by tests/run.sh
# ci: vscode-profiles PURE logic. The script is sourceable (its `main` is guarded
# by BASH_SOURCE), so these exercise the decision functions directly on plain
# data - no fake `code`, no sandbox subprocess, no storage.json. Splitting the
# pure math out is why the fake-`code` integration file can stay small.
#
# Covered: id normalization, global-inheritance, drift set-math, and the
# security-critical location validator that guards a later `rm -rf`.

echo "== ci: vscode logic =="

CLI="$REPO/scripts/vscode-profiles"

# Run a sourced function in a fresh, isolated bash (never pollutes this shell).
call()     { bash -c 'source "$1"; shift; "$@"' _ "$CLI" "$@"; }
boolcall() { call "$@" && echo ok || echo reject; }

# ── set_minus: the pure core of extension drift math ─────────────────────────
assert_eq "set_minus computes A-not-B" "$(printf 'a\nc')" \
  "$(call set_minus "$(printf 'a\nb\nc')" "$(printf 'b')")"
assert_eq "set_minus empty when subset" "" \
  "$(call set_minus "$(printf 'a\nb')" "$(printf 'a\nb\nc')")"

# ── declared_extensions: strip comments/blanks, lowercase, unique-sort ───────
{
  sb="$(sandbox)"
  printf 'ESBenp.Prettier-VSCode\n# a comment\n\nms-python.python\nESBENP.PRETTIER-VSCODE\n' >"$sb/extensions.txt"
  out="$(VSCODE_REPO_DIR="$sb" call declared_extensions _)"
  assert_eq "normalized, deduped, sorted" "$(printf 'esbenp.prettier-vscode\nms-python.python')" "$out"
}

# ── effective_declared: a named profile inherits the global set ──────────────
{
  sb="$(sandbox)"; mkdir -p "$sb/profiles/pyth"
  printf 'golang.go\n' >"$sb/extensions.txt"
  printf 'ms-python.python\n' >"$sb/profiles/pyth/extensions.txt"
  out="$(VSCODE_REPO_DIR="$sb" call effective_declared pyth)"
  assert_contains "named profile gets its own id"    "$out" "ms-python.python"
  assert_contains "named profile inherits the global" "$out" "golang.go"
  glob="$(VSCODE_REPO_DIR="$sb" call effective_declared _)"
  assert_not_contains "global does not inherit named ids" "$glob" "ms-python.python"
}

# ── valid_location: the rm -rf safety validator ──────────────────────────────
assert_eq "accepts a safe segment"        "ok"     "$(boolcall valid_location 'pyth0001')"
assert_eq "rejects path traversal (..)"   "reject" "$(boolcall valid_location '../../canary')"
assert_eq "rejects a slash"               "reject" "$(boolcall valid_location 'a/b')"
assert_eq "rejects empty"                 "reject" "$(boolcall valid_location '')"

# ── settings composition: base plus profile override, with nested merge ──────
if command -v jq >/dev/null 2>&1; then
  sb="$(sandbox)"; mkdir -p "$sb/profiles/rust"
  printf '%s\n' '{"editor.fontSize":16,"editor.codeActionsOnSave":{"source.fixAll":"explicit","source.organizeImports":"explicit"},"nested":{"base":true}}' >"$sb/settings.base.json"
  printf '%s\n' '{"editor.fontSize":18,"editor.codeActionsOnSave":{"source.organizeImports":"always"},"nested":{"override":true}}' >"$sb/profiles/rust/settings.json"
  rendered="$sb/rendered.json"
  VSCODE_REPO_DIR="$sb" call render_settings rust "$rendered"
  merged="$(jq -S -c . "$rendered")"
  assert_contains "settings merge keeps base scalar" "$merged" '"nested":{"base":true,"override":true}'
  assert_contains "settings merge lets override win" "$merged" '"editor.fontSize":18'
  assert_contains "settings merge preserves nested base value" "$merged" '"source.fixAll":"explicit"'
  assert_contains "settings merge applies nested override" "$merged" '"source.organizeImports":"always"'

  printf '%s\n' '{"editor.fontSize":18,"editor.codeActionsOnSave":{"source.fixAll":"explicit","source.organizeImports":"always"},"nested":{"base":true,"override":true},"extension.setting":"enabled"}' >"$sb/live.json"
  delta="$sb/delta.json"
  VSCODE_REPO_DIR="$sb" call settings_delta "$sb/settings.base.json" "$sb/live.json" "$delta"
  delta_json="$(jq -S -c . "$delta")"
  assert_eq "settings delta captures only overrides" \
    '{"editor.codeActionsOnSave":{"source.organizeImports":"always"},"editor.fontSize":18,"extension.setting":"enabled","nested":{"override":true}}' \
    "$delta_json"
else
  skip "settings composition (jq not installed)"
fi
