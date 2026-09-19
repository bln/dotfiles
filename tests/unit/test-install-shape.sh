#!/usr/bin/env bash
# Static: the install.sh wrapper and its config are shaped as the mise-native
# entrypoint the redesign requires. Replaces the old ordering test (which drove
# a fake mise through install.sh's now-gone trust/bootstrap/mode sequence).
#
# Asserts against the real files, no execution:
#   - install.sh hands converge to `mise bootstrap --from` (not manual trust)
#   - the version pin is present and there is no MISE_GLOBAL_CONFIG_FILE bridge
#   - git-identity is a foreground call guarded on identity-personal, NOT a hook
#   - [tasks.bootstrap] lives in mise.toml, never config.toml (global pollution)
#   - config.toml has no [bootstrap.hooks].final key

echo "== install-shape =="

INSTALL="$REPO/install.sh"
CONFIG="$REPO/home/.config/mise/config.toml"
MISETOML="$REPO/mise.toml"

install_src="$(cat "$INSTALL")"
assert_contains "install.sh uses mise bootstrap --from" "$install_src" "mise bootstrap --from"
assert_contains "install.sh pins MISE_VERSION"          "$install_src" 'MISE_VERSION="2026.9.9"'
assert_not_contains "install.sh drops MISE_GLOBAL_CONFIG_FILE bridge" "$install_src" "MISE_GLOBAL_CONFIG_FILE"
assert_not_contains "install.sh drops manual mise trust" "$install_src" "mise trust"
assert_contains "install.sh calls git-identity in foreground" "$install_src" "mise run setup:git-identity"
assert_contains "git-identity call is guarded on identity-personal" "$install_src" "identity-personal"

# git-identity must be a foreground call, not a bootstrap hook that skips on non-TTY.
config_src="$(cat "$CONFIG")"
assert_not_contains "config.toml has no [bootstrap.hooks].final" "$config_src" "final ="
assert_not_contains "config.toml final hook not present (alt spacing)" "$config_src" "final="

# The bootstrap task belongs to the repo mise.toml, never the global config -
# a global `bootstrap` task is runnable/listed from any dir (namespace pollution).
# Same reasoning puts teardown in mise.toml: its scripts live in the repo, so it
# must run with config_root = repo (a global task resolves config_root to $HOME).
misetoml_src="$(cat "$MISETOML")"
assert_contains "mise.toml defines [tasks.bootstrap]" "$misetoml_src" "[tasks.bootstrap]"
assert_not_contains "config.toml has no [tasks.bootstrap]" "$config_src" "[tasks.bootstrap]"
assert_contains "mise.toml defines [tasks.teardown]" "$misetoml_src" "[tasks.teardown]"
assert_not_contains "config.toml has no [tasks.teardown]" "$config_src" "[tasks.teardown]"
