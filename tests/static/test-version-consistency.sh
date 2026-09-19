#!/usr/bin/env bash
# Static: the pinned mise version is identical everywhere it is hard-coded.
#
# The version lives in three independent places that must not drift:
#   - home/.config/mise/config.toml  min_version = "X"
#   - install.sh                     MISE_VERSION="X"  (curl bootstrap)
#   - .github/workflows/ci.yml       MISE_VERSION=X    (two install steps)
# A bump to one and not the others means CI installs a different mise than
# install.sh, or config demands a newer mise than either installs. Pure
# cross-file data invariant, no runtime - hence static.

echo "== static: version consistency =="

extract() {
  # $1 = file, $2 = sed/grep-friendly extractor label; echoes the version(s).
  case "$2" in
    config) grep -E '^min_version[[:space:]]*=' "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' ;;
    install) grep -oE 'MISE_VERSION="?[0-9]+\.[0-9]+\.[0-9]+"?' "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' ;;
    ci) grep -oE 'MISE_VERSION=[0-9]+\.[0-9]+\.[0-9]+' "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' ;;
  esac
}

config_v="$(extract "$REPO/home/.config/mise/config.toml" config)"
install_v="$(extract "$REPO/install.sh" install)"
ci_vs="$(extract "$REPO/.github/workflows/ci.yml" ci)"

if [ -n "$config_v" ]; then ok "config.toml declares a min_version ($config_v)"; else bad "config.toml min_version present" "no min_version found"; fi
if [ -n "$install_v" ]; then ok "install.sh pins MISE_VERSION ($install_v)"; else bad "install.sh MISE_VERSION present" "no MISE_VERSION found"; fi

assert_eq "install.sh version matches config min_version" "$config_v" "$install_v"

# ci.yml may pin the same version in more than one step; every occurrence must match.
ci_mismatch=0
while IFS= read -r v; do
  [ -n "$v" ] || continue
  [ "$v" = "$config_v" ] || ci_mismatch=$((ci_mismatch + 1))
done <<EOF
$ci_vs
EOF
if [ -n "$ci_vs" ]; then
  assert_eq "every ci.yml MISE_VERSION matches config" "0" "$ci_mismatch"
else
  bad "ci.yml pins MISE_VERSION" "no MISE_VERSION found in ci.yml"
fi
