#!/usr/bin/env bash
# ci: reset-rtk delegates to `rtk gain --reset --yes`. No filesystem seam
# exists, so CI only tests argument parsing and CLI dispatch using RTK_CMD stub.
# Real stats-clearing verification is in host/.

echo "== ci: reset-rtk =="

RESET="$REPO/scripts/reset-rtk.sh"

# Nominal run: calls rtk gain --reset --yes.
{
  stub_dir="$(sandbox)"
  calls="$(sandbox)/calls.txt"
  cat >"$stub_dir/rtk" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"$calls"
echo "Token savings and recall stats reset to zero."
exit 0
EOF
  chmod +x "$stub_dir/rtk"
  out="$(RTK_CMD="$stub_dir/rtk" bash "$RESET" 2>&1)"; rc=$?
  assert_eq "exits 0" "0" "$rc"
  assert_contains "calls gain --reset --yes" "$(cat "$calls")" "gain --reset --yes"
  assert_contains "output confirms reset" "$out" "reset to zero"
}

# --dry-run: prints intent, does not call rtk.
{
  stub_dir="$(sandbox)"
  calls="$(sandbox)/calls.txt"
  printf '#!/usr/bin/env bash\necho "$*" >>"%s"\nexit 0\n' "$calls" >"$stub_dir/rtk"
  chmod +x "$stub_dir/rtk"
  out="$(RTK_CMD="$stub_dir/rtk" bash "$RESET" --dry-run 2>&1)"; rc=$?
  assert_eq "dry-run exits 0" "0" "$rc"
  assert_contains "dry-run says DRY RUN" "$out" "DRY RUN"
  assert_not_exists "dry-run does not call rtk" "$calls"
}

# rtk absent: warns and exits 0.
{
  out="$(RTK_CMD="__no_such_binary__" bash "$RESET" 2>&1)"; rc=$?
  assert_eq "missing rtk exits 0" "0" "$rc"
  assert_contains "warns rtk missing" "$out" "not found"
}

# Unknown argument exits 2.
{
  set +e; out="$(RTK_CMD=/dev/null bash "$RESET" --bogus 2>&1)"; rc=$?; set -e
  assert_eq "unknown arg exits 2" "2" "$rc"
}
