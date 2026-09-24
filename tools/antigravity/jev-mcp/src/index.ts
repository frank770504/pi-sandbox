import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { ZodError } from "zod";
import { MissingApiKeyError, UnsafeApiKeyFileError } from "./credentials.js";
import { evaluateInputSchema, gateInputSchema } from "./schemas.js";
import { createJevToolHandlers, createSystemOneCall } from "./service.js";

const server = new McpServer({
  name: "pi-sandbox-typesafe-jev",
  version: "0.1.0",
});

const handlers = createJevToolHandlers(createSystemOneCall());

function asTextResult(value: unknown) {
  return { content: [{ type: "text" as const, text: JSON.stringify(value) }] };
}

function asSafeToolError(error: unknown) {
  if (error instanceof MissingApiKeyError || error instanceof UnsafeApiKeyFileError) {
    return { isError: true, ...asTextResult({ error: error.message }) };
  }
  if (error instanceof ZodError) {
    return {
      isError: true,
      ...asTextResult({ error: "Invalid tool input; submitted values were not echoed." }),
    };
  }
  return {
    isError: true,
    ...asTextResult({ error: "TypeSafe request failed. Check network/API configuration; details were not logged." }),
  };
}

server.registerTool(
  "jev_evaluate",
  {
    title: "TypeSafe Jev Evaluate",
    description:
      "Evaluate explicit JSON/text state with typed choice, noul, and score questions using TypeSafe Jev. This sends the supplied state and questions to TypeSafe. Do not include sensitive code, diffs, credentials, private identifiers, logs, or customer data unless the user explicitly authorizes it.",
    inputSchema: evaluateInputSchema,
  },
  async (input) => {
    try {
      return asTextResult(await handlers.evaluate(input));
    } catch (error) {
      return asSafeToolError(error);
    }
  },
);

server.registerTool(
  "jev_gate",
  {
    title: "TypeSafe Jev Gate",
    description:
      "Check whether caller-supplied state satisfies an acceptance criterion using a TypeSafe Jev noul judgment. Default threshold is 0.70. This sends the supplied state/diff and criterion to TypeSafe. It does not read repository files or run commands; the caller must explicitly provide content that is safe and authorized to share.",
    inputSchema: gateInputSchema,
  },
  async (input) => {
    try {
      return asTextResult(await handlers.gate(input));
    } catch (error) {
      return asSafeToolError(error);
    }
  },
);

const transport = new StdioServerTransport();
await server.connect(transport);
