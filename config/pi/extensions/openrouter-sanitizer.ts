import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const CONFIG = {
  // Neutralize XML/ChatML role tags and bracketed role headers in context strings.
  defangRoleDelimiters: true,
  // Mask secrets and PII inside toolCall arguments.
  maskSecretsInToolCalls: true,
  // Also mask secrets and PII in visible message text and thinking blocks.
  maskSecretsInAllText: true,
};

const ROLE_DELIMITER_PATTERNS: Array<[RegExp, (match: string) => string]> = [
  [
    /<(\/?(?:system|user|assistant|developer|instructions?|context|prompt|tool_call|tool_response|function_call|function_response|observation|thought|thinking|scratchpad|admin|root)(?:\s[^>]*)?|\|(?:im_start|im_end|endoftext|system|user|assistant|tool|eot_id|start_header_id|end_header_id)\|)>/gi,
    (match) => "<\u200B" + match.slice(1),
  ],
  [
    /\[(\/?(?:system|user|assistant|developer|inst|sys|admin|human|ai|bot|model|tool|function|observation|context|prompt|instructions?)(?:(?::|\s+)[^\]]*)?)\]/gi,
    (match) => "[\u200B" + match.slice(1),
  ],
];

const SECRET_AND_PII_PATTERNS: Array<[RegExp, string]> = [
  [
    /-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----/g,
    "[MASKED_PRIVATE_KEY]",
  ],
  [
    /\bsk-(?:or-v1-|ant-|proj-|live-|test-)?[a-zA-Z0-9_-]{16,}\b/g,
    "[MASKED_API_KEY]",
  ],
  [/\bsk-placeholder\b/g, "[MASKED_API_KEY]"],
  [
    /\b(?:gh[pousr]_[a-zA-Z0-9]{20,}|github_pat_[a-zA-Z0-9_]{20,})\b/g,
    "[MASKED_GH_TOKEN]",
  ],
  [/\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/g, "[MASKED_AWS_KEY]"],
  [/\bAIza[0-9A-Za-z_-]{35}\b/g, "[MASKED_GOOGLE_KEY]"],
  [/\bxox[baprs]-[0-9a-zA-Z-]{10,}\b/g, "[MASKED_SLACK_TOKEN]"],
  [/\bBearer\s+[a-zA-Z0-9._-]{20,}\b/gi, "Bearer [MASKED_TOKEN]"],
  [
    /\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b/g,
    "[EMAIL]",
  ],
  [
    /(?:\+?1[-.\s]?)?(?:\(\d{3}\)|\b\d{3})[-.\s]\d{3}[-.\s]\d{4}\b/g,
    "[PHONE]",
  ],
];

function sanitizeString(text: string, maskSecrets: boolean): string {
  let result = text;

  if (CONFIG.defangRoleDelimiters) {
    for (const [pattern, replace] of ROLE_DELIMITER_PATTERNS) {
      result = result.replace(pattern, replace);
    }
  }

  if (maskSecrets) {
    for (const [pattern, replacement] of SECRET_AND_PII_PATTERNS) {
      result = result.replace(pattern, replacement);
    }
  }

  return result;
}

function sanitizeUnknown<T>(value: T, maskSecrets: boolean): T {
  if (typeof value === "string") {
    const replacement = sanitizeString(value, maskSecrets);
    return (replacement === value ? value : replacement) as T;
  }

  if (Array.isArray(value)) {
    let changed = false;
    const sanitized = value.map((item) => {
      const replacement = sanitizeUnknown(item, maskSecrets);
      if (replacement !== item) changed = true;
      return replacement;
    });
    return (changed ? sanitized : value) as T;
  }

  if (value !== null && typeof value === "object") {
    let changed = false;
    const sanitized = Object.fromEntries(
      Object.entries(value).map(([key, item]) => {
        const replacement = sanitizeUnknown(item, maskSecrets);
        if (replacement !== item) changed = true;
        return [key, replacement];
      }),
    );
    return (changed ? sanitized : value) as T;
  }

  return value;
}

export default function (pi: ExtensionAPI) {
  pi.on("context", async (event) => {
    let messagesChanged = false;
    const messages = event.messages.map((message) => {
      if (typeof message.content === "string") {
        const content = sanitizeString(
          message.content,
          CONFIG.maskSecretsInAllText,
        );
        if (content === message.content) return message;

        messagesChanged = true;
        return { ...message, content };
      }

      if (!Array.isArray(message.content)) return message;

      let messageChanged = false;
      const content = message.content.map((block) => {
        if (block === null || typeof block !== "object") return block;

        if (block.type === "text" && typeof block.text === "string") {
          const text = sanitizeString(block.text, CONFIG.maskSecretsInAllText);
          if (text === block.text) return block;

          messageChanged = true;
          return { ...block, text };
        }

        if (
          block.type === "thinking" &&
          typeof block.thinking === "string"
        ) {
          const thinking = sanitizeString(
            block.thinking,
            CONFIG.maskSecretsInAllText,
          );
          if (thinking === block.thinking) return block;

          messageChanged = true;
          return { ...block, thinking };
        }

        if (block.type === "toolCall") {
          const arguments_ = sanitizeUnknown(
            block.arguments,
            CONFIG.maskSecretsInToolCalls,
          );
          if (arguments_ === block.arguments) return block;

          messageChanged = true;
          return { ...block, arguments: arguments_ };
        }

        return block;
      });

      if (!messageChanged) return message;
      messagesChanged = true;
      return { ...message, content };
    });

    // Preserve the provider's unchanged context and cache prefix where possible.
    return messagesChanged ? { messages } : undefined;
  });
}
