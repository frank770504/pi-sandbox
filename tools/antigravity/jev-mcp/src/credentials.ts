import * as fs from "node:fs";

export class MissingApiKeyError extends Error {
  constructor() {
    super("TypeSafe credentials are not configured. Set TYPESAFE_API_KEY or TYPESAFE_API_KEY_FILE.");
    this.name = "MissingApiKeyError";
  }
}

export class UnsafeApiKeyFileError extends Error {
  constructor() {
    super("The TypeSafe key file must be owned by the current user and readable only by its owner (mode 0600 or stricter).");
    this.name = "UnsafeApiKeyFileError";
  }
}

export function isSafeKeyFile(
  stat: { mode: number; uid: number },
  currentUid: number | undefined,
  platform: string = process.platform,
): boolean {
  if (platform === "win32") return true;
  return (stat.mode & 0o077) === 0 && (currentUid === undefined || stat.uid === currentUid);
}

/** Resolve credentials without logging or returning their value to tool output. */
export function resolveApiKey(env: NodeJS.ProcessEnv = process.env): string | null {
  const fromEnvironment = env.TYPESAFE_API_KEY?.trim();
  if (fromEnvironment) return fromEnvironment;

  const filePath = env.TYPESAFE_API_KEY_FILE?.trim();
  if (!filePath) return null;

  const stat = fs.statSync(filePath);
  if (!stat.isFile()) throw new Error("TYPESAFE_API_KEY_FILE must refer to a regular file.");
  const currentUid = typeof process.getuid === "function" ? process.getuid() : undefined;
  if (!isSafeKeyFile(stat, currentUid)) throw new UnsafeApiKeyFileError();

  const key = fs.readFileSync(filePath, "utf8").trim();
  return key || null;
}
