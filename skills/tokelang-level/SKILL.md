---
name: tokelang-level
description: >
  Change Tokelang's compression aggressiveness. L1 = output style guide only. L2 = + Task
  subagent prompt compression (default on install). L3 = + aggressive output style.
  "off" = skill loaded but inert. Setting persists in ~/.claude/settings.json.
  For user-input compression (every prompt you type), use the separate `tokelang-cli wrap`
  command — see README. Trigger: /tokelang-level [1|2|3|off]
---

# Change compression level

Switch between four preset compression levels. Setting persists across sessions in `~/.claude/settings.json` under `"tokelang.level"`.

## Trigger

- `/tokelang-level [1|2|3|off]` — explicit
- `/tokelang-level` (no arg) — show current level + describe each
- "turn tokelang down" / "be less aggressive" — natural language (interpret as one step down)
- "disable tokelang" / "turn it off" — natural language → set to off

## Level matrix (revised 2026-06-01 for Option B)

| Level | Context files (slash cmd) | Subagent inputs (Task tool) | Output style guide |
|---|---|---|---|
| **L1** Safe | via `/tokelang-compress` | **off** | "lite" — be concise |
| **L2** Balanced (default install) | via `/tokelang-compress` | **on**, lite depth | "lite" — be concise |
| **L3** Aggressive | via `/tokelang-compress` | **on**, medium depth | "medium" — fragments OK, drop articles |
| **off** | via `/tokelang-compress` | **off** | **off** (no style guide injection) |

Note: `/tokelang-compress` works at every level (it's user-initiated). Level only controls the *automatic* hooks (SessionStart style guide + PreToolUse Task compression).

**For real user-input compression**, you need `tokelang-cli wrap claude` as an alias. This is outside the skill's level dial. See README "Wrap mode" section.

## Process

1. Parse argument. Accept `1`, `2`, `3`, `off` (case-insensitive). Other input → print usage.
2. Read `~/.claude/settings.json`. If `"tokelang"` block missing, create it.
3. Set `"tokelang.level"`. Save settings.
4. Confirm:
   ```
   Tokelang level changed: 2 (Balanced) → 1 (Safe).
   Subagent compression: OFF
   Output style guide: lite (be concise)
   Context-file compression: still available via /tokelang-compress
   ```
5. Hook scripts read this setting on every fire — change takes effect on the next Task invocation. No restart needed.

## Custom level (advanced)

`~/.claude/settings.json` supports per-dial overrides via a `tokelang.custom` object. Example:

```json
{
  "tokelang.level": "custom",
  "tokelang.custom": {
    "subagent_input": true,
    "subagent_input.depth": "medium",
    "output_style": "lite"
  }
}
```

When `"tokelang.level": "custom"`, the dials in `custom` are used directly.

## Off semantics

`"tokelang.level": "off"` keeps the skill loaded (slash commands still work, statusline still shows lifetime stats) but the hooks become no-ops. No subagent compression, no style-guide injection. Use this for sessions where you want Tokelang fully dormant without uninstalling.

To uninstall completely: `claude plugin uninstall tokelang`.

## Example

```
> /tokelang-level

Current: 2 (Balanced)
  Subagent compression:   ON (lite depth)
  Output style guide:     lite (be concise)

Levels:
  1 / Safe       — output style only; subagent compression off
  2 / Balanced   — + subagent compression (DEFAULT)
  3 / Aggressive — + medium-depth subagent + aggressive output style
  off            — skill loaded but inert; hooks are no-ops

For input compression (every prompt you type):
  alias claude='tokelang-cli wrap claude'

Switch with: /tokelang-level <1|2|3|off|custom>
```
