#!/usr/bin/env bash
# wipe.sh behavioral tests are intentionally absent.
#
# wipe.sh calls `mise bootstrap dotfiles unapply`, `mise uninstall --all`, and
# `mise implode` even in --dry-run mode. These commands operate on the live mise
# installation regardless of the HOME or PATH overrides used for step 1, so any
# non-trivial execution of wipe.sh during the test suite risks destroying the
# environment that is running the tests.
#
# Argument parsing and --dry-run acceptance are covered by
# tests/integration/wipe-args.sh.
echo "== unit: wipe (skipped — see integration/wipe-args.sh) =="
