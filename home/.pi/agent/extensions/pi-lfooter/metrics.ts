/**
 * Pure usage accounting for the Pi LFooter extension.
 *
 * This module deliberately has no Pi or TUI imports. It can be tested with
 * Node's built-in test runner and keeps the integration file focused on Pi's
 * lifecycle and rendering APIs.
 */

export interface UsageLike {
	input?: number;
	output?: number;
	cacheRead?: number;
	cacheWrite?: number;
	cacheWrite1h?: number;
	reasoning?: number;
	totalTokens?: number;
}

export interface MessageLike {
	role?: string;
	stopReason?: string;
	usage?: UsageLike;
}

export interface SessionEntryLike {
	type?: string;
	message?: MessageLike;
	usage?: UsageLike;
	tokensBefore?: number;
}

export interface CompactionStats {
	count: number;
	latestTokensBefore: number | null;
	latestUsageTotal: number | null;
}

export interface UsageStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	promptTokens: number;
	total: number;
	cacheHitPercent: number | null;
	reasoning: number;
	cacheWrite1h: number;
	hasReasoning: boolean;
	hasCacheWrite1h: boolean;
}

export interface UsageTotals {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	total: number;
	reasoning: number;
	cacheWrite1h: number;
	hasReasoning: boolean;
	hasCacheWrite1h: boolean;
}

function tokenValue(value: unknown): number {
	return typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : 0;
}

function optionalTokenValue(value: unknown): number | undefined {
	return typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : undefined;
}

/** Convert one provider usage object into the values shown by the footer. */
export function getUsageStats(usage: UsageLike): UsageStats {
	const input = tokenValue(usage.input);
	const output = tokenValue(usage.output);
	const cacheRead = tokenValue(usage.cacheRead);
	const cacheWrite = tokenValue(usage.cacheWrite);
	const reasoning = optionalTokenValue(usage.reasoning);
	const cacheWrite1h = optionalTokenValue(usage.cacheWrite1h);
	const promptTokens = input + cacheRead + cacheWrite;
	const total = promptTokens + output;

	return {
		input,
		output,
		cacheRead,
		cacheWrite,
		promptTokens,
		total,
		cacheHitPercent: promptTokens > 0 ? (cacheRead / promptTokens) * 100 : null,
		reasoning: reasoning ?? 0,
		cacheWrite1h: cacheWrite1h ?? 0,
		hasReasoning: reasoning !== undefined,
		hasCacheWrite1h: cacheWrite1h !== undefined,
	};
}

export function createUsageTotals(): UsageTotals {
	return {
		input: 0,
		output: 0,
		cacheRead: 0,
		cacheWrite: 0,
		total: 0,
		reasoning: 0,
		cacheWrite1h: 0,
		hasReasoning: false,
		hasCacheWrite1h: false,
	};
}

/** Add one provider usage object to cumulative totals. */
export function addUsageToTotals(totals: UsageTotals, usage: UsageLike): void {
	const stats = getUsageStats(usage);
	totals.input += stats.input;
	totals.output += stats.output;
	totals.cacheRead += stats.cacheRead;
	totals.cacheWrite += stats.cacheWrite;
	totals.total += stats.total;

	if (stats.hasReasoning) {
		totals.reasoning += stats.reasoning;
		totals.hasReasoning = true;
	}
	if (stats.hasCacheWrite1h) {
		totals.cacheWrite1h += stats.cacheWrite1h;
		totals.hasCacheWrite1h = true;
	}
}

function isCountableAssistantMessage(message: MessageLike | undefined): boolean {
	return Boolean(
		message?.role === "assistant" &&
		message.usage &&
		message.stopReason !== "aborted" &&
		message.stopReason !== "error",
	);
}

/** Return the usage for the latest completed assistant turn in a branch. */
export function getLatestAssistantUsage(entries: readonly SessionEntryLike[]): UsageLike | undefined {
	for (let index = entries.length - 1; index >= 0; index -= 1) {
		const message = entries[index]?.message;
		if (isCountableAssistantMessage(message)) return message.usage;
	}
	return undefined;
}

/** Count completed assistant turns in a branch. */
export function countAssistantTurns(entries: readonly SessionEntryLike[]): number {
	return entries.reduce(
		(count, entry) => count + (isCountableAssistantMessage(entry.message) ? 1 : 0),
		0,
	);
}

/**
 * Sum all provider usage persisted in a session.
 *
 * This follows Pi's built-in footer accounting: normal assistant messages,
 * usage entries, nested tool usage, compaction, and branch-summary usage are
 * all included in the session total.
 */
export function getSessionUsageTotals(entries: readonly SessionEntryLike[]): UsageTotals {
	const totals = createUsageTotals();

	for (const entry of entries) {
		let usage: UsageLike | undefined;

		if (entry.type === "message") {
			if (entry.message?.role === "assistant" && entry.message.usage) {
				// Failed or aborted requests can still have billable provider usage.
				// Keep them in session totals, even though they are not eligible as
				// the latest completed turn above.
				usage = entry.message.usage;
			} else if (entry.message?.role === "toolResult") {
				usage = entry.message.usage;
			}
		} else if (
			(entry.type === "usage" || entry.type === "compaction" || entry.type === "branch_summary") &&
			entry.usage
		) {
			usage = entry.usage;
		}

		if (usage) addUsageToTotals(totals, usage);
	}

	return totals;
}

/** Return concise details for the latest persisted compaction in a session. */
export function getCompactionStats(entries: readonly SessionEntryLike[]): CompactionStats {
	let count = 0;
	let latestTokensBefore: number | null = null;
	let latestUsageTotal: number | null = null;

	for (const entry of entries) {
		if (entry.type !== "compaction") continue;
		count += 1;
		latestTokensBefore = optionalTokenValue(entry.tokensBefore) ?? null;
		latestUsageTotal = entry.usage ? getUsageStats(entry.usage).total : null;
	}

	return { count, latestTokensBefore, latestUsageTotal };
}

export function formatTokens(value: number): string {
	const count = Math.max(0, Math.round(Number.isFinite(value) ? value : 0));
	if (count < 1_000) return `${count}`;
	if (count < 10_000) return `${(count / 1_000).toFixed(1)}k`;
	if (count < 1_000_000) return `${Math.round(count / 1_000)}k`;
	if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
	return `${Math.round(count / 1_000_000)}M`;
}

export function formatPercent(value: number | null, decimals = 1): string {
	if (value === null || !Number.isFinite(value)) return "?";
	return `${value.toFixed(decimals)}%`;
}

/** Render a compact context gauge using terminal-safe block characters. */
export function renderGauge(percent: number | null, width = 10): string {
	if (percent === null || !Number.isFinite(percent)) return "?".repeat(width);
	const clamped = Math.max(0, Math.min(100, percent));
	const filled = Math.round((clamped / 100) * width);
	return "█".repeat(filled) + "░".repeat(width - filled);
}
