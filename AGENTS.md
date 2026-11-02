s Working in this repo

Personal macOS dotfiles repository. Keep changes small, explicit, and easy to revert.

## Ownership

- `home/.config/mise/config.toml` owns global tools, packages, environment, macOS
  preferences, mise settings, and dotfile deployment.
- `home/` mirrors `$HOME`; mise deploys it with `symlink-each`.
- Credentials, sessions, caches, databases, generated state, and application state
  remain machine-local and are never tracked.

## Instructions

- Use Conventional Commits.
- Never commit secrets or generated state.
- Ask before deleting unrelated files, committing, pushing, or performing
  destructive cleanup.
