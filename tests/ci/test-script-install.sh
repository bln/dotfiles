#!/usr/bin/env bash
# ci: install.sh uses the checkout's machine config and repo task context even
# when launched from another directory. The fake mise records calls; the real
# install.sh performs the path, trust, and ordering logic.

echo "== ci: install =="

{
  home="$(sandbox)"
  repo_link="$home/dotfiles"
  stub_dir="$(sandbox)"
  calls="$(sandbox)/mise-calls.txt"

  ln -s "$REPO" "$repo_link"
  mkdir -p "$home/.config/git"
  touch "$home/.config/git/identity-personal" "$home/.config/git/identity-work"

  cat >"$stub_dir/mise" <<'EOF'
#!/usr/bin/env bash
printf 'config=%s args=%s\n' "$MISE_GLOBAL_CONFIG_FILE" "$*" >>"$MISE_LOG"
exit 0
EOF
  chmod +x "$stub_dir/mise"

  # shellcheck disable=SC2016 # $1 expands in the nested bash process
  run_capture env \
    HOME="$home" \
    MISE_LOG="$calls" \
    PATH="$stub_dir:/usr/bin:/bin" \
    bash -c 'cd /tmp && exec bash "$1"' bash "$repo_link/install.sh"

  assert_eq "install exits 0 outside checkout" "0" "$RUN_STATUS"
  log="$(cat "$calls")"
  assert_contains "uses repository machine config" "$log" "config=$repo_link/home/.config/mise/config.toml"
  assert_contains "trusts the global machine config" "$log" "args=trust $repo_link/home/.config/mise/config.toml"
  assert_contains "bootstraps from repo context" "$log" "args=-C $repo_link bootstrap --yes --force-dotfiles"
  assert_not_contains "does not use remote bootstrap" "$log" "--from"
  assert_not_contains "skips complete identity" "$log" "setup:git-identity"
}
