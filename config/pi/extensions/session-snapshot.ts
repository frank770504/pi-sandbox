/**
 * Session Snapshot Extension
 *
 * Takes a hardlink snapshot of the project directory at session start, so
 * accidental damage during the session can be rolled back. Delegates to
 * ~/.pi/agent/bin/pi-snap.
 */
import { spawn } from "node:child_process";
import { lstatSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const SNAP_SCRIPT = join(homedir(), ".pi", "agent", "bin", "pi-snap");
const MIN_INTERVAL_MS = 60_000;

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (event, ctx) => {
    // "reload" happens mid-session (config reload), not a work boundary.
    if (event.reason === "reload") return;

    const cwd = ctx.cwd;
    // Must match the project key scheme used by pi-snap: all "/" -> "_".
    const key = cwd.split("/").join("_");
    const latest = join(homedir(), ".pi", "snapshots", key, "latest");

    // Debounce: don't stack duplicate snapshots from quick re-fires.
    // lstat reads the symlink's own mtime (rsync -a preserves the target dir's
    // mtime, so statSync would report the source's old mtime).
    try {
      if (Date.now() - lstatSync(latest).mtimeMs < MIN_INTERVAL_MS) return;
    } catch {
      // No prior snapshot for this project — proceed.
    }

    const child = spawn("bash", [SNAP_SCRIPT, cwd], {
      stdio: ["ignore", "pipe", "pipe"],
    });
    let out = "";
    let err = "";
    child.stdout.on("data", (d) => (out += d.toString()));
    child.stderr.on("data", (d) => (err += d.toString()));
    child.on("error", (e) => {
      ctx.ui.notify(`pi-snap failed to start: ${e.message}`, "error");
    });
    child.on("close", (code) => {
      if (code === 0) {
        ctx.ui.notify(`Snapshot: ${out.trim()}`, "info");
      } else {
        ctx.ui.notify(`pi-snap failed (exit ${code}): ${err.trim()}`, "error");
      }
    });
  });
}
