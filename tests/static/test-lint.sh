#!/usr/bin/env bash
# Static: every shell script passes bash -n and shellcheck.
#
# Runs the REAL scripts/lint-shell.sh (the same script the `test` mise task and
# CI invoke), so the harness and CI agree on one lint definition. This is the
# highest-value cheap check: it catches the syntax and quoting bugs that a
# source-grep test sails straight past. Skips shellcheck cleanly if absent
# (lint-shell.sh warns and still runs bash -n); fails the suite on any error.

echo "== static: lint =="

run_capture bash "$REPO/scripts/lint-shell.sh"
if [ "$RUN_STATUS" -eq 0 ]; then
  ok "all shell scripts pass bash -n + shellcheck"
else
  bad "shell lint" "$(cat "$RUN_STDOUT" "$RUN_STDERR")"
fi
