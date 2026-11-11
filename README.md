# Personal Dotfiles

Personal workstation configuration for macOS on Apple Silicon. Mise 2026.11.5 or newer manages tools, Homebrew packages and applications, dotfile deployment, and selected macOS preferences. The `home/` directory mirrors `$HOME`.

## Install

```sh
git clone https://github.com/bln/dotfiles.git ~/dotfiles
cd ~/dotfiles

curl -fsSL --proto '=https' https://mise.run | sh
MISE_CONFIG_DIR="$PWD/home/.config/mise" "$HOME/.local/bin/mise" \
  bootstrap --yes --force-dotfiles
```

Bootstrap installs the configured tools and Homebrew packages, deploys dotfiles, and applies the macOS settings. It also runs the configured `bootstrap` task, which ensures a default managed Python is installed through uv and installs the Claude Code, Pi, and Codex command line tools when missing. Those tools use their vendor install scripts.

`--force-dotfiles` overwrites existing files that conflict with whole-file dotfile entries. Review those destinations before bootstrapping if they contain files you need.

## Git identity

Git is configured not to guess a commit identity. Create the machine-local files before making commits:

```sh
touch ~/.config/git/identity-personal ~/.config/git/identity-local
```

Add a `[user]` section with a name and email to each file. Git reads the personal identity first and the local identity second, so values in the local file take precedence. Both files are machine-local and ignored by Git.

## Configuration

Mise provides one declarative source for workstation setup, while keeping decisions grouped by concern. This keeps tool versions, deployment, and system preferences reviewable as ordinary configuration rather than hiding them in a custom setup framework.

The home directory mirror is the portable baseline. Files are linked where the repository owns them, shared agent instructions are copied to their client locations, and settings are merged when an application file may also contain machine-local values. Credentials, Git identity, sessions, caches, databases, and application state remain local.

The lockfile records tool versions for macOS Apple Silicon, the platform this setup targets. Updates can be reviewed with the configuration that produced them.

## Shell and editors

Zsh uses XDG directories, Mise activation, and Starship. Its interactive defaults include eza listing aliases with system fallbacks, fzf file/directory/history pickers with bat previews, prefix-aware history search, and zoxide's `z` command. Vim, Ghostty, Zed, and VS Code configurations are included.

## Maintenance

Inspect the configured state and Mise setup:

```sh
mise bootstrap --dry-run
mise bootstrap status --missing
mise dot status --missing
mise doctor
```

Apply dotfiles alone, or run the repository update task:

```sh
mise dot apply --force --yes
mise run update
```

The update task self-updates Mise, upgrades configured packages and tools, prunes obsolete deployed dotfiles, then updates Claude Code, Pi, and Codex. The cleanup task prunes Mise-managed tool versions and configured Homebrew packages and casks:

```sh
mise run cleanup
```

To refresh the locked versions for requests such as `lts` and `latest`, then install them:

```sh
mise lock --global --bump
mise install
```

## Uninstall

```sh
./uninstall.sh --yes
```

The script unapplies managed dotfiles, prunes Mise-owned Homebrew packages and casks, removes Mise-managed tool versions and Mise configuration/state, and removes the Claude Code binary and local data. It leaves this repository in place. It does not restore removed user files or macOS preferences.

## CI

GitHub Actions runs on macOS 26. It checks Bash and Zsh syntax, Mise configuration and dotfile-root settings, a dry-run bootstrap, and Git whitespace.
