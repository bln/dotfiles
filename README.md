# dotfiles

A mise-based macOS dotfiles repo. One command converges a fresh Mac: tools,
dotfile symlinks, macOS defaults, Homebrew packages, Mac App Store apps, VSCode
extensions, and a global uv-managed Python.

## Install

On a fresh machine:

```bash
git clone <this-repo-url> ~/dotfiles
~/dotfiles/install.sh
exec zsh -l
```

`install.sh` installs mise into `~/.local/bin`, points the live mise config at
this checkout, trusts it, runs `mise bootstrap --yes`, then prompts for a
machine-local git identity. It is a one-shot converge with no dry-run; to preview
the heavy step first, run `mise bootstrap --dry-run`.

## Philosophy

Four decisions govern everything here:

1. **One convergence engine.** mise is the single entry point - it installs
   tools, applies dotfile symlinks, writes macOS defaults, and drives Homebrew
   and uv. No competing bootstrap scripts or dotfile managers.
2. **One declarative source of truth per layer.** Each thing lives in exactly
   one place and is *applied*, never hand-edited on the machine (see the table
   below). Homebrew owns casks/MAS/extensions; mise `[tools]` owns
   version-resolved tools; `home/` owns dotfiles.
3. **Secrets and identity are never tracked.** git identity and the pi API key
   are machine-local, rendered into `chmod 600` files the repo never sees.
   `useConfigOnly` makes a missing identity fail loudly, not commit as the wrong
   person.
4. **Small, reversible, verifiable.** `wipe.sh` reverses `install.sh`; `verify`
   proves the machine matches the repo. Where a step is not cleanly reversible
   (macOS defaults), that is stated rather than faked.

The working rules that follow from these live in [AGENTS.md](AGENTS.md).

## Common tasks

Every change follows the same shape: **edit the source, then apply.** Never edit
live state on the machine - it will be overwritten on the next converge.

| To... | Edit | Then run |
| --- | --- | --- |
| Add/remove a CLI tool with a pinned version | `home/.config/mise/config.toml` `[tools]` | `mise install` |
| Add/remove a Homebrew package, cask, MAS app, or VSCode extension | `home/.config/homebrew/Brewfile` | `brew bundle` |
| Change a shell/editor/git dotfile | the file under `home/` | `mise dotfiles apply` |
| Change a macOS default (dock, finder, keyboard) | `[bootstrap.macos.*]` in the mise config | `mise bootstrap macos defaults apply` |
| Set up git identity on a new machine | (prompted) | `mise run setup:git-identity` |
| Create or rotate the pi agent API key | (prompted, or `PI_PROXY_API_KEY`) | `mise run setup:pi-config --force` |
| Update everything and re-check | nothing | `mise update` |
| Check the machine matches the repo | nothing | `mise audit` |
| Add a new shell script | `scripts/` or `home/.config/mise/tasks/` | `mise run lint` |

After any change, run `mise -C ~/dotfiles verify` to confirm the machine still
matches the repo.

## Commands

```bash
mise bootstrap status          # show declared machine-state drift
mise bootstrap --dry-run       # preview bootstrap work without applying
mise update                    # upgrade all layers, reapply dotfiles, then audit
mise audit                     # full verification from anywhere (delegates to the repo)
mise -C ~/dotfiles verify      # the same checks, run in-repo (what CI and audit call)
mise -C ~/dotfiles run lint    # bash -n + shellcheck on every shell script
mise -C ~/dotfiles run test    # run the script test harness (tests/run.sh)
mise reset-all                 # clear Claude Code, Codex, and Pi agent sessions
~/dotfiles/wipe.sh --dry-run   # preview a wipe
~/dotfiles/wipe.sh             # tear down (see Wipe below)
```

`mise audit` and `mise update` are global - they work from any directory, so you
never have to switch into the repo. Both delegate the actual checks to the
repo-local `verify` task (`doctor`, bootstrap/dotfiles drift, `brew bundle
check`, lint, test, and the `check:*` guards), which needs a converged macOS
host; `update` runs `audit`'s checks as its final step. `lint` and `test` are
host-independent and are what CI runs. Session-reset tasks (`reset-claude`,
`reset-codex`, `reset-pi`, `reset-all`) clear agent session state while
preserving configuration.

## Layout

```text
dotfiles/
├── install.sh              # fresh-machine bootstrap (one-shot converge)
├── wipe.sh                 # reverse of install (shell-only)
├── mise.toml               # repo-local tasks: verify, lint, test, update, reset-*, check:*
├── .mise/tasks/            # repo-local file tasks (check:git-identity, check:vscode-symlink)
├── AGENTS.md               # repo working rules (agents + humans)
├── CLAUDE.md               # includes AGENTS.md for Claude Code
├── .github/workflows/      # CI: lint + test
├── tests/
│   └── run.sh              # test harness for the parameterized scripts
└── home/                   # payload symlinked into $HOME by mise dotfiles
    ├── .zshenv
    ├── .agents/            # AGENTS.md + skills, shared across agent CLIs
    ├── .pi/                # pi agent extensions
    └── .config/
        ├── mise/           # config.toml (source of truth), lock, tasks/
        ├── homebrew/Brewfile
        ├── git/            # config + global ignore (identity is machine-local)
        ├── zsh/            # .zshrc, .zprofile
        ├── nvim/
        ├── ghostty/
        ├── vscode/
        ├── starship.toml
        ├── npm/
        └── uv/
```

## Source of truth

The authoritative location for each managed layer. Change the source, not the
machine.

| Layer | Source | Apply |
| --- | --- | --- |
| mise tools | `home/.config/mise/config.toml` `[tools]` | `mise install` |
| dotfiles | `home/` plus the `[dotfiles]` table | `mise dotfiles apply` |
| macOS defaults | `[bootstrap.macos.*]` | `mise bootstrap macos defaults apply` |
| Homebrew, MAS, VSCode | `home/.config/homebrew/Brewfile` | `brew bundle` |
| git identity | machine-local prompt (untracked) | `mise run setup:git-identity` |
| pi agent config | `home/.config/mise/tasks/setup/pi-config.d/*.template` | `mise run setup:pi-config` |

**pi agent config** is rendered from templates rather than symlinked, because
`models.json` holds a proxy API key. `mise run setup:pi-config` fills the
templates into `~/.pi/agent/` as `chmod 600` files (set `PI_PROXY_API_KEY` or
enter it at the prompt); existing files are left untouched unless you pass
`--force`. Only the placeholder templates are tracked.

## Wipe

To tear the machine back down:

```bash
~/dotfiles/wipe.sh --dry-run   # preview every removal first
~/dotfiles/wipe.sh             # prompts for confirmation, then removes
```

It reverses install in order: remove machine-local identity, unapply dotfiles,
uninstall Brewfile-managed formulae/casks/VSCode-extensions/Mac-App-Store-apps
(the last needs `sudo`), uninstall mise-managed tools, then implode mise last.

It is **not** a full inverse: it does not revert the macOS system defaults (dock,
finder, keyboard) written at install - `defaults write` records no prior value,
so there is nothing to restore - and it leaves Homebrew itself installed.
