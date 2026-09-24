import assert from "node:assert/strict";
import test from "node:test";
import { evaluateInputSchema, gateInputSchema, MAX_REQUEST_BYTES, assertRequestSize } from "../src/schemas.js";

test("evaluation accepts the fixed multi-question score loop schema", () => {
  const result = evaluateInputSchema.safeParse({
    state: { task: "synthetic", plan: ["inspect", "test"] },
    questions: {
      overall: { type: "score", instructions: "Score alignment.", criteria: ["weak", "partial", "strong", "excellent"] },
      primary_gap: { type: "choice", instructions: "Pick the main gap.", criteria: { none: "No gap", scope: "Scope gap" } },
    },
  });
  assert.equal(result.success, true);
});

test("gate schema defaults to a 0.70 threshold", () => {
  const result = gateInputSchema.parse({ state: "synthetic patch", criterion: "The patch passes." });
  assert.equal(result.threshold, 0.7);
});

test("score question requires at least two ordered anchors", () => {
  const result = evaluateInputSchema.safeParse({
    state: "synthetic",
    questions: { score: { type: "score", instructions: "Score.", criteria: ["one"] } },
  });
  assert.equal(result.success, false);
});

test("request size limit is enforced without echoing input", () => {
  assert.throws(() => assertRequestSize("x".repeat(MAX_REQUEST_BYTES + 1)), /input limit/);
});
