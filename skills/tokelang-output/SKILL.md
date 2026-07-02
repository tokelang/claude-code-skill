---
name: tokelang-output
description: >
  The Tokelang output-compression dial. `/tokelang-output off|lite|full` sets how aggressively the
  skill shrinks what flows through the model: WebFetch/WebSearch tool results, subagent briefs, and
  the model's own verbosity — each guarded by a semantic validator that refuses any fold that would
  drop meaning. Default is `lite`. `/tokelang-output` with no argument shows the current level. Apache 2.0.
---

# /tokelang-output — the output-compression dial

`/tokelang-output <level>` sets one dial for all of the skill's automatic compression. It persists in
`~/.claude/settings.json` under `"tokelang.level"`.

## Trigger

- `/tokelang-output off` — loaded but inert (no compression, no style nudge)
- `/tokelang-output lite` — **default.** Gentle: folds web tool results + subagent briefs at a
  conservative (high-recall) depth, and nudges the model to answer concisely
- `/tokelang-output full` — aggressive: deeper compression + a terser output style
- `/tokelang-output` (no argument) — show the current level and what's on
- Natural language: "turn tokelang down/off", "compress output harder" → map to the nearest level

## Process

1. Parse the argument to one of `off` / `lite` / `full` (case-insensitive). Anything else → print usage.
2. Read `~/.claude/settings.json`, set `"tokelang.level"` to that value, save.
3. Confirm, e.g.:
   ```
   Tokelang output: lite → full.
     Web tool results:  compressed (default mode)
     Subagent briefs:   compressed (default mode)
     Output style:      terse
   ```
   The hooks read this on their next fire — no restart needed.

## What each level does

| Surface (all automatic) | off | lite (default) | full |
|---|---|---|---|
| WebFetch / WebSearch results | — | compressed (conservative) | compressed (deeper) |
| Output style nudge | — | "be concise" | terse / fragments OK |
| Subagent briefs (Task prompts) | — | compressed | compressed |

Read/Edit/Bash/Grep tool results are **never** touched (code, logs, and data are correctness-critical).
The skill does **not** compress the prompts you type — Claude Code's hooks can't rewrite user input.

## Why compress

Compressed context saves tokens **and** helps the model reason: Hakim 2026
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
