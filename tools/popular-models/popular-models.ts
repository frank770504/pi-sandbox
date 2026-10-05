/**
 * Display the ten most-used OpenRouter models for programming on new sessions.
 * This is a read-only widget: it never changes the active model or opens a
 * selection dialog.
 */

import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { getAgentDir } from "@earendil-works/pi-coding-agent";

const RANKING_URL = "https://openrouter.ai/api/frontend/v1/rankings/tools";
const FETCH_TIMEOUT_MS = 8_000;
const CACHE_TTL_MS = 12 * 60 * 60 * 1_000;
const MODEL_COUNT = 10;
const WIDGET_KEY = "popular-models";
const OTHERS_BUCKET = "Others";

interface PopularModel {
	id: string;
	tokens: number;
}

interface CacheSnapshot {
	fetchedAt: number;
	models: PopularModel[];
}

function record(value: unknown): Record<string, unknown> {
	return value !== null && typeof value === "object" ? value as Record<string, unknown> : {};
}

function stripVersion(id: string): string {
	return id.replace(/-\d{8}$/, "");
}

function parseUsage(payload: unknown): Array<{ id: string; tokens: number }> {
	const buckets = record(payload).data;
	if (!Array.isArray(buckets)) return [];

	let latest: Record<string, unknown> | undefined;
	for (const value of buckets) {
		const bucket = record(value);
		if (!latest || String(bucket.x ?? "") > String(latest.x ?? "")) latest = bucket;
	}

	const ys = record(latest?.ys);
	return Object.entries(ys)
		.filter(([id]) => id !== OTHERS_BUCKET)
		.map(([id, value]) => ({ id, tokens: Number(value) }))
		.filter((entry) => entry.id.length > 0 && Number.isFinite(entry.tokens))
		.sort((a, b) => b.tokens - a.tokens);
}

async function fetchJson(url: string): Promise<unknown> {
	const response = await fetch(url, { signal: AbortSignal.timeout(FETCH_TIMEOUT_MS) });
	if (!response.ok) throw new Error(`HTTP ${response.status} from ${url}`);
	return response.json();
}

async function fetchPopularModels(): Promise<PopularModel[]> {
	const usage = parseUsage(await fetchJson(RANKING_URL));
	if (usage.length === 0) throw new Error("OpenRouter returned no weekly tool-call rankings");

	const models: PopularModel[] = [];
	const seen = new Set<string>();
	for (const entry of usage) {
		const id = stripVersion(entry.id);
		if (seen.has(id)) continue;
		seen.add(id);
		models.push({ id, tokens: entry.tokens });
		if (models.length === MODEL_COUNT) break;
	}
	return models;
}

function getCachePath(): string {
	return join(getAgentDir(), "popular-models-cache.json");
}

function readCache(): CacheSnapshot | null {
	try {
		const raw = JSON.parse(readFileSync(getCachePath(), "utf8")) as CacheSnapshot;
		if (!Number.isFinite(raw?.fetchedAt) || !Array.isArray(raw.models)) return null;
		const models = raw.models.filter((model) =>
			typeof model?.id === "string" && model.id.length > 0 && Number.isFinite(model.tokens),
		);
		return models.length > 0 ? { fetchedAt: raw.fetchedAt, models } : null;
	} catch {
		return null;
	}
}

function writeCache(snapshot: CacheSnapshot): void {
	try {
		writeFileSync(getCachePath(), JSON.stringify(snapshot), "utf8");
	} catch {
		// Caching is best-effort; a live ranking is still useful without it.
	}
}

async function loadPopularModels(): Promise<{ models: PopularModel[]; cached: boolean }> {
	const cached = readCache();
	if (cached && Date.now() - cached.fetchedAt < CACHE_TTL_MS) {
		return { models: cached.models.slice(0, MODEL_COUNT), cached: true };
	}

	try {
		const models = await fetchPopularModels();
		writeCache({ fetchedAt: Date.now(), models });
		return { models, cached: false };
	} catch (error) {
		if (cached) return { models: cached.models.slice(0, MODEL_COUNT), cached: true };
		throw error;
	}
}

function formatTokens(tokens: number): string {
	if (tokens >= 1_000_000_000_000) return `${(tokens / 1_000_000_000_000).toFixed(1)}T`;
	if (tokens >= 1_000_000_000) return `${(tokens / 1_000_000_000).toFixed(1)}B`;
	if (tokens >= 1_000_000) return `${(tokens / 1_000_000).toFixed(1)}M`;
	if (tokens >= 1_000) return `${(tokens / 1_000).toFixed(1)}k`;
	return String(Math.round(tokens));
}

async function updateWidget(ctx: ExtensionContext, isCurrent: () => boolean): Promise<void> {
	try {
		const result = await loadPopularModels();
		if (!isCurrent()) return;
		const cachedLabel = result.cached ? " (cached)" : "";
		const lines = [
			`Top ${MODEL_COUNT} popular models · OpenRouter weekly tool-call usage${cachedLabel}`,
			...result.models.map((model, index) =>
				`${String(index + 1).padStart(2, " ")}. ${model.id}  ·  ${formatTokens(model.tokens)} tokens`,
			),
		];
		ctx.ui.setWidget(WIDGET_KEY, lines, { placement: "aboveEditor" });
	} catch (error) {
		if (!isCurrent()) return;
		console.error(`popular-models: failed to load OpenRouter ranking: ${error}`);
		ctx.ui.notify("Popular models unavailable (no OpenRouter ranking or cached results).", "warning");
	}
}

export default function popularModels(pi: ExtensionAPI) {
	let requestId = 0;

	pi.on("session_start", (event, ctx) => {
		const currentRequest = ++requestId;
		if (!ctx.hasUI) return;

		// Clear stale content when a session is resumed, forked, or reloaded.
		ctx.ui.setWidget(WIDGET_KEY, undefined);
		if (event.reason !== "startup" && event.reason !== "new") return;

		void updateWidget(ctx, () => currentRequest === requestId);
	});
}
