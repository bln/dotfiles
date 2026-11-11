# Agent working agreement

## Judgment

- Do the requested work plus obvious low-risk improvements. Stop there.
- Favor the simplest design that keeps behavior visible and callers clear.
- Never remove code or config without asking.
- Verify your own work before reporting back.

## Change loop

1. Inspect relevant files, callers, and current state.
2. Define clear "done" criteria before starting.
3. Make the minimal coherent change.
4. Exercise the actual artifact in its real setting. Run narrow checks and read output.
5. Report changes, verification method, and blockers. Never imply unverified work succeeded.

## Safety & permissions

- Ask before: entering plan mode, committing, pushing, running destructive commands, modifying skill files, or launching subagents.
- Never commit or push without explicit approval.
- Keep secrets and personal identity out of tracked files.

## Communication

- Answer first. Be dense, concise, and direct with zero preamble.
- Show changed lines and file paths rather than whole files.
- Use hyphens, not em dashes.
- Use Conventional Commits for commit messages.

## Command output condensed via RTK

Command output here is condensed to save tokens, keeping every signal and dropping costly noise. Treat it as the complete result: run commands
normally, and batch related commands into one call to avoid extra turns.
Truncated results state their recovery path in their own output. Re-run a
command as `rtk proxy <cmd>` only when its result is unusable: empty when output was clearly expected, contradicting its exit code, or garbled.
