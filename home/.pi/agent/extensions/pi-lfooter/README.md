# Pi LFooter

`pi-lfooter.ts` is the repository-owned Pi footer extension. It replaces Pi's default footer with a cache-focused telemetry footer while keeping the extension itself thin. Usage accounting is implemented separately in `pi-lfooter/metrics.ts` so the important behavior is deterministic and testable without starting Pi.

## Motivation

Prompt caching is easiest to validate by looking at all three cache-related input fields for every model request:

```text
input       uncached input tokens processed for this request
cache-read  input tokens served from the prompt cache
cache-write input tokens written to the prompt cache
```

Looking at only one field can hide a broken cache prefix. A healthy multi-turn sequence normally has:

- `cache-read` growing as prior history is reused
- `cache-write` small after the initial request
- `input` representing the new uncached tail
- a high effective cache hit rate

The footer therefore shows both the latest completed model turn and cumulative session totals.

## Display

On a wide terminal the full footer has three rows. The `TURN` and `SESSION` labels use separate theme-aware background chips, and the metric columns are width-aligned so the pipes line up:

```text
󰚩 openai-codex/gpt-5.5 • 󰈈 high • 󰘬 dotfiles (main)       CTX [███░░░░░░░] 57.8k/200k (28.9%)
 TURN    in 2.1k  | cr 55.3k | cw 1.0k | out 1.4k | all 59.8k | hit 94.7% | reason 1.0k
 SESSION in 12.7k | cr 301k  | cw 3.4k | out 8.9k | all 326k  | hit 94.9% | reason 4.1k | cw1h 0
```

The leading label padding is part of each background chip. The exact background and foreground colors come from Pi's active theme rather than hard-coded ANSI colors.

## Modes

The extension supports two display modes. Full mode is the default:

```bash
pi --lfooter-mode=full
```

It renders the model/context row plus aligned `TURN` and `SESSION` usage rows.

Compact mode renders and computes only the first row:

```bash
pi --lfooter-mode=compact
```

```text
󰚩 codex/gpt-5.5 • 󰈈 high • 󰘬 dotfiles (main)       CTX [███░░░░░░░] 57.8k/200k (28.9%)
```

Compact mode does not scan branch entries or session entries and does not calculate turn/session token totals, cache-hit rates, reasoning totals, or cache-write-1h totals. It only reads model, thinking, git location, and current context usage.

The mode can also be changed during an interactive session:

```text
/lfooter-mode compact
/lfooter-mode full
/lfooter-mode
```

The command without an argument toggles the current mode. Switching back to full reconstructs the usage state from Pi's persisted session data.

The symbols in the first row are Nerd Font glyphs:

- `󰚩` model
- `󰈈` thinking level
- `󰘬` git branch

The metric rows use short, explicit labels so the three cache fields remain easy to distinguish:

| Label | Meaning |
| --- | --- |
| `in` | Uncached input tokens |
| `cr` | Cache-read tokens |
| `cw` | Cache-write tokens |
| `out` | Generated output tokens |
| `all` | `in + cr + cw + out` |
| `hit` | `cr / (in + cr + cw)` |

If a provider reports them, the rows also append:

- `reason`: reasoning tokens, a subset of `out`
- `cw1h`: one-hour cache-write tokens, a subset of `cw`

Optional subsets are never added a second time to `all`. When an optional field is available in one row but not the other, both rows retain the same column and the unavailable value is shown as `—` so the separators stay aligned.

## Per-turn accounting

The `TURN` row is the latest completed assistant response. It is populated from Pi's `turn_end` lifecycle event and uses the response's provider usage object.

A Pi turn is one model response cycle. A single user prompt can cause multiple turns when the model calls tools. The footer intentionally shows the latest model turn, since that is the request where a cache break is easiest to spot.

The cache hit rate is weighted by tokens, not averaged across percentages:

```text
turn hit = cache-read / (input + cache-read + cache-write)
```

Output tokens do not belong in this denominator because they are generated after the prompt is read.

Zeros are always displayed. In particular, `cr 0` on an intermediate turn is useful diagnostic information and is not hidden.

## Per-session accounting

The `SESSION` row aggregates all usage persisted by Pi in the current session:

- assistant message usage from normal turns
- `usage` entries, including cache warming
- tool-result usage from nested model calls
- compaction usage
- branch-summary usage

This follows the accounting used by Pi's built-in footer and represents total recorded provider usage. Its cache rate is calculated from summed token fields:

```text
session hit = total cache-read /
              (total input + total cache-read + total cache-write)
```

This is a weighted rate. A large request contributes proportionally more than a small request.

The session total includes side calls such as compaction. It is also intentionally billing-oriented: an aborted or failed assistant request is included if Pi persisted provider usage for it, even though it is not selected as the latest completed `TURN`.

## Context usage

The first row shows Pi's current active context separately from session totals:

```text
CTX [gauge] used/context-window (percentage)
```

The value comes from `ctx.getContextUsage()`:

- Pi uses the latest valid provider-reported context usage where available.
- It falls back to the usage components when needed.
- It estimates messages added after the latest measured response.
- After compaction, Pi reports the token count as unknown until another model response provides a reliable value.

Unknown values are shown as `?`, for example:

```text
CTX [??????????] ?/200k (?)
```

This avoids presenting an estimate as an exact provider measurement.

## Colors and warnings

The footer uses Pi's active theme instead of hard-coded ANSI colors:

