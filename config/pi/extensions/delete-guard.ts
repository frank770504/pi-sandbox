/**
 * Delete Guard Extension
 *
 * Blocks file/directory deletion operations (rm, rmdir, unlink, destructive
 * redirects, overwrites) unless the user explicitly grants permission.
 *
 * Intercepts:
 *   - bash: rm, rmdir, unlink, deltree, truncate -s 0, dd if=/dev/null,
 *           and simple destructive redirects (> file to truncate an existing file)
 *   - write: overwriting existing files (destructive to previous content)
 *
 * Safe in non-interactive modes: blocks by default when no UI is available.
 */

import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { access } from "node:fs/promises";

/** Pattern for rm with recursive/force flags (triggers high-alert prompt) */
const RM_RECURSIVE = /\brm\s+(-[rf]*[rf]|--recursive|--force)/i;

/** Pattern for bare rm (no -r flag) – still deletes files */
const RM_BARE = /\brm\s+(-[f]*[f])?\s+/i;

/** Pattern for rmdir */
const RMDIR = /\brmdir\s+/i;

/** Pattern for unlink */
const UNLINK = /\bunlink\s+/i;

/** Pattern for destructive redirect (> file) that truncates an existing file */
const DESTRUCTIVE_REDIRECT =
  /(?:\s+|^|\||;|&&)\s*>\s+(?:['"])?([^'"\s;|&]+)(?:['"])?\s*$/m;

