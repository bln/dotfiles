# mise registry tools: Claude Code and Codex

Date: 2026-10-01

## Finding

Both command-line tools are available as mise registry shorthands in mise
`v2026.9.18`:

```toml
[tools]
claude-code = "latest"
codex = "latest"
```

The registry selects release-binary backends by default:

- `claude-code` -> `aqua:anthropics/claude-code`, exposing `claude`.
- `codex` -> `aqua:openai/codex`, exposing `codex` and
  `codex-code-mode-host`.

Codex also has `npm:@openai/codex` as a registry fallback. Claude Code has an
`http:claude` fallback. The default selection for both is Aqua, so the normal
path does not require Node or npm at runtime.

## Verification

The installed mise binary reports `2026.9.18 macos-arm64`. These commands were
read-only:

```sh
mise registry --json claude-code
mise registry --json codex
mise install --dry-run --verbose claude-code@latest codex@latest
```

The dry-run resolved the current selectors to `claude-code@2.1.288` and
`codex@0.160.0` for this host and reported the Aqua backends. Versions are
release-time data and will change.

A temporary isolated configuration was also passed through
`mise lock --dry-run --platform macos-arm64`; both tools resolved to lockfile
entries for the macOS arm64 platform.

## Repository implications

Before the switch, the configuration installed these commands as Homebrew
casks:

```toml
[bootstrap.packages]
"brew-cask:claude-code" = "latest"
"brew-cask:codex" = "latest"
```

Switching to mise tools means adding the two `[tools]` entries and removing
those cask declarations. That switch has now been applied. The former Homebrew
casks (`claude-code` 2.1.285 and `codex` 0.160.0) were explicitly uninstalled,
the lockfile was regenerated for macOS arm64, and the mise-managed tools were
installed at `claude-code` 2.1.288 and `codex` 0.160.0.

Removing the declarations alone would not uninstall already-installed casks;
that required the explicit Homebrew uninstall step used here.

## Sources

- [Claude Code registry entry](https://github.com/jdx/mise/blob/v2026.9.18/registry/claude.toml)
- [Codex registry entry](https://github.com/jdx/mise/blob/v2026.9.18/registry/codex.toml)
- [mise registry documentation](https://github.com/jdx/mise/blob/v2026.9.18/docs/registry.md)
- [mise npm backend documentation](https://github.com/jdx/mise/blob/v2026.9.18/docs/dev-tools/backends/npm.md)
