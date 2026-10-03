# Working in this repo

This is a personal macOS dotfiles repository.

- `Brewfile` owns Homebrew formulae, casks, fonts, and VS Code extensions.
- `home/` mirrors `$HOME`; GNU Stow links it into place.
- `home/.config/mise/config.toml` owns language runtimes only.
- `macos.sh` owns macOS preferences.
- Agent credentials, sessions, caches, and application state stay in native home directories and are never tracked.
- Prefer native Homebrew, mise, Stow, and macOS commands over repository wrappers.
- Keep the repository small. Add automation or tests only when a real custom behavior requires them.
- Ask before commits, pushes, destructive cleanup, or changes to skill files.
- Keep secrets and personal identity out of tracked files.
- Use Conventional Commits when committing.
