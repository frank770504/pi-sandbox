import { TypeSafeClient, choice, noul, score } from "@typesafe-ai/sdk";
import type {
  ChoiceCriteria,
  EntryType,
  NoulQuestion,
  Questions,
  ScoreCriteria,
  SystemOneRequest,
  SystemOneResult,
} from "@typesafe-ai/sdk";
import { resolveApiKey, MissingApiKeyError } from "./credentials.js";
import { assertRequestSize, evaluateInputSchema, gateInputSchema } from "./schemas.js";
import type { EvaluateInput, GateInput, JevQuestion } from "./schemas.js";

export type SystemOneCall = (
  request: SystemOneRequest<Questions>,
) => Promise<SystemOneResult<Questions>>;

export interface JevToolHandlers {
  evaluate(input: unknown): Promise<Record<string, unknown>>;
  gate(input: unknown): Promise<Record<string, unknown>>;
}

function toSystemOneQuestions(input: Record<string, JevQuestion>): Questions {
  const result: Questions = {};

  for (const [id, question] of Object.entries(input)) {
    if (question.type === "choice") {
      result[id] = choice(question.instructions as EntryType, question.criteria as ChoiceCriteria);
    } else if (question.type === "noul") {
      result[id] = noul(
        question.instructions as EntryType,
        question.criteria as NoulQuestion["criteria"],
      );
    } else {
      result[id] = score(question.instructions as EntryType, question.criteria as unknown as ScoreCriteria);
    }
  }

  return result;
}

export function createJevToolHandlers(systemOne: SystemOneCall): JevToolHandlers {
  return {
    async evaluate(untrustedInput) {
      const input: EvaluateInput = evaluateInputSchema.parse(untrustedInput);
      assertRequestSize(input);

      const request: SystemOneRequest<Questions> = {
        state: input.state as EntryType,
        questions: toSystemOneQuestions(input.questions as Record<string, JevQuestion>),
      };
      const response = await systemOne(request);

      return {
        answers: response.answers,
        model: response.model,
        usage: response.usage,
      };
    },

    async gate(untrustedInput) {
      const input: GateInput = gateInputSchema.parse(untrustedInput);
      assertRequestSize(input);

      const response = await systemOne({
        state: {
          acceptance_criterion: input.criterion,
          submitted_state: input.state as EntryType,
        },
        questions: {
          gate_passed: noul(
            "Does the submitted state satisfy the acceptance criterion in state.acceptance_criterion?",
            {
              true: "The submitted state satisfies the stated acceptance criterion.",
              false: "The submitted state does not satisfy the stated acceptance criterion.",
            },
          ),
        },
      });

      const answer = response.answers.gate_passed;
      if (answer.type !== "noul" || !Number.isFinite(answer.noul) || answer.noul < 0 || answer.noul > 1) {
        throw new Error("TypeSafe returned an invalid gate probability.");
      }

      return {
        criterion: input.criterion,
        probability: answer.noul,
        threshold: input.threshold,
        passed: answer.noul >= input.threshold,
        model: response.model,
        usage: response.usage,
      };
    },
  };
}

export function createSystemOneCall(): SystemOneCall {
  let client: TypeSafeClient | undefined;

  return async (request) => {
    if (!client) {
      const apiKey = resolveApiKey();
      if (!apiKey) throw new MissingApiKeyError();
      client = new TypeSafeClient({ apiKey });
    }

    return client.systemOne(request);
  };
}
