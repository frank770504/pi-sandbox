---
name: catch-up-project
description: Catch up on the project. Use when a new session starts, when asked to catch up on the project, or when you need to understand the project architecture, rules, and feature specifications.
---

# Catch Up Project

## Overview

This skill helps you quickly get up to speed on the current project. The project
has strict workflow rules, architectural guidelines, and detailed feature
specifications that MUST be understood before making changes.

This skill is shared by Pi and Antigravity, so use the tool names of the agent
you are running in when following the steps below.

## Catch-Up Workflow

To fully catch up on the project, you must read the core documentation and
relevant feature specifications.

### Step 1: Read Project Rules and Architecture

Read the project rules file in the repository root:

- Read `AGENT.md` if it exists.
- Otherwise, read `GEMINI.md`.

Use the file-reading tool of the current agent (`read` in Pi, `read_file` in
Antigravity).

### Step 2: Read Feature Specifications

The project has several feature specifications in the `docs/specs/` directory.
If you are doing a general catch-up or onboarding, you should read all of them to
understand the full context. If you are working on a specific feature, read the
relevant spec as dictated by the project rules.

*Tip: Read these files in parallel tool calls to save turns.*
