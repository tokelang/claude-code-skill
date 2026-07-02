---
name: tokelang
description: >
  The Tokelang compression dial. `/tokelang off|lite|full` sets how aggressively the skill
  compresses subagent briefs, WebFetch/WebSearch tool results, and the model's own verbosity —
  each guarded by a semantic validator that refuses any fold that would drop meaning.
  Default is `lite`. `/tokelang` with no argument shows the current level. Apache 2.0.
---

# /tokelang — the compression dial

`/tokelang <level>` sets one dial that controls all of the skill's automatic compression. It
persists in `~/.claude/settings.json` under `"tokelang.level"`.

## Trigger

- `/tokelang off` — loaded but inert (no compression, no style nudge)
- `/tokelang lite` — **default.** Gentle: compresses subagent briefs + web tool results at a
  conservative (high-recall) depth, and nudges the model to answer concisely
- `/tokelang full` — aggressive: deeper compression + a terser output style
- `/tokelang` (no argument) — show the current level and what's on
- Natural language: "turn tokelang down/off", "be more aggressive" → map to the nearest level

## Process

1. Parse the argument to one of `off` / `lite` / `full` (case-insensitive). Anything else → print usage.
2. Read `~/.claude/settings.json`, set `"tokelang.level"` to that value, save.
3. Confirm, e.g.:
   ```
   Tokelang: lite → full.
     Subagent briefs:   compressed (default mode)
     Web tool results:  compressed (default mode)
     Output style:      terse
   ```
   The hooks read this on their next fire — no restart needed.

## What each level does

| Surface (all automatic) | off | lite (default) | full |
|---|---|---|---|
| Subagent briefs (Task prompts) | — | compressed | compressed |
| WebFetch / WebSearch results | — | compressed (conservative) | compressed (deeper) |
| Output style nudge | — | "be concise" | terse / fragments OK |

Read/Edit/Bash/Grep tool results are **never** touched (code, logs, and data are correctness-critical).
The skill does **not** compress the prompts you type — Claude Code's hooks can't rewrite user input.

## Why compress

Compressed prompts save tokens **and** help the model reason: Hakim 2026
([arXiv:2604.00025](https://arxiv.org/abs/2604.00025)) found brevity constraints improve accuracy by
up to 26 points. The verbose English around a request is a parsing tax; stripping it helps.

## Validator — nothing important gets dropped

Every fold passes a semantic validator before it replaces the original: content-recall floor plus hard
zones that are never rewritten — negations (`not`, `never`, `only`), numbers/thresholds, code blocks,
URLs, file paths, regex, quoted strings, contract vocabulary (`shall`, `must`). If a candidate fails,
the **original passes through unchanged**. Tokelang never compresses past what the model can still use.

## Related commands

| Command | What it does |
|---|---|
| `/tokelang-stats` | Session savings: tokens saved, % reduction, ~$ |
| `/tokelang-router …` | Optional cheap-router / expensive-worker cost routing (off by default) |
| `/tokelang-telemetry on\|off` | Opt-in aggregate metrics (off by default; never content) |

Uninstall: `rm -rf ~/.claude/skills/tokelang`. Engine runs locally; no telemetry unless you opt in.
