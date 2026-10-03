# mise `bootstrap --from` investigation

Date: 2026-10-01

## Question

Can this repository replace a separate repository/bootstrap flow with:

```sh
curl -fsSL https://mise.run | sh
mise bootstrap --from <repository> --from-dir <checkout>
```

The source and documentation below are pinned to mise `v2026.9.18`, the minimum
version declared by this repository. The installed binary reports
`2026.9.18 macos-arm64`.

## Conclusion

Yes, `mise bootstrap --from` can bootstrap this repository from a Git URL and
eliminates a separate `mise trust` step. It is a replacement for the
repository-checkout part of an onboarding flow, not for installing mise itself.

For a remote-first flow, use the documented installer and invoke the installed
binary by its documented default path:

```sh
curl -fsSL https://mise.run | sh
"$HOME/.local/bin/mise" bootstrap \
  --from https://github.com/bln/dotfiles.git \
  --from-dir "$HOME/dotfiles" \
  --yes --locked
```

`--from-dir` is optional. Without it, mise uses
`$MISE_DATA_DIR/bootstrap-repo`. The path is a checkout destination, not a
local source-directory argument. A non-empty destination must already be a Git
checkout whose `origin` exactly matches the requested URL.

This is not an exact drop-in replacement for the current `install.sh`:

- The command must still run a mise binary after the installer. The documented
  installer does not promise that mise is immediately on the current shell's
  `PATH`; its default executable is `~/.local/bin/mise`.
- `--from` accepts a Git repository URL and clones/reuses a checkout. It does
  not bootstrap arbitrary uncommitted contents from the current local checkout.
- If the default checkout directory is used, this repository's symlinked
  dotfiles will point into mise's data directory rather than a stable
  `~/dotfiles` checkout. Supplying a stable `--from-dir` avoids that trade-off.
- The current macOS arm64 policy guard remains a reason to keep a small wrapper
  if unsupported hosts should fail with the repository's explicit message.

For the current locally cloned workflow, `mise -C "$repo" bootstrap` remains
clearer and preserves the checkout that owns the resulting symlinks. The
`--from` flow is appropriate if onboarding should begin from the repository URL
rather than from a pre-cloned working tree.

## Documentation findings

The official Bootstrap guide distinguishes three repository shapes:

1. A bootstrap project containing `mise.toml` and source files uses
   `mise bootstrap --from <url>`.
2. A repository containing global mise configuration such as `config.toml`,
   `conf.d/`, and `tasks/` uses `mise bootstrap --adopt <url>`.
3. A shared dotfile-history setup repository also uses `--adopt`.

For a bootstrap project, the guide says that `--from` clones the project and
applies its `mise.toml`; `--from-dir` selects the checkout location; the
repository is trusted for that invocation; and an existing checkout must have
the requested URL as its `origin`. The CLI reference confirms that
`--from-dir` is specifically the directory used for the repository cloned by
`--from`.

Sources:

