# Security policy

## Reporting

Do not open a public issue for a credential leak, unsafe destructive behavior, or
supply-chain vulnerability. Use GitHub private vulnerability reporting when
enabled, or contact the repository owner privately.

Include affected paths, impact, reproduction steps that do not expose secrets, and
a suggested mitigation when available.

## Supported version

Only the current `main` branch is supported.

## Sensitive data

Never commit API tokens, private keys, passwords, cookies, employer-specific
identity, or generated local configuration. If a secret is committed, revoke it
immediately before removing it from Git history.

The bootstrap wrapper and the teardown task modify workstation state. Review them
before execution and use dry-run modes first (`mise run teardown` defaults to a
dry run; `mise bootstrap --dry-run` previews a converge).
