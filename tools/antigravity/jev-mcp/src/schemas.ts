import { z } from "zod";

export type JsonValue = string | number | boolean | null | JsonValue[] | { [key: string]: JsonValue };
export type JevEntry = string | { [key: string]: JsonValue } | JsonValue[] | null;

const jsonValueSchema: z.ZodType<JsonValue> = z.lazy(() =>
  z.union([
    z.string(),
    z.number().finite(),
    z.boolean(),
    z.null(),
    z.array(jsonValueSchema),
    z.record(z.string(), jsonValueSchema),
  ]),
);

export const entrySchema: z.ZodType<JevEntry> = z.union([
  z.string(),
  z.record(z.string(), jsonValueSchema),
  z.array(jsonValueSchema),
  z.null(),
]);

const choiceQuestionSchema = z.object({
  type: z.literal("choice"),
  instructions: entrySchema,
  criteria: z
    .record(z.string().min(1).max(80), entrySchema)
    .refine((criteria) => Object.keys(criteria).length >= 2, "Choice needs at least two criteria."),
});

const noulQuestionSchema = z.object({
  type: z.literal("noul"),
  instructions: entrySchema,
  criteria: z
    .object({
      true: entrySchema.optional(),
      false: entrySchema.optional(),
    })
    .optional(),
});

const scoreQuestionSchema = z.object({
  type: z.literal("score"),
  instructions: entrySchema,
  criteria: z.array(entrySchema).min(2).max(10),
});

export const questionSchema = z.discriminatedUnion("type", [
  choiceQuestionSchema,
  noulQuestionSchema,
  scoreQuestionSchema,
]);

export const questionsSchema = z
  .record(z.string().min(1).max(80), questionSchema)
  .refine((questions) => Object.keys(questions).length >= 1, "At least one question is required.")
  .refine((questions) => Object.keys(questions).length <= 12, "At most 12 questions are allowed per request.");

export const evaluateInputSchema = z.object({
  state: entrySchema,
  questions: questionsSchema,
});

export const gateInputSchema = z.object({
  state: entrySchema,
  criterion: z.string().trim().min(1).max(4000),
  threshold: z.number().finite().min(0).max(1).default(0.7),
});

export type EvaluateInput = z.infer<typeof evaluateInputSchema>;
export type GateInput = z.infer<typeof gateInputSchema>;
export type JevQuestion = z.infer<typeof questionSchema>;

export const MAX_REQUEST_BYTES = 256 * 1024;

export function assertRequestSize(value: unknown): void {
  const encoded = JSON.stringify(value);
  if (Buffer.byteLength(encoded, "utf8") > MAX_REQUEST_BYTES) {
    throw new Error(`Request exceeds the ${MAX_REQUEST_BYTES}-byte input limit.`);
  }
}
