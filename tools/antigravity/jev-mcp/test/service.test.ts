import assert from "node:assert/strict";
import test from "node:test";
import { createJevToolHandlers } from "../src/service.js";
import type { SystemOneCall } from "../src/service.js";
import type { Questions, SystemOneRequest, SystemOneResult } from "@typesafe-ai/sdk";

function fakeSystemOne(
  response: SystemOneResult<Questions>,
  capture?: (request: SystemOneRequest<Questions>) => void,
): SystemOneCall {
  return async (request) => {
    capture?.(request);
    return response;
  };
}

const emptyUsage = { input_tokens: 12, output_tokens: 3 };

test("evaluate forwards typed score and choice questions and returns typed answers", async () => {
  let captured: SystemOneRequest<Questions> | undefined;
  const response = {
    model: "jev-latest",
    usage: emptyUsage,
    answers: {
      alignment: { type: "score", score: 3.4, confidence: 0.8, legend: {}, probabilities: {} },
      gap: { type: "choice", choice: "none", confidence: 0.9, probabilities: { none: 0.9, scope: 0.1 } },
    },
  } as unknown as SystemOneResult<Questions>;
  const handlers = createJevToolHandlers(fakeSystemOne(response, (request) => { captured = request; }));

  const result = await handlers.evaluate({
    state: { task: "synthetic task", plan: ["inspect", "test"] },
    questions: {
      alignment: { type: "score", instructions: "Score alignment.", criteria: ["0: materially misaligned", "1: major gap", "2: meaningful gap", "3: minor gap", "4: fully aligned"] },
      gap: { type: "choice", instructions: "Choose the primary gap.", criteria: { none: "No gap", scope: "Scope issue" } },
    },
  });

  assert.equal(captured?.questions.alignment?.type, "score");
  assert.equal(captured?.questions.gap?.type, "choice");
  assert.deepEqual((result.answers as Record<string, unknown>).alignment, response.answers.alignment);
  assert.equal(result.model, "jev-latest");
});

test("gate uses caller state only, applies the default 0.70 threshold, and passes equality", async () => {
  let captured: SystemOneRequest<Questions> | undefined;
  const response = {
    model: "jev-latest",
    usage: emptyUsage,
    answers: { gate_passed: { type: "noul", noul: 0.7 } },
  } as unknown as SystemOneResult<Questions>;
  const handlers = createJevToolHandlers(fakeSystemOne(response, (request) => { captured = request; }));

  const result = await handlers.gate({ state: "synthetic diff only", criterion: "The synthetic criterion passes." });

  assert.deepEqual(captured?.state, {
    acceptance_criterion: "The synthetic criterion passes.",
    submitted_state: "synthetic diff only",
  });
  assert.equal(captured?.questions.gate_passed?.type, "noul");
  assert.equal(result.probability, 0.7);
  assert.equal(result.threshold, 0.7);
  assert.equal(result.passed, true);
});

test("gate honors a caller-supplied threshold", async () => {
  const response = {
    model: "jev-latest",
    usage: emptyUsage,
    answers: { gate_passed: { type: "noul", noul: 0.75 } },
  } as unknown as SystemOneResult<Questions>;
  const handlers = createJevToolHandlers(fakeSystemOne(response));

  const result = await handlers.gate({ state: "synthetic", criterion: "Pass", threshold: 0.8 });
  assert.equal(result.passed, false);
  assert.equal(result.threshold, 0.8);
});

test("invalid evaluation inputs are rejected before calling TypeSafe", async () => {
  let called = false;
  const handlers = createJevToolHandlers(async () => {
    called = true;
    throw new Error("unexpected call");
  });

  await assert.rejects(
    handlers.evaluate({ state: "x", questions: { score: { type: "score", instructions: "Score", criteria: ["only one"] } } }),
  );
  assert.equal(called, false);
});

test("gate rejects thresholds outside 0..1 before calling TypeSafe", async () => {
  let called = false;
  const handlers = createJevToolHandlers(async () => {
    called = true;
    throw new Error("unexpected call");
  });

  await assert.rejects(handlers.gate({ state: "x", criterion: "Pass", threshold: 1.1 }));
  assert.equal(called, false);
});
