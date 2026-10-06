/**
 * Render the ten most-used OpenRouter models as a TUI transcript table on new
 * sessions. The custom session entry is excluded from LLM context.
 */

import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { getAgentDir, getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import { Box, Markdown, Text } from "@earendil-works/pi-tui";

const RANKING_URL = "https://openrouter.ai/api/frontend/v1/rankings/tools";
const MODEL_CATALOG_URL = "https://openrouter.ai/api/v1/models";
const FETCH_TIMEOUT_MS = 8_000;
const CACHE_TTL_MS = 12 * 60 * 60 * 1_000;
const MODEL_COUNT = 10;
const ENTRY_TYPE = "popular-models-table";
const OTHERS_BUCKET = "Others";

interface PopularModel {
	id: string;
	tokens: number;
}

interface CacheSnapshot {
	fetchedAt: number;
	models: PopularModel[];
}

interface ModelMetadata {
	name?: string;
	promptPricePerToken?: number;
	completionPricePerToken?: number;
	contextLength?: number;
}

interface MetadataCacheSnapshot {
	fetchedAt: number;
	models: Record<string, ModelMetadata>;
}

interface PopularModelsEntryData {
	rankingCached: boolean;
	models: Array<PopularModel & { metadata?: ModelMetadata }>;
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

function getMetadataCachePath(): string {
	return join(getAgentDir(), "popular-models-metadata-cache.json");
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

function nonNegativeNumber(value: unknown): number | undefined {
	if (typeof value === "string" && value.trim().length === 0) return undefined;
	const number = typeof value === "number" || typeof value === "string" ? Number(value) : NaN;
	return Number.isFinite(number) && number >= 0 ? number : undefined;
}

function normalizeMetadata(value: unknown): ModelMetadata {
	const raw = record(value);
	const metadata: ModelMetadata = {};
	if (typeof raw.name === "string" && raw.name.trim()) metadata.name = raw.name.trim();

	const promptPricePerToken = nonNegativeNumber(raw.promptPricePerToken);
	if (promptPricePerToken !== undefined) metadata.promptPricePerToken = promptPricePerToken;
	const completionPricePerToken = nonNegativeNumber(raw.completionPricePerToken);
	if (completionPricePerToken !== undefined) metadata.completionPricePerToken = completionPricePerToken;
	const contextLength = nonNegativeNumber(raw.contextLength);
	if (contextLength !== undefined && contextLength > 0) metadata.contextLength = contextLength;
	return metadata;
}

function parseModelMetadata(payload: unknown): Record<string, ModelMetadata> {
	const data = record(payload).data;
	if (!Array.isArray(data)) throw new Error("OpenRouter model catalog returned no data array");

	const models: Record<string, ModelMetadata> = {};
	for (const value of data) {
		const model = record(value);
		if (typeof model.id !== "string" || model.id.length === 0) continue;
		const pricing = record(model.pricing);
		const metadata: ModelMetadata = {};
		if (typeof model.name === "string" && model.name.trim()) metadata.name = model.name.trim();
		const promptPricePerToken = nonNegativeNumber(pricing.prompt);
		if (promptPricePerToken !== undefined) metadata.promptPricePerToken = promptPricePerToken;
		const completionPricePerToken = nonNegativeNumber(pricing.completion);
		if (completionPricePerToken !== undefined) metadata.completionPricePerToken = completionPricePerToken;
		const contextLength = nonNegativeNumber(model.context_length);
		if (contextLength !== undefined && contextLength > 0) metadata.contextLength = contextLength;
		if (Object.keys(metadata).length === 0) continue;

		const baseId = stripVersion(model.id);
		if (model.id === baseId || !models[baseId]) models[baseId] = metadata;
	}
	if (Object.keys(models).length === 0) throw new Error("OpenRouter model catalog contained no usable metadata");
	return models;
}

function readMetadataCache(): MetadataCacheSnapshot | null {
	try {
		const raw = JSON.parse(readFileSync(getMetadataCachePath(), "utf8")) as MetadataCacheSnapshot;
		if (!Number.isFinite(raw?.fetchedAt) || raw.fetchedAt < 0) return null;
		const models: Record<string, ModelMetadata> = {};
		for (const [id, value] of Object.entries(record(raw.models))) {
			const metadata = normalizeMetadata(value);
			if (Object.keys(metadata).length > 0) models[id] = metadata;
		}
		return Object.keys(models).length > 0 ? { fetchedAt: raw.fetchedAt, models } : null;
	} catch {
		return null;
	}
}

function writeMetadataCache(snapshot: MetadataCacheSnapshot): void {
	try {
		writeFileSync(getMetadataCachePath(), JSON.stringify(snapshot), "utf8");
	} catch {
		// Metadata caching is best-effort; the conversation can still show rankings.
	}
}

async function loadModelMetadata(): Promise<Record<string, ModelMetadata>> {
	const cached = readMetadataCache();
	if (cached && Date.now() - cached.fetchedAt < CACHE_TTL_MS) return cached.models;

	try {
		const models = parseModelMetadata(await fetchJson(MODEL_CATALOG_URL));
		writeMetadataCache({ fetchedAt: Date.now(), models });
		return models;
	} catch (error) {
		console.error(`popular-models: failed to load OpenRouter model metadata: ${error}`);
		return cached?.models ?? {};
	}
}

function formatPricePerMillion(pricePerToken: number | undefined): string {
	if (pricePerToken === undefined) return "n/a";
	return new Intl.NumberFormat("en-US", {
		style: "currency",
		currency: "USD",
		maximumSignificantDigits: 3,
	}).format(pricePerToken * 1_000_000);
}

function formatTokens(tokens: number): string {
	if (tokens >= 1_000_000_000_000) return `${(tokens / 1_000_000_000_000).toFixed(1)}T`;
	if (tokens >= 1_000_000_000) return `${(tokens / 1_000_000_000).toFixed(1)}B`;
	if (tokens >= 1_000_000) return `${(tokens / 1_000_000).toFixed(1)}M`;
	if (tokens >= 1_000) return `${(tokens / 1_000).toFixed(1)}k`;
	return String(Math.round(tokens));
}

function escapeTableCell(value: string): string {
	return value.replace(/\\/g, "\\\\").replace(/\|/g, "\\|").replace(/[\r\n]+/g, " ");
}

function renderModelsTable(data: PopularModelsEntryData): string {
	const rows = data.models.map((model, index) => {
		const details = model.metadata;
		const name = details?.name && details.name !== model.id ? ` (${details.name})` : "";
		const values = [
			String(index + 1),
			`${model.id}${name}`,
			`${formatTokens(model.tokens)} tokens`,
			formatPricePerMillion(details?.promptPricePerToken),
			formatPricePerMillion(details?.completionPricePerToken),
			details?.contextLength ? formatTokens(details.contextLength) : "n/a",
		];
		return `| ${values.map(escapeTableCell).join(" | ")} |`;
	});

	return [
		"| Rank | Model | Weekly usage | Input USD / 1M tokens | Output USD / 1M tokens | Context |",
		"| ---: | :--- | ---: | ---: | ---: | ---: |",
		...rows,
	].join("\n");
}

async function appendRankingEntry(
	pi: ExtensionAPI,
	ctx: ExtensionContext,
	isCurrent: () => boolean,
): Promise<void> {
	try {
		const [result, metadata] = await Promise.all([loadPopularModels(), loadModelMetadata()]);
		if (!isCurrent()) return;
		pi.appendEntry<PopularModelsEntryData>(ENTRY_TYPE, {
			rankingCached: result.cached,
			models: result.models.map((model) => ({ ...model, metadata: metadata[model.id] })),
		});
	} catch (error) {
		if (!isCurrent()) return;
		console.error(`popular-models: failed to load OpenRouter ranking: ${error}`);
		ctx.ui.notify("Popular models unavailable (no OpenRouter ranking or cached results).", "warning");
	}
}

export default function popularModels(pi: ExtensionAPI) {
	let requestId = 0;

	pi.registerEntryRenderer<PopularModelsEntryData>(ENTRY_TYPE, (entry, _options, theme) => {
		const data = entry.data;
		if (!data || !Array.isArray(data.models)) {
			return new Text(theme.fg("warning", "[popular models] Missing table data"), 0, 0);
		}

		const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
		const cachedLabel = data.rankingCached ? " · ranking cached" : "";
		box.addChild(new Text(theme.fg("accent", `Top ${MODEL_COUNT} popular models${cachedLabel}`), 0, 0));
		box.addChild(new Text(theme.fg("dim", "OpenRouter weekly tool-call usage · prices in USD per 1M tokens"), 0, 0));
		box.addChild(new Markdown(renderModelsTable(data), 0, 0, getMarkdownTheme()));
		return box;
	});

	pi.on("session_start", (event, ctx) => {
		const currentRequest = ++requestId;
		if (ctx.mode !== "tui") return;
		if (event.reason !== "startup" && event.reason !== "new") return;

		void appendRankingEntry(pi, ctx, () => currentRequest === requestId);
	});

	pi.on("model_select", () => {
		// Preserve the existing guard against a pending load completing after a model change.
		++requestId;
	});
}
