---
name: tokelang-stats
description: >
  Show savings for the current session — tokens compressed, % reduction, and an approximate
  dollar figure at Anthropic's published input rate. Reads this session's local sidecar via
  the bundled CLI; no network call. Counts only what the skill compresses (Task subagent
  prompts + WebFetch/Search tool results + /tokelang-compress file runs).
  Trigger: /tokelang-stats
---

# Session savings stats

Reports what Tokelang has saved you in the current Claude Code session.

## Trigger

- `/tokelang-stats` — explicit
- "show tokelang savings" — natural language

## Process

1. Resolve the current session id (Claude Code supplies it to the hooks; the sidecar is named for it).

2. Run the bundled CLI over this session's sidecar — the file the hooks append a
   `surface,orig_tokens,comp_tokens,unix_ts` line to on every compression event:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/bin/tokelang-cli" stats --transcript ~/.claude/.tokelang-session-<session_id>
   ```
   It emits JSON: `{events, original_tokens, compressed_tokens, tokens_saved, pct_saved}`. All token
   counts are real cl100k (computed in-process; no network).

3. Convert `tokens_saved` to an approximate dollar figure at the model's published input rate
   (e.g. Sonnet 4.6 input $3/MTok) for display.

4. Print summary:
   ```
   Tokelang — this session
   Compression events:    14   (subagent prompts + tool results + any /tokelang-compress file runs)
   Input tokens saved:    4,287 (32% reduction)
   Estimated $ saved:     ~$0.013 (input $3/MTok)
   ```

> **Counted:** Task subagent prompts (PreToolUse), WebFetch/WebSearch tool results (PostToolUse, via
> `updatedToolOutput`), and `/tokelang-compress` file runs.
> **Not counted** (be honest about scope): per-turn user input — the plugin can't rewrite it, so use
> `tokelang-cli wrap` for that; **Read/Edit/Bash/Grep tool results** — deliberately not compressed
> (code/logs/data are correctness-critical); and model output — never post-processed. Stats reflect
> only what the skill actually compresses.

## Lifetime stats (statusline)

The statusline shows **lifetime** cumulative savings across all your Claude Code sessions — different from this command which shows current-session only. Lifetime stats live in `~/.claude/.tokelang-lifetime.json` and update on every `Stop` hook.

## Why both per-session AND lifetime?

- Per-session — useful when debugging "did Tokelang actually compress my last turn?"
- Lifetime — useful when justifying ROI ("$X.XX saved last month")

## What this command does NOT do

- Phone home (everything is computed locally from `$CLAUDE_TRANSCRIPT_PATH`)
- Include the hosted API's compression stats (separate product)
- Predict future savings (no forecasting)

## Example

```
> /tokelang-stats

Tokelang — this session
Compression events:    9   (subagent prompts + tool results)
Input tokens saved:    1,840 / 5,210 (35%)
Estimated $ saved:     ~$0.006 (input $3/MTok)
Lifetime savings:      tracked in ~/.claude/.tokelang-lifetime.json (shown in the statusline)
```
