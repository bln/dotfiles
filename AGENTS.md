# Working in this repo

This is a single mise-based macOS dotfiles repo. Keep it simple: one home
payload, top-level install/wipe scripts, small mise tasks, and one global mise config.

`home/` mirrors `$HOME` (symlinked by mise). Everything else is repo machinery:
top-level `install.sh`/`wipe.sh` and `tests/` run against the checkout and are
never symlinked; `home/.config/mise/tasks/` holds mise tasks that ship to
`$HOME` and run as `mise run ...`. If you add repo-local helper scripts, put
them in a top-level `scripts/` dir (not shipped), mirroring that split.

## Rules

- Do not split this repo into profile, machinery, policy, or package projects.
- Do not add a Python project, verifier package, uv task dependency, or test
  framework for repo automation without explicit approval.
- Keep `install.sh` and `wipe.sh` as shell. Keep `verify`, `lint`, and `test`
  inline as mise tasks in `mise.toml`. Non-trivial task logic (the `check:*`
  guards, `reset-codex`) lives as file tasks with test seams that
  `tests/run.sh` exercises, not as inline TOML. The test harness stays plain
  bash in `tests/` (no bats or other framework without approval).
- Do not add dependencies to `[tools]`, `[bootstrap.packages]`, or the Brewfile
  without explicit approval.
- Do not create, edit, move, or delete files under `home/.agents/skills`
  without explicit approval.
- Personal identity stays out of tracked files. Use machine-local git identity
  files created by `mise setup:git-identity`.
- Use Conventional Commits for commits.
- Run the narrowest meaningful verification before finishing implementation.

## Verification

For dotfiles changes, prefer:

```bash
mise -C ~/dotfiles run lint    # bash -n + shellcheck on every shell script
mise -C ~/dotfiles run test    # script harness against mktemp sandboxes
mise -C ~/dotfiles verify      # the above, plus live machine-state checks
```

`lint` and `test` are host-independent (this is what CI runs). CI runs them on
Linux (GNU coreutils); local `mise run test` runs on macOS (BSD coreutils). When
a script or test shells out to `stat`/`date`/`sed`/etc., use the GNU form first
with a BSD fallback (`stat -c '%a' … 2>/dev/null || stat -f '%Lp' …`), never the
reverse - BSD `stat -f` exits 0 on Linux and silently masks the fallback.
`verify` layers
on the live-machine checks, which need a converged macOS host: `mise doctor`
(installation health, run first so later status output is trustworthy),
bootstrap/dotfiles status (tools, symlinks, and macOS defaults drift),
`brew bundle check`, and the `check:*` guards (VSCode settings symlink, git
identity). If live machine state is not safe or available, run `lint` and `test`
and state clearly that live verification was skipped.
