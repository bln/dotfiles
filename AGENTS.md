# Working in this repo

This is a personal macOS dotfiles repository.

- `mise.toml` owns language runtimes, command-line tools, host packages, casks,
  fonts, dotfiles, and macOS preferences; `mise.lock` pins tool artifacts.
- `home/` mirrors `$HOME`; mise's `symlink-each` dotfiles mode deploys it.
- Agent credentials, sessions, caches, and application state stay in native home
  directories and are never tracked.
- Prefer native mise, Git, and macOS commands over repository wrappers.
- Keep the repository small. Add automation or tests only when a real custom
  behavior requires them.
- Ask before commits, pushes, destructive cleanup, or changes to skill files.
- Keep secrets and personal identity out of tracked files.
- Use Conventional Commits when committing.
