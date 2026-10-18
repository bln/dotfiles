/**
 * Pi LFooter integration for Pi.
 *
 * Usage accounting lives in ./pi-lfooter/metrics.ts so this file only
 * connects the accounting to Pi lifecycle events and the TUI footer API.
 */

import { basename } from "node:path";
import type { ExtensionAPI, ExtensionContext, Theme, ThemeColor } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth, type TUI } from "@earendil-works/pi-tui";
import {
	countAssistantTurns,
	formatPercent,
	formatTokens,
	getCompactionStats,
	getLatestAssistantUsage,
	getSessionUsageTotals,
	getUsageStats,
	renderGauge,
	type CompactionStats,
	type MessageLike,
	type SessionEntryLike,
	type UsageLike,
	type UsageStats,
} from "./pi-lfooter/metrics.ts";

const ICONS = {
	model: "󰚩",
	thinking: "󰈈",
	branch: "󰘬",
} as const;

interface TurnSnapshot {
	stats: UsageStats;
	isInitial: boolean;
}

interface FooterMessage extends MessageLike {
	usage?: UsageLike;
}

function asEntries(ctx: ExtensionContext): readonly SessionEntryLike[] {
	return ctx.sessionManager.getBranch() as unknown as readonly SessionEntryLike[];
}

function asSessionEntries(ctx: ExtensionContext): readonly SessionEntryLike[] {
	return ctx.sessionManager.getEntries() as unknown as readonly SessionEntryLike[];
}

function formatCwd(cwd: string): string {
	const home = process.env.HOME;
	if (home && cwd === home) return "~";
	if (home && cwd.startsWith(`${home}/`)) return `~${cwd.slice(home.length)}`;
	return cwd;
}

function formatLocation(cwd: string, branch: string | null): string {
	const formattedCwd = formatCwd(cwd);
	const shortCwd = formattedCwd.length > 24 ? basename(cwd) || formattedCwd : formattedCwd;
	const location = `${shortCwd}${branch ? ` (${branch})` : ""}`;
	return truncateToWidth(location, 48, "…");
}

type FooterMode = "compact" | "full";

const MODE_FLAG = "lfooter-mode";
const LABEL_WIDTH = 9;

function normalizeMode(value: unknown): FooterMode {
	return value === "compact" ? "compact" : "full";
}

function separator(theme: Theme): string {
	return theme.fg("dim", "  •  ");
}

function metricSeparator(theme: Theme): string {
	return theme.fg("dim", "  |  ");
}

function renderMetric(theme: Theme, label: string, value: string, color: ThemeColor): string {
	return `${theme.fg("muted", label)} ${theme.fg(color, value)}`;
}

function padVisible(text: string, width: number): string {
	return `${text}${" ".repeat(Math.max(0, width - visibleWidth(text)))}`;
}

function renderRowLabel(
	theme: Theme,
	label: "TURN" | "SESSION",
): string {
	const text = ` ${label}`.padEnd(LABEL_WIDTH, " ");
	return label === "TURN"
		? theme.style(text, { fg: "text", bg: "selectedBg", bold: true })
		: theme.style(text, { fg: "customMessageText", bg: "customMessageBg", bold: true });
}

function cacheReadColor(stats: UsageStats, isInitial: boolean): ThemeColor {
	if (stats.cacheRead > 0) return "success";
	return isInitial ? "dim" : "error";
}

function hitColor(stats: UsageStats, isInitial: boolean): ThemeColor {
	if (stats.cacheHitPercent === null) return "dim";
	if (stats.cacheHitPercent >= 70) return "success";
	if (stats.cacheHitPercent > 0 || isInitial) return "warning";
	return "error";
}

function coreMetricParts(theme: Theme, stats: UsageStats, isInitial: boolean): string[] {
	return [
		renderMetric(theme, "in", formatTokens(stats.input), "text"),
		renderMetric(theme, "cr", formatTokens(stats.cacheRead), cacheReadColor(stats, isInitial)),
		renderMetric(theme, "cw", formatTokens(stats.cacheWrite), "warning"),
		renderMetric(theme, "out", formatTokens(stats.output), "accent"),
		renderMetric(theme, "all", formatTokens(stats.total), "muted"),
		renderMetric(theme, "hit", formatPercent(stats.cacheHitPercent), hitColor(stats, isInitial)),
	];
}

type OptionalMetricKey = "reason" | "cw1h";

function optionalMetricParts(
	theme: Theme,
	stats: UsageStats,
	keys: readonly OptionalMetricKey[],
): string[] {
	return keys.map((key) => {
		if (key === "reason") {
			return stats.hasReasoning
				? renderMetric(theme, "reason", formatTokens(stats.reasoning), "thinkingHigh")
				: renderMetric(theme, "reason", "—", "dim");
		}
		return stats.hasCacheWrite1h
			? renderMetric(theme, "cw1h", formatTokens(stats.cacheWrite1h), "warning")
			: renderMetric(theme, "cw1h", "—", "dim");
	});
}

