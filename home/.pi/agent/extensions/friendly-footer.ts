/**
 * Friendly footer
 *
 * Replaces pi's default footer with a warmer take on the *same* information -
 * model, thinking level, context-window usage, token count, and git branch -
 * phrased gently instead of as a dense stat strip. Cost is omitted: our proxy
 * always reports $0.00, so it carries no signal. It does not add a second
 * status segment; it swaps the footer via ctx.ui.setFooter().
 *
 * Read-only: no tool interception, no session mutation. Managed in ~/dotfiles
 * (home/.pi/agent/extensions/) and symlinked to ~/.pi/agent/extensions/ via the
 * mise [dotfiles] table, so it loads globally across all projects.
 */

import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

function fmtTokens(n: number): string {
	if (n < 1000) return `${n}`;
	if (n < 1_000_000) return `${(n / 1000).toFixed(1)}k`;
	return `${(n / 1_000_000).toFixed(1)}M`;
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		ctx.ui.setFooter((tui, theme, footerData) => {
			const unsub = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose: unsub,
				invalidate() {},
				render(width: number): string[] {
					// Sum this session's token counts (same source the default footer uses).
					let input = 0;
					let output = 0;
					for (const e of ctx.sessionManager.getBranch()) {
						if (e.type === "message" && e.message.role === "assistant") {
							const m = e.message as AssistantMessage;
							input += m.usage.input;
							output += m.usage.output;
						}
					}

					// Model + thinking level, in plain words.
					const model = ctx.model?.name ?? ctx.model?.id ?? "no model";
					const thinking = ctx.thinkingLevel && ctx.thinkingLevel !== "off"
						? `thinking ${ctx.thinkingLevel}`
						: "thinking off";

					// How full the context window is - warn as it fills.
					const usage = ctx.getContextUsage();
					const pct = usage?.percent ?? null;
					const ctxColor = pct === null ? "dim" : pct >= 85 ? "warning" : "dim";
					const ctxStr = pct === null ? "" : `${Math.round(pct)}% full`;

					// Where we are.
					const branch = footerData.getGitBranch();
					const where = branch ? `on ${branch}` : "no git";

					// Left: a calm, readable summary. Right: the token count, quietly.
					const leftParts = [
						theme.fg("accent", model),
						theme.fg("dim", thinking),
						theme.fg("dim", where),
					];
					if (ctxStr) leftParts.push(theme.fg(ctxColor, ctxStr));
					const left = leftParts.join(theme.fg("dim", "  ·  "));

					const right = theme.fg("dim", `${fmtTokens(input)} in · ${fmtTokens(output)} out`);

					const gap = Math.max(2, width - visibleWidth(left) - visibleWidth(right));
					return [truncateToWidth(left + " ".repeat(gap) + right, width)];
				},
			};
		});
	});
}