- [Bootstrap workflow](https://github.com/jdx/mise/blob/v2026.9.18/docs/bootstrap.md#L47-L84)
- [Bootstrap CLI reference](https://github.com/jdx/mise/blob/v2026.9.18/docs/cli/bootstrap.md#L34-L43)
- [Installing mise](https://github.com/jdx/mise/blob/v2026.9.18/docs/installing-mise.md#L78-L91)

## Implementation trace

### 1. Flag dispatch

`src/cli/bootstrap.rs` defines `--from` as a Git URL and `--from-dir` as a
path that requires `--from`:

- [Bootstrap argument definitions](https://github.com/jdx/mise/blob/v2026.9.18/src/cli/bootstrap.rs#L77-L108)

`run_with_notices` dispatches any invocation containing `--from` or `--adopt`
to `run_from`; a bootstrap subcommand cannot be combined with either option:

- [Bootstrap dispatch](https://github.com/jdx/mise/blob/v2026.9.18/src/cli/bootstrap.rs#L1363-L1383)

### 2. Checkout selection and reuse

For `--from`, `run_from` parses the Git URL and optional `?ref=`, then chooses
`--from-dir` or defaults to `$MISE_DATA_DIR/bootstrap-repo`. A non-empty
existing directory is reused only after its `origin` is validated. The clone or
fast-forward operation happens before the bootstrap child process starts:

- [Checkout selection and child handoff](https://github.com/jdx/mise/blob/v2026.9.18/src/cli/bootstrap.rs#L1944-L2060)
- [Existing-checkout origin validation](https://github.com/jdx/mise/blob/v2026.9.18/src/cli/bootstrap.rs#L208-L231)
- [Clone, update, and dry-run behavior](https://github.com/jdx/mise/blob/v2026.9.18/src/cli/bootstrap.rs#L4601-L4680)

On a first-run `--dry-run`, a missing checkout is reported but not cloned, so
there is no child configuration to preview until the checkout exists.

### 3. Automatic trust

The parent process does not persist a trust record or require a separate
`mise trust` command for `--from`. After checkout, `run_child_bootstrap`:

1. Canonicalizes the checkout path.
2. Re-runs the same mise executable with `--cd <checkout>`.
3. Removes the parent-only `--from`, `--from-dir`, and related checkout flags
   while forwarding ordinary bootstrap flags such as `--yes`, `--locked`,
   `--dry-run`, `--only`, and `--skip`.
4. Appends the checkout to the child process's `MISE_TRUSTED_CONFIG_PATHS`.

Sources:

- [Child argument construction](https://github.com/jdx/mise/blob/v2026.9.18/src/cli/bootstrap.rs#L2060-L2100)
- [Forwarded-argument filtering](https://github.com/jdx/mise/blob/v2026.9.18/src/cli/bootstrap.rs#L2242-L2270)
- [Trust-path environment variable documentation](https://github.com/jdx/mise/blob/v2026.9.18/docs/configuration.md#L814-L817)
- [Trust-path matching in the loader](https://github.com/jdx/mise/blob/v2026.9.18/src/config/config_file/mod.rs#L590-L710)

This is a special `--from` handoff, not the general implicit-trust behavior of
`mise bootstrap`. In the top-level command dispatcher, the commands that
implicitly trust their active config are `exec`, `install`, `run`, `watch`, and
starting daemons; ordinary `bootstrap` is not in that list:

- [Implicit active-config trust policy](https://github.com/jdx/mise/blob/v2026.9.18/src/cli/mod.rs#L471-L480)
- [Trust initialization and active-config handling](https://github.com/jdx/mise/blob/v2026.9.18/src/cli/mod.rs#L1086-L1155)

The documentation's wording that the repository is trusted “for this
invocation” matches the implementation: the child receives a trusted-path
environment entry rather than the parent necessarily writing a durable trust
record.

### 4. Which configuration file is loaded

The child is started with `--cd <checkout>`, so normal configuration discovery
runs from the cloned project. The documented local project names include
`mise.toml`, `mise/config.toml`, `.mise/config.toml`, `.config/mise.toml`, and
`.config/mise/config.toml`. A repository-root `config.toml` is not a listed
project configuration name.

The source's actual local filename list includes `mise.toml` and
`mise/config.toml`, but not `<project-root>/config.toml`:

- [Documented config filenames](https://github.com/jdx/mise/blob/v2026.9.18/docs/configuration.md#L36-L60)
- [Actual local config filename list](https://github.com/jdx/mise/blob/v2026.9.18/src/config/mod.rs#L2257-L2300)
- [Hierarchy/config-path loading](https://github.com/jdx/mise/blob/v2026.9.18/src/config/mod.rs#L2790-L2825)

This is the important distinction for this repository:

- The repository root's **`mise.toml`** is the bootstrap project configuration
  consumed by `--from`.
- `~/.config/mise/config.toml` is the normal user-global configuration path.
  It can be merged into a project invocation, but it is not the file that
  makes a repository a `--from` bootstrap project.
- A repository whose primary configuration is global `config.toml`,
  `conf.d/`, or global `tasks/` should use `--adopt`, not `--from`.
- A repository-root plain **`config.toml`** should not be relied on for
  `--from`.

The current repository therefore has the correct source filename: `mise.toml`.
Its root lockfile is also the correct lockfile. The lockfile implementation
explicitly maps `mise.toml` to the adjacent `mise.lock`:

- [Lockfile path resolution](https://github.com/jdx/mise/blob/v2026.9.18/src/lockfile.rs#L2190-L2234)

Thus `--locked` on the child bootstrap uses the cloned repository's root
`mise.lock`. The separate dotfile mapping to
`~/.config/mise/mise.lock` is for the later global configuration symlink; it is
not needed for the initial `--from` lookup.

## Verification performed

I created two temporary Git repositories and invoked the installed mise binary
with an isolated temporary global-config path:

1. A repository containing `mise.toml` with a `[tasks.bootstrap]` task and a
   root `config.toml` was bootstrapped with:

   ```sh
   mise bootstrap --from <origin> --from-dir <checkout> \
     --dry-run --yes --only task
   ```

   Debug output showed the child invocation with `--cd <checkout>` and:

   ```text
   config: <checkout>/mise.toml
   bootstrap: running `bootstrap` task
   [bootstrap] $ echo from-mise-toml
   ```

   There was no trust prompt; this verifies the child trust handoff.

2. A repository containing only a root `config.toml` with the same task did not
   run the task. Debug output reported:

   ```text
   bootstrap: no `bootstrap` task defined, skipping
   ```

   This verifies that root `config.toml` is not a substitute for root
   `mise.toml` in the `--from` project flow.

Both tests used `--dry-run`; no host packages, tools, dotfiles, or macOS
settings were changed.

## The `mise.lock` dry-run warning

The warning:

```text
mise WARN unknown field in ~/.config/mise/mise.lock: lockfile_version
```

is a dry-run false positive, not a malformed lockfile. This repository maps
`mise.lock` to `~/.config/mise/mise.lock` as a symlink in `[dotfiles]`.
During `bootstrap --dry-run`, mise simulates the post-dotfiles configuration
so hooks and later phases can be previewed. The v2026.9.18 implementation
classifies every target under the mise config directory as a possible TOML
configuration target, including `~/.config/mise/mise.lock`, then parses the
lockfile body with the ordinary `MiseToml` parser. `lockfile_version` is valid
for the lockfile parser but is not a field in `MiseToml`, so the generic TOML
unknown-field warning is emitted.

The real lockfile reader explicitly removes and interprets `lockfile_version`,
so the checked-in `mise.lock` is valid. An actual dotfiles apply does not emit
the warning, and skipping the dotfiles phase does not emit it either. The
`--force-dotfiles` flag does not affect this warning.

Sources:

- [Dry-run config simulation](https://github.com/jdx/mise/blob/v2026.9.18/src/cli/bootstrap.rs#L2411-L2549)
- [Generic mise TOML parser](https://github.com/jdx/mise/blob/v2026.9.18/src/config/config_file/mise_toml.rs#L722-L734)
- [Lockfile parser](https://github.com/jdx/mise/blob/v2026.9.18/src/lockfile.rs#L1383-L1420)

Removing the lockfile dotfile mapping would hide the warning but would stop
managing the global lockfile symlink. The correct fix belongs upstream in the
dry-run target classification; for this repository the warning can be
ignored when running `--dry-run`.

## Recommendation for this repository

Keep the current local-checkout flow unless remote-first onboarding is a goal.
If remote-first onboarding is desired, a small installer can be reduced to:

```bash
mise="$HOME/.local/bin/mise"

if [[ ! -x "$mise" ]]; then
  curl -fsSL https://mise.run | sh
fi

"$mise" bootstrap \
  --from https://github.com/bln/dotfiles.git \
  --from-dir "$HOME/dotfiles" \
  --yes --locked
```

The local repository's explicit macOS arm64 guard can be retained around this
flow. If `install.sh` is run from an already cloned repository, the simpler and
more deterministic operation remains:

```sh
"$HOME/.local/bin/mise" -C "$repo" bootstrap --yes --locked
```

That form preserves local edits, uses the existing stable checkout, and does
not need `--from` to clone or validate another checkout.
