# Working in this repo

Personal macOS dotfiles repository. Keep changes small, explicit, and reversible.

## Ownership

- `home/.config/mise/config.toml` owns global tools, packages, environment, macOS
  preferences, and mise settings.
- `mise.toml` owns repository dotfile declarations, templates, and deployment policy.
- `home/` mirrors `$HOME`; mise deploys it with `symlink-each`.
- Credentials, sessions, caches, databases, generated state, and application state
  stay in native machine-local locations and are never tracked.

## Instructions

- Use Conventional Commits.
- Ask before deleting unrelated files, changing skills, committing, pushing, or making destructive cleanup.
- Never commit secrets or generated state.
