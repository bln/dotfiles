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

# Coverage guard (finding #6 regression class): test-lint above only proves the
# files the collector DID pick up are clean - it stays green if the collector
# silently narrows and drops tests/ entirely. So assert the collector actually
# covers every shell file under tests/. We don't reimplement the collector's
# find logic (that would be the copy smell); instead we run the REAL
# lint-shell.sh with a shim `shellcheck` on PATH that records the exact argv the
# script assembled, then check every tests/ shell file is in that argv.
{
  shim_dir="$(sandbox)"
  argv_log="$(sandbox)/shellcheck-argv"
  cat >"$shim_dir/shellcheck" <<EOF
#!/usr/bin/env bash
# Record every path argument (drop leading flags like -x) one per line.
for a in "\$@"; do case "\$a" in -*) ;; *) printf '%s\n' "\$a" ;; esac; done >>"$argv_log"
EOF
  chmod +x "$shim_dir/shellcheck"

  # Force the shim to win over any real shellcheck; DOTFILES_DIR pins the repo.
  run_capture env PATH="$shim_dir:$PATH" DOTFILES_DIR="$REPO" bash "$REPO/scripts/lint-shell.sh"

  if [ ! -s "$argv_log" ]; then
    bad "collector coverage" "shim shellcheck was never invoked (argv log empty)"
  else
    missing=""
    while IFS= read -r f; do
      grep -qxF "$f" "$argv_log" || missing="$missing $f"
    done < <(find "$REPO/tests" -type f -name '*.sh' -not -path '*/.git/*' | sort -u)
    if [ -n "$missing" ]; then
      bad "collector covers every tests/ shell file" "not linted:$missing"
    else
      ok "collector covers every tests/ shell file"
    fi
  fi
}
