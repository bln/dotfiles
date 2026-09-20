# dotfiles

[![CI](https://github.com/bln/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/bln/dotfiles/actions/workflows/ci.yml)

A declarative macOS development environment managed by
[mise](https://mise.jdx.dev/). One command converges a fresh Mac: tools, dotfile
symlinks, macOS defaults, packages (formulae, casks, fonts, Mac App Store apps),
VS Code extensions, and a global uv-managed Python.

mise is the sole user-facing control plane. Backend identifiers such as `brew:`
and `brew-cask:` in `[bootstrap.packages]` are mise resource keys, not a direct
Homebrew workflow. There is no Brewfile.

## Quick start

```sh
curl -fsSL https://mise.run | sh
curl -fsSL https://raw.githubusercontent.com/bln/dotfiles/main/install.sh | bash
exec zsh -l
```

Or, from a clone (use the **https** URL - it must match the `--from` URL in
`install.sh`, or mise's checkout reuse bails):

```sh
git clone https://github.com/bln/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
exec zsh -l
```

`install.sh` installs mise, then hands the whole converge to
`mise bootstrap --from`: it clones/reuses the repo, trusts it, and runs the
8-phase bootstrap (tools, packages, dotfiles, macOS defaults, and the repo's
`[tasks.bootstrap]` for VS Code extensions + uv python), then prompts for a
machine-local git identity. It is a **first-run** entrypoint; re-converge with
`dot run update`. Preview a bootstrap with `mise bootstrap --dry-run`.

## Design principles

1. **One interface.** Use mise to install, update, inspect, and verify the
   machine. Never call a backend package manager directly.
2. **Declarative state.** `home/.config/mise/config.toml` describes the host.
   `mise.toml` defines repository tasks. Edit the source, then apply.
3. **Safe re-runs.** Bootstrap and setup tasks are idempotent.
4. **Explicit ownership.** Linked files are owned by the repo; shared files use
   include or copy-once; secrets are generated locally.
5. **Local secrets stay local.** Identity and credentials are never committed.

## Layout

```text
dotfiles/
├── install.sh                  # first-run bootstrap (mise bootstrap --from)
├── mise.toml                   # repo-local tasks: verify, test, bootstrap, update, teardown
├── AGENTS.md                   # working rules for agents and humans
├── CLAUDE.md                   # includes AGENTS.md for Claude Code
├── LICENSE
├── .github/
│   ├── workflows/ci.yml        # CI: lint + test + bootstrap plan
│   ├── dependabot.yml
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── ISSUE_TEMPLATE/
├── scripts/
│   ├── check-git-identity.sh
│   ├── lint-shell.sh
│   ├── reset-codex.sh
│   ├── teardown-dotfiles.sh    # teardown step: mise dotfiles unapply
│   ├── teardown-local.sh       # teardown step: remove machine-local files
│   └── vscode-profiles         # mini-CLI: apply/check/pull/teardown VS Code profiles
├── tasks/
│   └── setup/
│       └── git-identity        # prompted machine-local git identity
├── tests/
│   ├── run.sh                  # test harness (run.sh [ci|host|all])
│   ├── lib/testlib.sh          # assertion helpers + sandbox management
│   ├── ci/                     # hermetic: script logic, shell startup, format parse
│   └── host/                   # needs a converged mac (tools, real code); not CI
├── docs/
│   └── ARCHITECTURE.md         # design rationale + package policy
└── home/                       # payload managed in $HOME by mise dotfiles
    ├── .zshenv
    └── .config/
        ├── pi/agent/AGENTS.md   # copied into the Pi agent root
        ├── codex/AGENTS.md      # copied into the Codex root
        ├── skills/              # copied to ~/.agents/skills for Pi and Codex
        ├── claude/CLAUDE.md     # copied into the Claude root
        ├── claude/skills/       # independent copied Claude skill tree
        ├── mise/config.toml     # THE source of truth: tools, packages, defaults
        ├── mise/mise.lock
        ├── git/                # config + global ignore (identity is machine-local)
        ├── zsh/                # .zshrc, .zprofile
        ├── nvim/init.lua       # default Neovim config
        ├── nvim-lazyvim/       # LazyVim starter config
        ├── nvim-kickstart/     # Kickstart.nvim config
        ├── ghostty/config
        ├── gitui/
        ├── vscode/             # VS Code profiles (settings + extension lists), owned by scripts/vscode-profiles
        ├── starship.toml
        ├── npm/npmrc
        └── uv/uv.toml
```

## Source of truth

| Layer | Source | Apply |
|---|---|---|
| Tools (node, uv) | `home/.config/mise/config.toml` `[tools]` | `mise install` |
| Packages (formulae, casks, fonts, MAS apps) | `home/.config/mise/config.toml` `[bootstrap.packages]` | `mise bootstrap packages apply` |
| Dotfile symlinks | `home/` + `[dotfiles]` table | `mise dotfiles apply` |
| Agent instructions and skills | explicit `[dotfiles]` entries in copy mode | `mise dotfiles apply` |
| macOS defaults | `[bootstrap.macos.*]` | `mise bootstrap macos defaults apply` |
| VS Code profiles (settings + extensions) | `home/.config/vscode/` (per-profile `extensions.txt` + files) | `scripts/vscode-profiles apply` |
| Shell bootstrap | `home/.zshenv` | zsh startup |
| Interactive environment, activation, aliases, and functions | `home/.config/zsh/.zshrc` | `exec zsh` |
| Git identity | machine-local, routed by remote host (untracked) | `mise run setup:git-identity` |

### Agent resources

Agent instructions and skills are copied as real files and directories because
Pi, Codex, and Claude can write in their configuration roots. Only these
resources are repository-owned:

- `~/.config/pi/agent/AGENTS.md`
- `~/.config/codex/AGENTS.md`
- `~/.agents/skills/**` from `home/.config/skills/**`
- `~/.config/claude/CLAUDE.md`
- `~/.config/claude/skills/**` from its independent source tree

Agent settings, credentials, sessions, databases, caches, plugins, and Codex
system skills remain machine-local and ignored. Use the native mise commands:

```sh
mise dotfiles diff
mise dotfiles apply
mise dotfiles status --missing
```

`mise dotfiles pull` pulls shared mise history; it is not a live-to-repository
capture. Do not capture an entire writable agent root. Deliberate individual
instruction-file capture can use `mise dotfiles add` after review. Skill trees
remain repository-authored.

## Adding software

1. **Versioned portable tool** (mise registry or GitHub/npm/cargo backend):
   add to `[tools]` in `home/.config/mise/config.toml`, then `mise install`.
2. **Native host package or macOS app**: add to `[bootstrap.packages]`, then
   `mise bootstrap packages apply`.
3. **Stateful setup** (symlinks, includes, generated config): create an
   idempotent file task under `tasks/`.
4. **Dev-only dependency** (shellcheck, etc.): add to `mise.toml` `[tools]`.

See `docs/ARCHITECTURE.md` for the full backend preference order and package policy.

### Managing VS Code profiles

VS Code profiles are owned on disk under `home/.config/vscode/`, driven by the
`scripts/vscode-profiles` mini-CLI. Extensions are profile-scoped state (like
Neovim plugins), not global tools, so `code` owns their lifecycle - mise no
longer shims or versions them.

Layout: the `vscode/` root is the **global** profile; each `profiles/<name>/`
is a **named** profile. Extensions are plain-text id lists (one per line, `#`
comments); other profile files (`settings.json`, `keybindings.json`,
`tasks.json`, `snippets/`) are synced in copy mode when present.

```
home/.config/vscode/
├── settings.json          # global profile
├── extensions.txt         # global extension ids
└── profiles/
    ├── python/            # extensions.txt + settings.json (curated Python template)
    ├── go/                # settings.json (golang.go is global; native test explorer)
    ├── doc/               # extensions.txt + settings.json (curated Doc Writer template)
    └── node/              # extensions.txt + settings.json (curated Node.js template)
```

- **Add / remove an extension**: edit the profile's `extensions.txt`, then run
  `scripts/vscode-profiles apply` (or `dot run update`). Named profiles inherit
  the global set ("globals expected everywhere").
- **Sync behavior**: `apply` installs declared-but-missing extensions per
  profile and seeds a missing named profile headlessly. Prune (installed but
  not declared) is warned by default; pass `--prune` (or `dot run update`,
  which prunes and runs `code --update-extensions`) to uninstall them.
- **Drift / capture**: `vscode-profiles check` reports live-vs-repo drift;
  `vscode-profiles pull` captures live profile files back into the repo after
  UI edits (copy mode - pull or lose them).
- **Safety**: seeding/deleting a profile mutates VS Code's `storage.json`, which
  a running VS Code rewrites on exit. Those paths refuse to run while VS Code is
  open (`--force` overrides). Extension installs and file copies are unguarded.
- Find an extension's ID with `code --list-extensions`.

## Configuration ownership

The repo owns some files outright and shares others with the tools that write
them. See "Configuration ownership strategies" in `docs/ARCHITECTURE.md` for the
symlink / include / copy-once / generate breakdown.

## Common commands

```sh
mise -C ~/dotfiles tasks              # list the public task interface
mise -C ~/dotfiles run test           # host-independent repository tests
mise -C ~/dotfiles run verify         # repository + installed-machine checks
mise -C ~/dotfiles run update         # upgrade tools, packages, dotfiles
mise -C ~/dotfiles run bootstrap      # finish post-bootstrap setup (idempotent)
mise bootstrap status                 # show declared machine-state drift
mise bootstrap --dry-run              # preview bootstrap without applying
```

The `dot` alias expands to `mise -C "${DOTFILES_DIR:-$HOME/dotfiles}"`, so
`dot run verify` works from any directory.

## Neovim configurations

The default configuration remains available as nvim or the v alias. The
additional configurations use Neovim's NVIM_APPNAME mechanism, so each one
gets separate plugin, data, cache, and state directories:

    v          # default dotfiles config
    vz         # LazyVim
    vk         # Kickstart.nvim

The LazyVim starter snapshot comes from LazyVim/starter at commit
803bc181d7c0d6d5eeba9274d9be49b287294d99; the Kickstart snapshot comes from
nvim-lua/kickstart.nvim at commit 80743df53d8f7058fc5b60e41f1081d11df9c880.
The first launch of each alternate config installs its plugins and requires
network access.

## Testing and CI

`mise run test` (from the repo root, or `dot run test` anywhere) lints every
shell script and runs the **ci** tier - hermetic tests that need no host state,
exactly what CI runs. `mise run verify` additionally runs the **host** tier
(tools on PATH, plugins loaded, real VS Code) plus mise health and
declared-state drift on a converged macOS host.

The suite is intentionally small and organised by one question - *does this
need a real mac?* - not by test category. It guards behavior, script logic, and
data-loss paths; it does NOT restate the config or re-test mise. Read
`docs/TESTING.md` before adding, removing, or "strengthening" a test - it is the
contract that keeps the suite from re-accreting double-entry checks.

## Teardown

`mise run teardown` (or `dot run teardown`) defaults to a dry run. With `--apply`
it removes repository-owned state: dotfile symlinks (via `mise dotfiles unapply`),
declared VS Code extensions and seeded named profiles, and machine-local files
(git identity, uv cache).
It then prints the two commands to finish manually - these can't be task steps
(`mise uninstall` re-shims the runner mid-task; `mise implode` deletes mise
itself):

```sh
dot run teardown            # dry run: preview removals
dot run teardown --apply    # execute, then run the printed commands:
mise uninstall --all --yes
mise implode --config --yes
```

It does not uninstall Homebrew, and does **not** revert macOS system defaults
(dock, finder, keyboard) - defaults write records no prior value, so there is
nothing to restore.

## Contributing

See `CONTRIBUTING.md` for where changes belong, code rules, and testing. Run
`mise run test` before opening a pull request. Report security issues privately
per `SECURITY.md`.

## License

See `LICENSE`.
