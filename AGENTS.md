# Working in this repo

Personal macOS dotfiles repository. Keep changes small, explicit, and easy to revert.

## Ownership

- `home/.config/mise/config.toml` owns global mise settings, tools, packages,
  environment, macOS preferences, and repository dotfile deployment.
- `home/` mirrors `$HOME`; mise deploys tracked files as relative symlinks.
  Explicit copy and merge entries are defined in `home/.config/mise/config.toml`.
- Use each tool's native config discovery
- Credentials, sessions, caches, databases, generated state, and application state
  remain machine-local and are never tracked.

## Instructions

- Use Conventional Commits.
- Never commit secrets or generated state.
- Ask before deleting unrelated files, committing, pushing, or performing destructive cleanup.