- positive `cache-read` values use the success color
- `cache-write` uses the warning color
- zero `cache-read` is dim on an initial cold turn
- zero `cache-read` is highlighted as an error on later turns
- hit rates at or above 70% are healthy
- hit rates between 0% and 70% are warnings
- a zero hit rate is an error except for a cold initial turn
- context usage follows Pi's 70% warning and 90% error thresholds
- `TURN` uses the theme's selected-item background and normal text foreground.
- `SESSION` uses the theme's custom-message background and foreground.
- core metric columns are padded by visible width so their separators align between rows
- long locations are reduced to the repository basename and branch before truncation

A zero cache read does not prove one specific cause. Possible causes include a changed prompt prefix, a model switch, cache TTL expiry, or a provider-side cache decision. The footer reports the observable usage, not an inferred cause.

## When to be concerned

No single cell is enough to diagnose a problem. Look for repeated patterns across several turns:

| Signal | Healthy | Investigate | Concern |
| --- | --- | --- | --- |
| `CTX` | Below 70% | 70-90% | Above 90% |
| `TURN hit` | 90% or higher | 70-90% | Below 70% |
| `SESSION hit` | 90% or higher | 70-90% | Below 70% |
| `TURN cr` | Large and nonzero | Drops sharply | Zero repeatedly |
| `cw` compared with `cr` | Much smaller | Similar magnitude | Large on every turn |

The extension's visual thresholds are intentionally conservative: hit rates at or above 70% are shown as healthy, positive rates below 70% are warnings, and a zero hit rate on a later turn is an error. The practical 90% threshold above is a stricter rule for deciding whether to investigate.

A zero `cr` on the first request is normal. It can also be expected after a model switch, branch change, compaction, system-prompt change, tool change, or cache expiration. It becomes suspicious when it repeats without an obvious cause.

A large `cw` is normal when creating a new cache prefix. Investigate when cache writes remain large on every turn while cache reads stay small. A large `all` value alone is not a health problem; it measures volume. The concerning combination is large `all`, high `CTX`, and a falling cache-hit rate.

`reason` is a subset of `out`, and `cw1h` is a subset of `cw`. Neither is an additional total or an independent cache warning.

## When to write a handoff and start a new session

Compaction is a normal Pi workflow. It summarizes older messages, keeps recent messages, and preserves the original session entries. It is useful when the work is still coherent and the summary can retain the important decisions.

A fresh session with a deliberate handoff is usually better when one or more of these conditions apply:

- compaction happens repeatedly and the context climbs back near the limit soon afterward
- the same files, decisions, or requirements need to be rediscovered after each compaction
- the model begins asking questions that were already settled
- the task has reached a natural milestone and the next phase has a different goal
- the old transcript is mostly historical detail while the next step can be described concisely
- a compaction summary would be nearly as long or expensive as a focused handoff
- cache reuse becomes unstable after repeated compactions and `TURN hit` drops or `TURN cr` repeatedly returns to zero

There is no fixed number of compactions that is always safe. One or two compactions can be efficient for a continuous task. The warning sign is not the count by itself; it is whether each compaction gives the model a useful, stable working context.

The `SESSION` row can also show concise compaction details at its right edge:

```text
SESSION ... | cw1h 641k                              CMP 3 · pre 920k · use 8.4k
```

- `CMP 3`: three persisted compactions in the current session
- `pre 920k`: the context size recorded before the latest compaction
- `use 8.4k`: total provider tokens recorded for the latest compaction summary, not monetary cost

The compaction indicator is right-prioritized on narrow terminals. Optional session metrics may truncate before it does. If a compaction entry has no recorded usage or `tokensBefore`, that part is omitted.

A useful handoff should contain:

```markdown
## Goal
## Current state
## Completed work
## Key decisions
## Files changed
## Verification
## Open questions
## Next action
## Constraints and critical context
```

After saving it to a project-appropriate file, start a clean session with `/new` and begin with something like:

```text
Read path/to/handoff.md. Continue from "Next action". Do not repeat completed work.
```

Use a tracked project document only when the handoff is part of the project record. For a temporary personal transition, use a machine-local path instead. The old session remains available through `/resume` if historical context is needed.

## Responsive layout

Full mode preserves the important cache fields on narrow terminals:

```text
󰚩 openai-codex/gpt-5.5 󰘬 dotfiles (main)  CTX 57.8k/200k (28.9%)
 TURN    in 2.1k | cr 55.3k | cw 1.0k | out 1.4k | hit 94.7%
 SESSION in 12.7k | cr 301k  | cw 3.4k | out 8.9k | hit 94.9%
```

Compact mode intentionally reduces the footer to the first line and skips usage accounting entirely. Pi's `truncateToWidth()` and `visibleWidth()` are used so ANSI styling and terminal width are handled correctly. The implementation does not start a second terminal renderer.

## Architecture

```text
pi-lfooter.ts
  Pi integration only:
  lifecycle events, setFooter(), theme, TUI redraws, model and git data

pi-lfooter/metrics.ts
  pure functionality:
  usage normalization, turn/session aggregation, cache formulas,
  token formatting, percentage formatting, context gauge

tests/pi-lfooter.test.ts
  Node built-in test runner coverage for the pure functionality
```

The extension is intentionally read-only. It does not modify prompts, provider payloads, session entries, or cache behavior.

## Loading

The extension can be loaded from Pi's normal user extension directory:

```text
~/.pi/agent/extensions/pi-lfooter.ts
```

For a direct local test:

```bash
pi --extension ./home/.pi/agent/extensions/pi-lfooter.ts
```

## Tests

Run the standalone tests from the repository root:

```bash
node --experimental-strip-types --test tests/pi-lfooter.test.ts
```

The tests cover:

- all three cache fields and the hit-rate formula
- total token calculation
- optional reasoning and one-hour cache-write fields
- session aggregation across Pi usage entry types
- ignoring aborted and failed assistant responses
- token, percentage, and gauge formatting
