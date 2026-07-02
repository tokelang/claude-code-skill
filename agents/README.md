# Tokelang router profile (cheap-router / expensive-worker)

> **Status: experimental, pending dogfood validation.** Not yet advertised in the main skill README.
> This is a **cost-routing** feature (RouteLLM-adjacent), distinct from Tokelang's prompt-compression.

Two agents ship here:

- **`tokelang-router`** (Haiku, medium effort) — the cheap seat you talk to. Holds the full
  conversation, curates the minimal context, delegates real work to the worker, relays the result.
- **`tokelang-worker`** (Opus, high effort) — the expensive seat. Sees only a small fresh brief,
  does the reasoning/coding, returns a terse result. Cannot talk to the user.

The expensive model never sits in the main loop re-reading verbose history every turn — that's the
saving. Opus tokens ≈ 10–15× Haiku.

## Turn it ON

Per session:
```
claude --agent tokelang-router
```

Per project (default for every session in this repo) — add to `.claude/settings.json`:
```json
{ "agent": "tokelang-router" }
```

## Turn it OFF

Launch `claude` normally (no `--agent`), or remove the `"agent"` key from settings.json.

The `tokelang.level` setting independently controls the deterministic Task-prompt compression hook
(`pre-tool-use.sh`); keep it at `2` so router→worker briefs get folded for free.

## Configure (`/tokelang-router`)

The `/tokelang-router` skill is the knob surface. It persists to `~/.claude/.tokelang-router.json`
and applies changes deterministically (`skills/tokelang-router/apply.sh`):

| Want | Command |
|---|---|
| See current config | `/tokelang-router status` |
| On / off | `/tokelang-router on` · `/tokelang-router off` |
| Router seat model | `/tokelang-router router-model sonnet` |
| Worker seat model | `/tokelang-router worker-model opus` |
| Worker effort | `/tokelang-router worker-effort max` |
| Cap worker spend | `/tokelang-router worker-max-turns 10` |
| Routing: fixed vs per-task | `/tokelang-router routing dynamic` (or `fixed`) |
| One-shot presets | `/tokelang-router preset max-savings\|balanced\|quality` |

Router-model changes apply **next session**; worker model/effort/max-turns/routing apply on the
**next spawn**. There is no context-window knob (the model fixes it at 200K) — `worker-max-turns` +
brief curation are the real cost levers.

**Routing modes:** `fixed` (default) = worker always on `worker-model`. `dynamic` = router picks the
worker model per task (routine→sonnet, hard→opus, trivial→handled by the router itself) for bigger
savings — validate quality in dogfood before trusting it on hard work.

**Per-turn override (no config):** start a message with `!worker` to force-delegate that turn, or
`!direct` to make the cheap router handle it itself — overrides the router's call for that one turn.

## When it helps / when it hurts

- **Helps:** long agentic sessions ("go build / fix / investigate X"). The longer the session, the
  more a plain-Opus session pays to re-read history every turn, and the more this saves.
- **Hurts:** short one-off tasks and highly interactive chat. Every worker spawn pays two fixed Opus
  taxes — the full CLAUDE.md + MEMORY.md reload, and the double-pass (router → worker → relay). On a
  short task those taxes can exceed the saving.

## Two worker modes (router picks per task)

- **Fresh spawn** (default) — independent / one-shot tasks. Max isolation; reloads project context
  each spawn.
- **Resume** (`SendMessage`) — iterative work where turn N builds on N-1. Keeps worker context so the
  router doesn't re-supply state; pays the CLAUDE.md tax once. Context regrows over a long thread.

Next-session dogfood A/Bs these two against a plain-Opus baseline (see `I2_ROUTER_BUILD_PLAN.md` §5).

## Files
- `tokelang-router.md`, `tokelang-worker.md` — canonical here (ship with the plugin).
- Symlinked into the workspace `.claude/agents/` so `--agent` resolves them for dogfood with no drift.
