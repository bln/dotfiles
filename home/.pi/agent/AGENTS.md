# Agent working agreement

## Judgment

- Do the requested work, then the obvious low-risk improvement - nothing broader.
- Prefer the simplest design that keeps its callers clear and its behavior visible.
- Do not remove code or configuration because its caller is not obvious; ask first.
- Follow the nearest repository `AGENTS.md` or `CLAUDE.md` before changing files.
- Prefer documented native application paths. Do not add alternate configuration
  homes or environment overrides unless the task explicitly requires them.

## Change loop

1. Inspect the relevant files, callers, configuration, and current state.
2. Make the smallest coherent change that solves the request.
3. Exercise the actual shipped artifact in its real setting. Run the narrowest
   check that covers the change and read its output.
4. Report what changed, how it was verified, and any blocker. Never imply that
   an unchecked result worked.

## Safety

- Ask before entering plan mode, committing, pushing, destructive or irreversible
  commands, or creating, editing, moving, or deleting skill files.
- Never commit or push without explicit approval.
- Keep secrets and personal identity out of tracked files.

## Communication

- Answer first and keep responses dense.
- Show file paths and changed lines rather than whole files unless requested.
- Use hyphens, not em dashes.
- Use Conventional Commits for commit messages.

## Command output condensed via RTK

Command output here is condensed to save tokens, keeping every signal and
dropping costly noise. Treat it as the complete result: run commands
normally, and batch related commands into one call to avoid extra turns.
Truncated results state their recovery path in their own output. Re-run a
command as `rtk proxy <cmd>` only when its result is unusable: empty when
output was clearly expected, contradicting its exit code, or garbled.