interface UsageRow {
	label: "TURN" | "SESSION";
	stats: UsageStats | null;
	isInitial: boolean;
}

function renderUsageRows(theme: Theme, rows: readonly UsageRow[]): string[] {
	const coreRows = rows.map((row) => (row.stats ? coreMetricParts(theme, row.stats, row.isInitial) : null));
	const widths = Array.from({ length: 6 }, (_, index) =>
		Math.max(...coreRows.map((parts) => (parts ? visibleWidth(parts[index] ?? "") : 0))),
	);
	const optionalKeys: OptionalMetricKey[] = [];
	if (rows.some((row) => row.stats?.hasReasoning === true)) optionalKeys.push("reason");
	if (rows.some((row) => row.stats?.hasCacheWrite1h === true)) optionalKeys.push("cw1h");
	const optionalRows = rows.map((row) =>
		row.stats ? optionalMetricParts(theme, row.stats, optionalKeys) : null,
	);
	const optionalWidths = optionalKeys.map((_, index) =>
		Math.max(...optionalRows.map((parts) => (parts ? visibleWidth(parts[index] ?? "") : 0))),
	);

	return rows.map((row, rowIndex) => {
		const label = renderRowLabel(theme, row.label);
		const parts = coreRows[rowIndex];
		if (!parts) return `${label} ${theme.fg("dim", "no completed turn")}`;

		const core = parts
			.map((part, index) => padVisible(part, widths[index] ?? visibleWidth(part)))
			.join(metricSeparator(theme));
		const optional = optionalRows[rowIndex];
		const optionalText = optional
			?.map((part, index) => padVisible(part, optionalWidths[index] ?? visibleWidth(part)))
			.join(metricSeparator(theme));
		return `${label} ${core}${optionalText ? `${metricSeparator(theme)}${optionalText}` : ""}`;
	});
}

function renderContext(
	ctx: ExtensionContext,
	theme: Theme,
): string {
	const usage = ctx.getContextUsage();
	const contextWindow = usage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
	const tokens = usage?.tokens ?? null;
	const percent = usage?.percent ?? null;
	const windowLabel = contextWindow > 0 ? formatTokens(contextWindow) : "?";
	const tokenLabel = tokens === null ? `?/${windowLabel}` : `${formatTokens(tokens)}/${windowLabel}`;
	const percentageLabel = formatPercent(percent);
	const color: ThemeColor = percent === null ? "dim" : percent >= 90 ? "error" : percent >= 70 ? "warning" : "success";
	const gauge = renderGauge(percent);

	return theme.fg("muted", `CTX`) +
		` ${theme.fg(color, gauge)} ${theme.fg(color, tokenLabel)} ${theme.fg(color, `(${percentageLabel})`)}`;
}

function fitFirstRow(left: string, right: string, width: number): string {
	if (width <= 0) return "";
	const gap = width - visibleWidth(left) - visibleWidth(right);
	if (gap >= 2) return `${left}${" ".repeat(gap)}${right}`;

	const rightWidth = Math.min(visibleWidth(right), Math.max(0, width - 1));
	const fittedRight = truncateToWidth(right, rightWidth, "");
	const leftWidth = Math.max(0, width - visibleWidth(fittedRight) - 1);
	if (leftWidth <= 0) return truncateToWidth(fittedRight, width, "");
	return `${truncateToWidth(left, leftWidth, "…")} ${fittedRight}`;
}

function renderFirstRow(
	ctx: ExtensionContext,
	theme: Theme,
	branch: string | null,
	width: number,
): string {
	const model = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "no-model";
	const thinking = ctx.thinkingLevel ?? "off";
	const location = formatLocation(ctx.cwd, branch);
	const left = [
		theme.fg("accent", `${ICONS.model} ${model}`),
		theme.fg("dim", `${ICONS.thinking} ${thinking}`),
		theme.fg("dim", `${ICONS.branch} ${location}`),
	].join(separator(theme));
	const right = renderContext(ctx, theme);
	return fitFirstRow(left, right, width);
}

function renderCompaction(theme: Theme, stats: CompactionStats): string {
	const parts = [
		theme.fg("dim", "CMP"),
		theme.fg("muted", formatTokens(stats.count)),
	];
	if (stats.latestTokensBefore !== null) {
		parts.push(theme.fg("muted", `pre ${formatTokens(stats.latestTokensBefore)}`));
	}
	if (stats.latestUsageTotal !== null) {
		parts.push(theme.fg("muted", `use ${formatTokens(stats.latestUsageTotal)}`));
	}
	return parts.join(theme.fg("dim", "  ·  "));
}

