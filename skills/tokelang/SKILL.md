---
name: tokelang
description: >
  Compress your context files, your subagent invocations, and your model's responses
  via a style guide. Controlled by a level dial (L1 / L2 / L3) plus a semantic validator
  that refuses to compress when meaning would be lost.
  For real input compression (every prompt you type), use the separate `tokelang-cli wrap`
  alias — Claude Code's plugin hooks cannot rewrite user input directly.
  Open source under Apache 2.0. Auto-activates on session start. Disable: /tokelang-level off
---

# Tokelang for Claude Code

This skill compresses tokens at three points where Claude Code's plugin hooks make it possible:

1. **Context files** — your `CLAUDE.md`, agent personas, RAG headers (one-shot via `/tokelang-compress <file>`)
2. **Subagent invocations** — the prompt argument passed to the `Task` tool gets compressed before the subagent receives it (PreToolUse hook)
3. **Output style** — system-context injection at session start nudges the model to respond briefly (SessionStart hook)

For **user-input compression** (compressing every prompt you type), use the separate `tokelang-cli wrap` command — Claude Code's plugin hook contract is additive only and cannot rewrite user input. See the README "Wrap mode for real input compression" section for setup.

## Why compress at all

Compressed prompts don't just save money. They make the model **think better**. From Hakim 2026 ([arXiv:2604.00025](https://arxiv.org/abs/2604.00025), "Brevity Constraints Reverse Performance Hierarchies in Language Models"):

> "Constraining large models to produce brief responses improves accuracy by 26 percentage points and reduces performance gaps by up to two-thirds. Most critically, brevity constraints completely reverse performance hierarchies on mathematical reasoning and scientific knowledge benchmarks."

The verbose English you usually write masks the model's reasoning capacity. Compression strips the parsing tax. We give you that compression automatically, with a validator that refuses to drop semantic content.

## The level dial — what's ON by default

You install Tokelang at **Level 2 (Balanced)**. The skill side does this automatically:

| Surface | Level 2 behavior |
|---|---|
| Context files | Untouched until you run `/tokelang-compress <file>` |
| Subagent inputs (Task tool prompt) | Compressed automatically every Task invocation |
| Output style | Lite — "be concise, drop hedges and filler" injected into system context |
| **User input** | **Not touched by the skill.** Use `tokelang-cli wrap` for that. |

If even the output-style nudge feels too aggressive, dial back:

```
/tokelang-level 1     → output style guide only; subagent compression off
/tokelang-level off   → skill stays loaded but does nothing
/tokelang-level 3     → + aggressive output style
```

The setting persists across sessions in `~/.claude/settings.json` under `"tokelang.level"`.

## Persistence

Active every response unless you say "stop tokelang" or run `/tokelang-level off`. The skill does not "drift off" after many turns and will not silently disable itself.

The engine runs locally — your prompts do NOT leave your machine. The hosted API at tokelang.com is a separate product (used by the dashboard); the CLI bundled with this skill is fully offline-capable.

## Validator — why nothing important gets dropped

Every compression candidate (file compression OR subagent input) passes through a semantic validator before replacing the original. The validator checks:

- **Content recall** — 0.85 minimum for context files, 0.90 minimum for subagent inputs (subagents are higher-stakes than per-turn prompts)
- **Hard zones** — negations (`not`, `never`, `only`), numeric thresholds, code blocks, URLs, file paths, regex literals, quoted strings, contract vocabulary (`shall`, `must`) — never rewritten

If the validator rejects a candidate, the original passes through unchanged. **Tokelang never compresses past what the model can still reason about.**

## Slash commands

| Command | What it does |
|---|---|
| `/tokelang-compress <file>` | Compress a context file (CLAUDE.md, agent persona, etc.) with `.original.md` backup. Reversible via `/tokelang-restore`. |
| `/tokelang-restore <file>` | Restore a compressed file from its `.original.md` backup. |
| `/tokelang-stats` | Show savings for current session: tokens saved, % reduction, equivalent $ cost. |
| `/tokelang-level [1\|2\|3\|off]` | Change compression aggressiveness. |

## What this skill will NOT do

- **Compress your typed input via plugin** — Claude Code's UserPromptSubmit hook is additive-only. For real input compression, use `tokelang-cli wrap` alias (one line of shell config; see README).
- **Compress tool results** — Claude Code's PostToolUse hook is additive-only. Tool results pass through to the next turn as-is.
- **Touch your output text** — the model speaks however it wants; we only nudge via style guide. No post-processing.
- **Compress sensitive content** — Task subagent prompts that look like security warnings, credentials, or irreversible actions auto-skip compression (escape hatch).
- **Hide what it's doing** — `/tokelang-stats` always tells you exactly what's been compressed and by how much. Statusline shows cumulative savings.
- **Phone home** — engine runs locally. Nothing sent to tokelang.com unless you explicitly use the hosted API.

## Off-switch summary (so you can always disable)

Quickest: type `/tokelang-level off` in any session.
Persistent: edit `~/.claude/settings.json`, set `"tokelang.level": "off"`.
Uninstall: `claude plugin uninstall tokelang`.

There is no telemetry. There is no usage limit. The skill is yours to use, modify, or fork (Apache 2.0).
