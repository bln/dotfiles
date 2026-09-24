# Testing philosophy

This file is the contract for the test suite. Read it before adding, removing,
or "strengthening" a test. The suite was deliberately rebuilt small; it
re-accretes bloat only if someone ignores the rules below.

## What this repo is, and therefore what can break

This repo converges a fresh mac into a workstation via mise. Only a few classes
of failure can actually hurt the owner, and the suite exists to guard exactly
those:

1. **A broken shell.** mise never runs your `.zshrc`; a bad edit breaks every
   terminal. Grep cannot catch a runtime error in a file that contains the right
   text.
2. **A destructive script misfiring.** teardown / reset-codex / vscode profile
   seeding can delete or clobber real data.
3. **Custom script logic being wrong.** `vscode-profiles` and `git-identity` are
   code *we* wrote; mise does not validate them.
4. **A cross-cutting invariant no single tool owns.** Secrets not committed;
   agent copy-trees in sync.
5. **The converge not working, or not being idempotent,** on a real host.

## The two rules

**Rule 1 - Test behavior and logic, never a file's own text.**
A test must assert something a human cannot eyeball and a tool does not already
check: an exported value, an exit code, a filesystem effect, a routing decision,
a drift computation. If a test would pass or fail purely because a string in a
config/script changed - a mapping line, an alias, a version literal, a
`set -euo` policy line - it is *double-entry bookkeeping*. Delete it. It adds no
safety and breaks every time the config legitimately evolves.

Forbidden patterns (these were removed and must not return):
- `grep`-ing `config.toml` / `install.sh` for a literal that restates the file.
- Enumerating a config list 1:1 ("every one of these 11 tools/vars/mappings…").
- Existence checklists ("these five files exist").
- Locking an implementation line (e.g. asserting a script says `set -u`) when the
  *behavior* that line produces is already tested.

**Rule 2 - Let the consumer validate its own config.**
mise validates mise's config. We do NOT re-implement, in Python or grep, that a
tool is declared, that a package key has a valid backend prefix, that the plan
resolves, that the TOML is structurally sane. That is mise's job, gated in CI by
the `mise config ls` and `mise bootstrap --dry-run` steps in `ci.yml`. Our
harness only checks that each file **parses** for the tool that reads it (TOML,
git config, `zsh -n`, `nvim` headless) - the "did I fat-finger the syntax" line,
nothing more. Same principle for other tools: assert the seam and the behavior,
not the tool's internal rules.

## Organization: one axis only

Tests are split by the single question that decides where they can run:

| Tier | Dir | Needs a real mac? | When |
|---|---|---|---|
| **ci** | `tests/ci/` | No - hermetic, no host tools, no network | every push (Linux + macOS CI), any laptop |
| **host** | `tests/host/` | Yes - installed tools, real `code`, GUI login | `mise run verify` only, never CI |
| **maint** | `tests/maint/` | Sometimes - skips macOS-only checks off-host | run by hand, never `test`/`verify`/CI |

Do **not** re-introduce a static/unit/integration split. That taxonomy tracks
*how* a test is written, which is not a decision anyone needs to make. "Can this
run without a converged mac?" is the only axis that changes where **ci vs host**
tests live.

`maint` is orthogonal: it holds tests for one-off maintenance scripts under
`scripts/maint/` (e.g. `reset-safari-readinglist.sh`) that are run deliberately,
not part of the convergence gate. These tests are **not discovered by
`tests/run.sh`** - it only iterates `ci`/`host`, and its glob is `test-*.sh`
while maint files are named `*.test.sh`. Each maint test is self-contained
(sources `tests/lib/testlib.sh`, prints its own summary) and run by path:
`bash tests/maint/<name>.test.sh`. `tests/maint/discovery-guard.test.sh` locks
this isolation so a future run.sh change cannot silently pull maint into CI.

## The pyramid