function currentTurnSnapshot(ctx: ExtensionContext): TurnSnapshot | null {
	const entries = asEntries(ctx);
	const usage = getLatestAssistantUsage(entries);
	if (!usage) return null;
	return {
		stats: getUsageStats(usage),
		isInitial: countAssistantTurns(entries) <= 1,
	};
}

export default function (pi: ExtensionAPI) {
	pi.registerFlag(MODE_FLAG, {
		type: "string",
		default: "full",
		description: "Pi LFooter mode: full or compact",
	});

	let footerMode = normalizeMode(pi.getFlag(MODE_FLAG));
	let activeSessionId: string | undefined;
	let activeTui: TUI | undefined;
	let latestTurn: TurnSnapshot | null = null;
	let completedTurnCount = 0;

	const requestRender = () => activeTui?.requestRender();
	const isActiveSession = (ctx: ExtensionContext) =>
		activeSessionId !== undefined && ctx.sessionManager.getSessionId() === activeSessionId;

	const syncBranchState = (ctx: ExtensionContext) => {
		if (footerMode !== "full") {
			latestTurn = null;
			completedTurnCount = 0;
			return;
		}

		const entries = asEntries(ctx);
		completedTurnCount = countAssistantTurns(entries);
		latestTurn = currentTurnSnapshot(ctx);
	};

	pi.registerCommand("lfooter-mode", {
		description: "Switch Pi LFooter between full and compact modes",
		handler: async (args, ctx) => {
			const requested = args.trim().toLowerCase();
			if (requested !== "" && requested !== "compact" && requested !== "full") {
				if (ctx.hasUI) ctx.ui.notify("Usage: /lfooter-mode [full|compact]", "error");
				return;
			}

			footerMode = requested === "" ? (footerMode === "full" ? "compact" : "full") : requested;
			syncBranchState(ctx);
			requestRender();
			if (ctx.hasUI) ctx.ui.notify(`Pi LFooter: ${footerMode}`, "info");
		},
	});

	pi.on("session_start", (_event, ctx) => {
		activeSessionId = ctx.sessionManager.getSessionId();
		activeTui = undefined;
		latestTurn = null;
		completedTurnCount = 0;
		syncBranchState(ctx);

		if (ctx.mode !== "tui") return;

		ctx.ui.setFooter((tui, theme, footerData) => {
			activeTui = tui;
			const unsubscribeBranch = footerData.onBranchChange(() => {
				if (isActiveSession(ctx)) syncBranchState(ctx);
				tui.requestRender();
			});

			return {
				dispose() {
					unsubscribeBranch();
					if (activeTui === tui) activeTui = undefined;
				},
				invalidate() {},
				render(width: number): string[] {
					const branch = footerData.getGitBranch();
					const first = renderFirstRow(ctx, theme, branch, width);
					if (footerMode === "compact") return [first];

					const sessionEntries = asSessionEntries(ctx);
					const sessionUsage = getSessionUsageTotals(sessionEntries);
					const compaction = getCompactionStats(sessionEntries);
					const rows = renderUsageRows(theme, [
						{
							label: "TURN",
							stats: latestTurn?.stats ?? null,
							isInitial: latestTurn?.isInitial ?? completedTurnCount <= 1,
						},
						{
							label: "SESSION",
							stats: getUsageStats(sessionUsage),
							isInitial: completedTurnCount <= 1,
						},
					]);

					const sessionRow = compaction.count > 0
						? fitFirstRow(rows[1]!, renderCompaction(theme, compaction), width)
						: rows[1]!;
					return [
						first,
						truncateToWidth(rows[0]!, width, ""),
						truncateToWidth(sessionRow, width, ""),
					];
				},
			};
		});
	});

	pi.on("turn_end", (event, ctx) => {
		if (!isActiveSession(ctx)) return;
		if (footerMode === "compact") {
			requestRender();
			return;
		}

		const message = event.message as unknown as FooterMessage;
		if (message.role !== "assistant" || !message.usage || message.stopReason === "aborted" || message.stopReason === "error") {
			requestRender();
			return;
		}

		latestTurn = {
			stats: getUsageStats(message.usage),
			isInitial: completedTurnCount === 0,
		};
		completedTurnCount += 1;
		requestRender();
	});

	pi.on("session_tree", (_event, ctx) => {
		if (!isActiveSession(ctx)) return;
		if (footerMode === "full") syncBranchState(ctx);
		requestRender();
	});

	pi.on("session_compact", (_event, ctx) => {
		if (isActiveSession(ctx)) requestRender();
	});

	pi.on("model_select", (_event, ctx) => {
		if (isActiveSession(ctx)) requestRender();
	});

	pi.on("thinking_level_select", (_event, ctx) => {
		if (isActiveSession(ctx)) requestRender();
	});

	pi.on("session_shutdown", (_event, ctx) => {
		if (!isActiveSession(ctx)) return;
		activeSessionId = undefined;
		activeTui = undefined;
		latestTurn = null;
		completedTurnCount = 0;
	});
}
