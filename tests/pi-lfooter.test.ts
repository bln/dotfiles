import assert from "node:assert/strict";
import test from "node:test";
import {
	countAssistantTurns,
	formatPercent,
	formatTokens,
	getCompactionStats,
	getLatestAssistantUsage,
	getSessionUsageTotals,
	getUsageStats,
	renderGauge,
	type SessionEntryLike,
} from "../home/.pi/agent/extensions/pi-lfooter/metrics.ts";

function usage(values: Record<string, number> = {}) {
	return {
		input: 0,
		output: 0,
		cacheRead: 0,
		cacheWrite: 0,
		...values,
	};
}

test("calculates the per-turn cache metrics from all three cache fields", () => {
	const stats = getUsageStats(
		usage({ input: 100, cacheRead: 900, cacheWrite: 100, output: 50 }),
	);

	assert.equal(stats.promptTokens, 1_100);
	assert.equal(stats.total, 1_150);
	assert.equal(stats.cacheHitPercent, (900 / 1_100) * 100);
	assert.equal(stats.hasReasoning, false);
	assert.equal(stats.hasCacheWrite1h, false);
});

test("keeps optional provider token breakdowns without double-counting them", () => {
	const stats = getUsageStats({
		input: 100,
		output: 50,
		cacheRead: 900,
		cacheWrite: 100,
		reasoning: 20,
		cacheWrite1h: 100,
	});

	assert.equal(stats.total, 1_150);
	assert.equal(stats.reasoning, 20);
	assert.equal(stats.cacheWrite1h, 100);
	assert.equal(stats.hasReasoning, true);
	assert.equal(stats.hasCacheWrite1h, true);
});

test("returns a null hit rate when there are no prompt tokens", () => {
	const stats = getUsageStats(usage({ output: 25 }));
	assert.equal(stats.promptTokens, 0);
	assert.equal(stats.cacheHitPercent, null);
});

test("aggregates all persisted provider usage categories for the session", () => {
	const entries: SessionEntryLike[] = [
		{
			type: "message",
			message: {
				role: "assistant",
				usage: {
					input: 10,
					output: 2,
					cacheRead: 30,
					cacheWrite: 4,
					reasoning: 1,
					cacheWrite1h: 2,
				},
			},
		},
		{
			type: "message",
			message: {
				role: "assistant",
				stopReason: "error",
				usage: usage({ input: 7, output: 1 }),
			},
		},
		{
			type: "usage",
			usage: usage({ input: 5, output: 1, cacheRead: 40, cacheWrite: 0 }),
		},
		{
			type: "message",
			message: {
				role: "toolResult",
				usage: usage({ input: 1, output: 3, cacheRead: 0, cacheWrite: 2 }),
			},
		},
		{
			type: "compaction",
			usage: usage({ input: 2, output: 4, cacheRead: 10, cacheWrite: 1 }),
		},
		{
			type: "branch_summary",
			usage: usage({ input: 3, output: 5, cacheRead: 20, cacheWrite: 2 }),
		},
	];

	const totals = getSessionUsageTotals(entries);
	assert.deepEqual(totals, {
		input: 28,
		output: 16,
		cacheRead: 100,
		cacheWrite: 9,
		total: 153,
		reasoning: 1,
		cacheWrite1h: 2,
		hasReasoning: true,
		hasCacheWrite1h: true,
	});

	const sessionStats = getUsageStats(totals);
	assert.equal(sessionStats.cacheHitPercent, (100 / (28 + 100 + 9)) * 100);
});

test("ignores failed assistant responses when finding the latest turn", () => {
	const entries: SessionEntryLike[] = [
		{ type: "message", message: { role: "assistant", usage: usage({ input: 10 }) } },
		{
			type: "message",
			message: { role: "assistant", stopReason: "error", usage: usage({ input: 999 }) },
		},
		{
			type: "message",
			message: { role: "assistant", stopReason: "aborted", usage: usage({ input: 999 }) },
		},
	];

	assert.deepEqual(getLatestAssistantUsage(entries), usage({ input: 10 }));
	assert.equal(countAssistantTurns(entries), 1);
});

test("summarizes the latest compaction details", () => {
	const stats = getCompactionStats([
		{ type: "compaction", tokensBefore: 900_000, usage: usage({ output: 3_000 }) },
		{ type: "compaction", tokensBefore: 1_200_000, usage: usage({ input: 100, output: 8_000 }) },
	]);

	assert.deepEqual(stats, {
		count: 2,
		latestTokensBefore: 1_200_000,
		latestUsageTotal: 8_100,
	});
});

test("formats token counts and context gauges compactly", () => {
	assert.equal(formatTokens(0), "0");
	assert.equal(formatTokens(1_234), "1.2k");
	assert.equal(formatTokens(12_345), "12k");
	assert.equal(formatTokens(1_234_567), "1.2M");
	assert.equal(formatPercent(94.567), "94.6%");
	assert.equal(formatPercent(null), "?");
	assert.equal(renderGauge(0), "░░░░░░░░░░");
	assert.equal(renderGauge(50), "█████░░░░░");
	assert.equal(renderGauge(100), "██████████");
	assert.equal(renderGauge(null), "??????????");
});
