# Working in this repo

This is a single mise-based macOS dotfiles repo. Keep it simple: one home
payload, a top-level install script, small mise tasks, and one global mise config.

`home/` mirrors `$HOME`; most entries are symlinked by mise, while agent
instructions and skills are explicitly copy-managed. The rest of the repository
is machinery and is never symlinked: top-level `install.sh` and `tests/` run against the
checkout; `tasks/setup/` holds mise file-tasks (run as `mise run setup:...`)
that generate machine-local state. If you add repo-local helper scripts, put
them in the top-level `scripts/` dir (not shipped), mirroring that split.

## Rules

- Do not split this repo into profile, machinery, policy, or package projects.
- Do not add a Python project, verifier package, uv task dependency, or test
  framework for repo automation without explicit approval.
- Keep `install.sh` as a thin shell wrapper. Keep `verify`, `test`, `bootstrap`,
  `update`, and `teardown` as the exposed mise tasks in `mise.toml`. Non-trivial helper
  scripts live in `scripts/` with test seams that `tests/run.sh` exercises.
  The test harness stays plain bash in `tests/` (no bats or other framework
  without approval).
- Before adding, removing, or strengthening tests, read `docs/TESTING.md`
  and follow its testing philosophy.
- Do not add dependencies to `[tools]` or `[bootstrap.packages]`
  without explicit approval.
- Do not create, edit, move, or delete files under `home/.config/skills` or
  `home/.config/claude/skills` without explicit approval.
- Personal identity stays out of tracked files. Use machine-local git identity
  files created by `mise run setup:git-identity`.

For the design rationale behind these rules see `docs/ARCHITECTURE.md`; for
contributor process (code rules, tests, commit style) see `CONTRIBUTING.md`.

To discover tools that mise can install, run mise registry; declare approved
tools directly under [tools] using the registry's supported name and version.

# RTK (when installed)

When `rtk` is available (`command -v rtk >/dev/null 2>&1`), prefix every shell
command with `rtk`: `rtk git status`, `rtk ls src/`, and so on. Keep the prefix
inside command chains. Commands without an RTK filter are still prefixed; use
`rtk proxy <cmd>` only when filtered output is unusable. If `rtk` is unavailable,
run commands normally without the prefix.

## Verification

For dotfiles changes, prefer:

```bash
mise -C ~/dotfiles run test    # lint (shellcheck) + script harness against mktemp sandboxes
mise -C ~/dotfiles run verify  # the above, plus live machine-state checks
mise -C ~/dotfiles dotfiles status --missing  # native agent-resource drift
```

`test` is host-independent (this is what CI runs); `verify` layers on the
live-machine checks, which need a converged macOS host: `mise doctor`
(installation health, run first so later status output is trustworthy),
bootstrap/dotfiles status (tools, symlinks, and macOS defaults drift), and
the git identity and VSCode symlink guard scripts. If live machine state is
not safe or available, run `test` and state clearly that live verification
was skipped.

CI runs on Linux (GNU coreutils); local `mise run test` runs on macOS (BSD
coreutils). When a script or test shells out to `stat`/`date`/`sed`/etc., use
the GNU form first with a BSD fallback (`stat -c '%a' … 2>/dev/null || stat -f
'%Lp' …`), never the reverse - BSD `stat -f` exits 0 on Linux and silently masks
the fallback.
