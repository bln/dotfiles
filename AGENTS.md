# Working in this repo

Personal macOS dotfiles repository. Keep changes small, explicit, and easy to revert.

## Ownership

- `mise.toml` owns repository dotfile deployment and tasks.
- `home/.config/mise/config.toml` owns global mise settings, tools, packages,
  environment, and macOS preferences.
- `home/` mirrors `$HOME`; mise deploys tracked files as relative symlinks.
  Explicit copy and merge entries are defined in `mise.toml`.
- Credentials, sessions, caches, databases, generated state, and application state
  remain machine-local and are never tracked.

## Instructions

- Use Conventional Commits.
- Never commit secrets or generated state.
- Ask before deleting unrelated files, committing, pushing, or performing
  destructive cleanup.
