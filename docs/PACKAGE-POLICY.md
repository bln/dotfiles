# Package Policy

## Principle

mise is the single interface for declaring and installing packages on this
workstation. Native package managers (Homebrew, pip, npm) exist as backends but
are never invoked directly.

## What this means in practice

### Allowed

```toml
# home/.config/mise/config.toml
[tools]
node = "22"

[packages]
"brew:ripgrep" = "latest"
"brew:fd" = "latest"
"npm:prettier" = "latest"
```

```bash
# mise tasks and scripts
mise install
mise run bootstrap
```

### Not allowed

```bash
# Direct package manager invocation
brew install ripgrep       # WRONG - use mise packages
brew bundle                # WRONG - no Brewfile
pip install foo            # WRONG - use mise packages or uv
npm install -g prettier    # WRONG - use mise packages
```

### Not allowed in portable code

```bash
# Hard-coded Homebrew paths
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh  # WRONG
```

Instead, detect the prefix dynamically (see `.zshrc` for the pattern).

## Why

1. **Single source of truth** - `config.toml` + `mise.lock` fully describe the
   desired machine state. There is no second manifest to keep in sync.
2. **Reproducibility** - `mise install` converges the machine. No manual steps.
3. **Portability** - If mise adds Linux support tomorrow, the same config works.
   Hard-coded `/opt/homebrew` paths break on other platforms.
4. **Auditability** - One file to review for supply-chain concerns.

## Enforcement

The contract test `tests/contract/test-package-policy.sh` checks on every CI
run that:

- No script, task, or workflow contains `brew install`, `brew uninstall`, or
  `brew bundle`.
- No file under `home/`, `scripts/`, or `tasks/` contains a hard-coded
  `/opt/homebrew` path.

Violations fail CI.

## Exceptions

- `install.sh` installs mise itself (and Homebrew if needed as a mise backend).
  This is the only bootstrapping exception.
- Shell configuration (`.zshrc`) may reference Homebrew plugin paths but must
  use dynamic prefix detection, never hard-coded paths.
- `wipe.sh` may reference package-manager state for cleanup purposes.
