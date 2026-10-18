# Changelog

All notable changes to the repository-owned Pi LFooter extension are documented here.

## [Unreleased]

### Added

- Per-turn cache telemetry for uncached input, cache reads, cache writes, output, total tokens, and effective cache hit rate.
- Per-session weighted token and cache totals using Pi's persisted usage categories.
- Current context-window usage with a compact gauge and unknown-state handling after compaction.
- Optional reasoning-token and one-hour cache-write reporting when a provider supplies those fields.
- Nerd Font symbols for model, thinking level, and git branch metadata.
- Responsive rendering that preserves cache diagnostics on narrow terminals.
- Pure usage-accounting functionality in `pi-lfooter/metrics.ts`.
- Node built-in tests in `tests/pi-lfooter.test.ts`.
- Practical warning thresholds and guidance for recognizing when a fresh-session handoff is preferable to repeated compaction.
- Concise right-aligned compaction count, latest pre-compaction context size, and latest compaction usage on the `SESSION` row.
- Full and compact display modes with CLI and runtime controls.
- Width-aligned core metric columns and contrasting theme-aware `TURN` and `SESSION` label backgrounds.
- Repository-basename location formatting to prevent long paths from crowding the context indicator.

### Changed

- `pi-lfooter.ts` is now primarily Pi lifecycle and TUI integration.
- Full mode remains the default; compact mode renders and computes only the first context row.
- Optional `reason` and `cw1h` columns are aligned across both usage rows; unavailable provider-specific fields render as `—`.
- `TURN` and `SESSION` labels use separate theme-provided background panels for contrast.
- Long working-directory paths are reduced to a repository basename before rendering.
- Session totals include assistant usage, usage entries, nested tool usage, compaction usage, and branch-summary usage, matching Pi's built-in footer accounting.
- Zero cache-read values remain visible instead of being omitted, making cold starts and possible intermediate cache breaks observable.

### Notes

- Cost is intentionally not displayed because the configured proxy currently reports `$0.00` and the footer's purpose is token and cache monitoring.