/** Destructive git commands (git is the primary safety net; guard it). */
const GIT_DESTRUCTIVE = [
  { re: /\bgit\s+reset\s+--hard\b/i, label: "git reset --hard" },
  { re: /\bgit\s+checkout\s+--\s+/i, label: "git checkout -- <paths> (discard work)" },
  { re: /\bgit\s+clean\s+(?:-[a-z]*f[a-z]*|--force)\b/i, label: "git clean -f (delete untracked files)" },
  { re: /\bgit\s+stash\s+(?:drop|clear)\b/i, label: "git stash drop/clear (delete stash)" },
];

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    // ----- Intercept bash commands -----
    if (isToolCallEventType("bash", event)) {
      const command = event.input.command;

      // Check for rm -rf / (nuclear – always block without question)
      if (/\brm\s+(-rf?|--recursive)\s+\/\s/i.test(command)) {
        return {
          block: true,
          reason: "Blocked: rm -rf / is never allowed without explicit override",
        };
      }

      // Check for recursive rm (rm -rf ...)
      if (RM_RECURSIVE.test(command)) {
        if (!ctx.hasUI) {
          return {
            block: true,
            reason:
              "Blocked: recursive delete command with no UI to confirm. " +
              "Set ctx.hasUI=true or re-run interactively.",
          };
        }

        const shortCmd =
          command.length > 200 ? command.slice(0, 200) + "..." : command;
        const allowed = await ctx.ui.confirm(
          "⚠️  Recursive delete detected",
          `Command:\n  ${shortCmd}\n\nAllow this operation?`,
        );
        if (!allowed) {
          return { block: true, reason: "Recursive delete blocked by user" };
        }
        return undefined;
      }

      // Check for bare rm (delete file(s))
      if (
        RM_BARE.test(command) ||
        RMDIR.test(command) ||
        UNLINK.test(command)
      ) {
        if (!ctx.hasUI) {
          return {
            block: true,
            reason:
              "Blocked: file/directory delete command with no UI to confirm.",
          };
        }

        const shortCmd =
          command.length > 200 ? command.slice(0, 200) + "..." : command;
        const allowed = await ctx.ui.confirm(
          "⚠️  File/directory delete detected",
          `Command:\n  ${shortCmd}\n\nAllow this operation?`,
        );
        if (!allowed) {
          return { block: true, reason: "Delete blocked by user" };
        }
        return undefined;
      }

      // Check for truncate -s 0 <file> (empties a file = content deletion)
      if (/\btruncate\s+-s\s+0\b/i.test(command)) {
        if (!ctx.hasUI) {
          return {
            block: true,
            reason:
              "Blocked: file truncation command with no UI to confirm.",
          };
        }
        const shortCmd =
          command.length > 200 ? command.slice(0, 200) + "..." : command;
        const allowed = await ctx.ui.confirm(
          "⚠️  File truncation detected",
          `Command:\n  ${shortCmd}\n\nAllow this operation? (empties file content)`,
        );
        if (!allowed) {
          return { block: true, reason: "File truncation blocked by user" };
        }
        return undefined;
      }

      // Check for dd if=/dev/null of=<file> (zeroes out a file)
      if (/\bdd\s+if=\/dev\/null\b/i.test(command)) {
        if (!ctx.hasUI) {
          return {
            block: true,
            reason: "Blocked: dd zero-file command with no UI to confirm.",
          };
        }
        const shortCmd =
          command.length > 200 ? command.slice(0, 200) + "..." : command;
        const allowed = await ctx.ui.confirm(
          "⚠️  File zeroing detected",
          `Command:\n  ${shortCmd}\n\nAllow this operation? (overwrites file with nulls)`,
        );
        if (!allowed) {
          return { block: true, reason: "File zeroing blocked by user" };
        }
        return undefined;
      }

      // Check for simple destructive redirect (> existingfile)
      // This only catches trivial cases like `> /path/to/file` at the end of a command.
      const redirectMatch = DESTRUCTIVE_REDIRECT.exec(command);
      if (redirectMatch) {
        const targetPath = redirectMatch[1];
        // Only prompt if the redirect has no command before it (bare redirect > file)
        // or if it's a simple standalone truncation.
        const bareRedirect = /^\s*>\s+/i.test(command);
        if (bareRedirect) {
          if (!ctx.hasUI) {
            return {
              block: true,
              reason:
                "Blocked: file truncation via redirect with no UI to confirm.",
            };
          }
          const shortCmd =
            command.length > 200 ? command.slice(0, 200) + "..." : command;
          const allowed = await ctx.ui.confirm(
            "⚠️  File truncation via redirect detected",
            `Command:\n  ${shortCmd}\n\nAllow this operation? (overwrites file content)`,
          );
          if (!allowed) {
            return {
              block: true,
              reason: "File truncation via redirect blocked by user",
            };
          }
        }
      }

      // ----- Intercept destructive git commands -----
      const isGitRestoreDiscard =
        /\bgit\s+restore\b/i.test(command) && !/--staged\b/.test(command);
      const gitMatch = GIT_DESTRUCTIVE.find((g) => g.re.test(command));
      const gitLabel = isGitRestoreDiscard
        ? "git restore (discard working-tree changes)"
        : gitMatch?.label;

      if (gitLabel) {
        if (!ctx.hasUI) {
          return {
            block: true,
            reason: `Blocked: ${gitLabel} with no UI to confirm.`,
          };
        }
        const shortCmd =
          command.length > 200 ? command.slice(0, 200) + "..." : command;
        const allowed = await ctx.ui.confirm(
          "⚠️  Destructive git operation detected",
          `Command:\n  ${shortCmd}\n\nThis discards or deletes work. Allow?`,
        );
        if (!allowed) {
          return { block: true, reason: "Destructive git operation blocked by user" };
        }
        return undefined;
      }

      return undefined;
    }

    // ----- Intercept write tool (overwriting existing files) -----
    if (isToolCallEventType("write", event)) {
      const targetPath = event.input.path;
      if (!targetPath || typeof targetPath !== "string") return undefined;

      try {
        // Check if file already exists
        await access(targetPath);
        // File exists — overwriting = destructive to existing content
        if (!ctx.hasUI) {
          return {
            block: true,
            reason: `Blocked: overwriting existing file "${targetPath}" with no UI to confirm.`,
          };
        }

        const allowed = await ctx.ui.confirm(
          "⚠️  Overwrite existing file?",
          `Path: ${targetPath}\n\nThis file already exists. Overwriting it will destroy the current content.\nAllow?`,
        );
        if (!allowed) {
          return { block: true, reason: "File overwrite blocked by user" };
        }
        return undefined;
      } catch {
        // File does not exist — safe to create
        return undefined;
      }
    }

    return undefined;
  });
}