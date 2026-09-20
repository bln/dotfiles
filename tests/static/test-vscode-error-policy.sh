#!/usr/bin/env bash
# Static: scripts/vscode-profiles keeps its deliberate error policy.
#
# The script drives tools whose nonzero exits are NORMAL signals (grep no-match,
# `code --list-extensions` on an unregistered profile, cmp on a diff), so it runs
# under `set -u` alone - NOT `set -e`/`pipefail`, which would abort a whole
# multi-profile apply on the first such signal. Truly fatal failures (the atomic
# storage.json rewrites) are handled with explicit `|| die` instead. The unit
# suite proves the behavior; this locks the policy line itself so a well-meaning
# "add set -euo pipefail for safety" edit fails loudly here with the rationale,
# not silently at runtime on the next comment-only profile.

echo "== static: vscode error policy =="

CLI="$REPO/scripts/vscode-profiles"
assert_file "vscode-profiles exists" "$CLI"

# The active shell-options line (ignore comments and the `set --` positional
# reset). Must be exactly `set -u`.
setline="$(grep -nE '^[[:space:]]*set[[:space:]]+-[a-zA-Z]' "$CLI" | grep -v '^[0-9]*:[[:space:]]*#')"

if [ "$(printf '%s\n' "$setline" | grep -c .)" != 1 ]; then
  bad "vscode-profiles has exactly one active set-options line" \
    "expected one, found:"$'\n'"${setline:-<none>}"
elif printf '%s' "$setline" | grep -qE 'set[[:space:]]+-u[[:space:]]*$'; then
  ok "vscode-profiles uses 'set -u' (no errexit/pipefail)"
else
  bad "vscode-profiles uses 'set -u' (no errexit/pipefail)" \
    "error policy changed - errexit/pipefail treats normal tool signals as fatal and aborts multi-profile apply; see the Error policy comment in the script. Line: $setline"
fi
