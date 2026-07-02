---
name: tokelang-router
description: >
  Configure the cheap-router / expensive-worker cost-routing profile: turn it on/off, set which
  model and effort the cheap router (the seat you talk to) and the expensive worker subagent use,
  and cap worker spend. Knobs persist in ~/.claude/.tokelang-router.json and are applied to the
  agent files + settings.json deterministically by apply.sh.
---

# /tokelang-router — configure the cost-routing profile

When invoked, translate the user's request into **exactly one** call to the applier script, run it,
and show its output verbatim (it prints the resulting state). Do not edit settings.json or the agent
files yourself — the script does it deterministically.

Applier: `bash "${CLAUDE_PLUGIN_ROOT}/skills/tokelang-router/apply.sh" <subcommand>`

## Map the request → subcommand

| User says (examples) | Run |
|---|---|
| "status", "show config", no args | `status` |
| "on", "enable", "turn it on" | `enable` |
| "off", "disable", "stop routing" | `disable` |
| "router model sonnet", "use sonnet for the router" | `set router-model sonnet` |
| "router effort high / medium / low", "router at high effort" | `set router-effort <e>` |
| "worker model opus / sonnet / haiku" | `set worker-model <m>` |
| "worker effort max / high / medium / low" | `set worker-effort <e>` |
| "cap the worker at 10 turns", "limit worker spend" | `set worker-max-turns 10` |
| "dynamic routing", "pick worker model per task", "RouteLLM" | `set routing dynamic` |
| "fixed routing", "always use the same worker model" | `set routing fixed` |
| "preset balanced / max-savings / quality" | `preset <name>` |

Valid models: `haiku sonnet opus fable inherit`. Valid effort: `low medium high max`.

## Presets (one call sets both seats)
- **max-savings** — router=haiku/medium, worker=opus/high. Cheapest orchestration, full-power worker.
- **balanced** — router=sonnet/medium, worker=opus/high. Safer routing.
- **quality** — router=sonnet/high, worker=opus/max. Safest routing + max worker effort.

## Routing mode (fixed vs dynamic)
- **fixed** (default) — the worker always runs on `worker-model`. Predictable cost.
- **dynamic** — the router picks the worker model per task (routine→sonnet, hard→opus; trivial it
  handles itself). Bigger savings, but routing quality matters — validate in dogfood before trusting
  it on hard work. Takes effect on the **next worker spawn** (no relaunch).

## Per-turn override (no config needed — tell the user this exists)
- Prefix a message with **`!worker`** to force-delegate that turn to the worker, or **`!direct`** to
  make the cheap router handle it itself. Overrides the router's routing call for that one turn.

## Tell the user (after applying)
- **Router model/effort** changes take effect **next session** (a session's agent model + effort are
  fixed at launch). To use them now, relaunch: `claude --agent tokelang-router`. Default is
  **haiku / medium**.
- **Worker** model/effort/max-turns take effect on the **next worker spawn** — no relaunch needed.
- `enable` writes `"agent":"tokelang-router"` to settings.json (on for every session in projects that
  read it). `disable` removes it (and only it — a user's own custom `agent` is left untouched).

## Notes
- There is **no context-window knob** — the model fixes the window (200K). The real cost levers are
  `worker-max-turns` (caps the worker loop) and the router's curation discipline (keep briefs small).
- Keep `tokelang` at `lite` or `full` (not `off`) so router→worker briefs get compressed by the Task hook.
