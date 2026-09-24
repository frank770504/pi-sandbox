import assert from "node:assert/strict";
import test from "node:test";
import { isSafeKeyFile, MissingApiKeyError, UnsafeApiKeyFileError, resolveApiKey } from "../src/credentials.js";

test("credential resolver prefers a non-empty environment key", () => {
  assert.equal(resolveApiKey({ TYPESAFE_API_KEY: " dummy-key " }), "dummy-key");
});

test("credential resolver does not guess or read an implicit secret path", () => {
  assert.equal(resolveApiKey({}), null);
  assert.equal(new MissingApiKeyError().name, "MissingApiKeyError");
  assert.equal(new UnsafeApiKeyFileError().name, "UnsafeApiKeyFileError");
});

test("secret file policy requires owner-only permissions and matching owner", () => {
  assert.equal(isSafeKeyFile({ mode: 0o100600, uid: 1000 }, 1000, "linux"), true);
  assert.equal(isSafeKeyFile({ mode: 0o100664, uid: 1000 }, 1000, "linux"), false);
  assert.equal(isSafeKeyFile({ mode: 0o100600, uid: 2000 }, 1000, "linux"), false);
  assert.equal(isSafeKeyFile({ mode: 0o100664, uid: 2000 }, 1000, "win32"), true);
});