```
   host/   e2e smoke on a real mac (few, slow, opt-in):
           converge idempotent · tools+plugins resolve · real `code` apply
   ─────────────────────────────────────────────────────────────
   ci/ contract: config parses · shell starts clean · env contract
   ─────────────────────────────────────────────────────────────
   ci/ behavioral (the wide base): each script's real logic + every
        destructive/safety path, sandboxed and hermetic
```

The base is wide because that is *our* code. The top is thin because a real mac
cannot run in CI and nothing there can be faked.

## Conventions that keep it honest

- **Exercise the real shipped artifact through its seam, never a copy.** Every
  FS-touching script takes its roots from env vars with `${VAR:-default}` (e.g.
  `HOME`, `CODEX_HOME`, `VSCODE_USER_DIR`); tests point those at a `mktemp`
  sandbox. A test that starts by copying a script into a fixture is the smell to
  fix at the script level. If a script is hard to test, make it testable
  (add a seam; make it sourceable; extract the pure decision) - do not copy it.
- **Prefer pure functions over fake binaries.** `vscode-profiles` is sourceable
  (`main` is guarded by `BASH_SOURCE`), so its decision logic - id
  normalization, `set_minus` drift math, `valid_location` - is tested directly
  on plain data in `test-vscode-logic.sh`, with no fake `code`. Only the
  genuinely-integration behavior (seeding, guards, install/prune) uses a fake
  `code` in `test-vscode-apply.sh`. When a test needs a large fake binary and
  many assertions, that is a signal the script is braiding logic with IO -
  extract the logic.
- **Representative cases, not permutation matrices.** One example per behavior
  class, plus *every* destructive/security path. Do not add a fourth "missing
  field" variant or a fifth drift permutation; add a case only for a genuinely
  distinct behavior or a real bug you are pinning.
- **Teardown steps are dry-run by default; guard that default.** Every step of
  the `teardown` task (`teardown-dotfiles.sh`, `teardown-local.sh`,
  `tasks/teardown/rtk`, …) reads `APPLY="${APPLY:-false}"` and touches nothing
  unless `APPLY=true`; the task passes `APPLY="${usage_apply:-false}"` so bare
  `mise run teardown` previews. A new teardown step MUST carry a case proving the
  default touches nothing - assert exit 0, a `DRY RUN` marker, and unchanged
  state (a whole-tree snapshot diff beats per-item probes: see the dry-run case
  in `test-rtk-roundtrip.sh`). This is failure class #2, so it is not optional.
- **Skip cleanly, never fail, on a missing optional dependency** (`jq`,
  `uuidgen`, `zsh`, `nvim`, `brew`). CI runners and laptops differ.
- **GNU-first, BSD-fallback** for `stat`/`date`/`script` (CI is Linux, local is
  macOS); never the reverse.
- Lint (`scripts/lint-shell.sh`) is a separate step of the `test` task, not a
  harness test - keep it that way.

## Design changes are cheaper than drift tests

When two files must agree, prefer removing the duplication over testing the
drift. The mise version lived in three files with a test guarding it; now
`config.toml`'s `min_version` is the single source (install.sh and CI install
latest, which always satisfies the floor), and the test is gone. If you find
yourself writing a test to keep two literals in sync, single-source them
instead.

## Deliberate exceptions

- The Claude skill tree (`home/.config/claude/skills`) is a committed copy of
  the shared tree (`home/.config/skills`), guarded by a parity check in
  `test-contract-agents.sh`. It is duplicated rather than generated at converge
  because `AGENTS.md` forbids automation from touching those trees. The drift
  guard is the accepted cost of that rule.

## Adding a test - the checklist

1. Which failure class (1-5 above) does this guard? If none, do not add it.
2. Does mise/git/zsh already validate this? If yes, do not re-implement it.
3. Would it break on a legitimate config edit without any behavior changing? If
   yes, it is double-entry - redesign or drop it.
4. ci or host? (Can it run without a converged mac?)
5. Real artifact through a seam, representative cases, clean skips.
