# Tokelang for Claude Code

> Compressed prompts make models think better. Not our claim — [arXiv:2604.00025](https://arxiv.org/abs/2604.00025).

[![License](https://img.shields.io/badge/license-Apache_2.0-blue.svg)](LICENSE)

Tokelang compresses tokens in your Claude Code session via a semantic validator that refuses any compression that drops meaning. Engine runs locally — your data never leaves your machine.

## What it does

The skill compresses tokens at the surfaces Claude Code's plugin hooks can actually reach:

- **Subagent invocations** (PreToolUse hook) — Task-tool prompt bodies.
- **Tool results** (PostToolUse hook) — WebFetch / WebSearch output folded before it enters context. Code, diffs, and command output are never touched.
- **Output style** (SessionStart hook) — nudges the model to answer briefly.

All three are controlled by one dial: **`/tokelang off｜lite｜full`** (default `lite`). It also ships an optional **cost router** (cheap-router / expensive-worker) — see below.

> Compressing **every prompt you type** needs a proxy in front of the API, which a plugin hook can't do (hooks can't rewrite your raw input). That lives in a separate product, not this skill.

## Install

```bash
npx @tokelang-lite/claude-code-skill
```

Installs to `~/.claude/skills/tokelang/` — downloads the matching engine binary and verifies its SHA-256. That's it: start a new Claude Code session and the skill is active at **`lite`** (subagent + tool-result compression at a conservative depth + a concise output-style nudge). Slash commands available.

## What runs where

```
              ── SessionStart hook: output style guide injected ("respond concisely")
              ── PreToolUse hook (Task): subagent prompt compressed before the subagent sees it
              ── PostToolUse hook (WebFetch/WebSearch): tool result folded before it enters context
              │
              ▼
Model responds:  brief, focused answer (because the style guide nudged it)
              │
              ▼
You see:     model's response

(meanwhile the statusline shows a running savings counter)
```

## How to turn it down or off

| Want | Action |
|---|---|
| Loaded but doing nothing | `/tokelang off` |
| Gentle (default) | `/tokelang lite` |
| More aggressive | `/tokelang full` |
| Usage metrics (opt-in) | `/tokelang-telemetry on` / `off` — **off by default**; aggregate counts only, never content |
| Uninstall skill | `rm -rf ~/.claude/skills/tokelang` |

Skill settings persist in `~/.claude/settings.json` under `"tokelang.level"`.

## Cost router (optional, off by default)

The skill also ships a **cheap-router / expensive-worker** pair of agents. A Haiku router holds your
conversation cheaply and delegates the real reasoning to an Opus worker that only ever sees a
curated, compressed brief — so the expensive model isn't re-reading your whole growing history every
turn. Trivial turns the router handles inline; it never spawns the worker for them.

```bash
/tokelang-router on          # enable (takes effect next session, or: claude --agent tokelang-router)
/tokelang-router off         # back to normal
/tokelang-router status      # show current config
/tokelang-router preset balanced   # max-savings | balanced | quality
```

Per-turn overrides while on: prefix a message with `!worker` to force delegation, or `!direct` to
force the cheap router to answer itself.

**When it pays off:** bigger, agentic tasks. In dogfood measurement it won every profile tested at
equal accuracy — medium build −46%, large-context change −60%, long multi-feature build −48% — by
cutting the Opus-seat tokens 48–72%. On trivial one-shot prompts it roughly breaks even, so it's built
to down-route those and it's off by default. Turn it on when your task is bigger than a quick edit.

Ships with `routing: fixed` (Opus worker). Dynamic worker-model routing (`/tokelang-router routing
dynamic`) is **experimental** — its mis-routing rate isn't measured yet, so leave it fixed for now.

## Why brevity helps the model

Hakim 2026 found that constraining large models to brief responses **improves accuracy by 26 percentage points** on hard reasoning benchmarks — and **reverses performance hierarchies** between small and large models. The mechanism: verbose generation introduces overelaboration errors. Strip the verbosity, the reasoning improves.

Tokelang is the productionized version of that finding. We compress the context, subagent prompts, and tool results the model has to read so it isn't burning attention on verbose English, and we nudge it (via style-guide injection) to respond briefly so it doesn't overelaborate.

## What gets compressed vs preserved

**Compressed** (when validator passes): articles (`a`, `the`), filler (`just`, `really`), pleasantries (`sure`, `of course`), hedging (`maybe`, `it might be worth`), prose connectives (`however`, `furthermore`), redundant phrasing (`in order to` → `to`).

**Always preserved exactly** (hard zones): negations (`not`, `never`, `only`), numbers and thresholds (`$5000`, `0.85`, `500ms`), code blocks (fenced + indented), URLs, file paths, command literals, regex literals (`\d{4}`), template placeholders (`{VAR}`), quoted strings, contract vocabulary (`shall`, `must`, `required`, `strictly`).

## Vs. Caveman and others

| | Tokelang skill | Caveman | LLMLingua / SynthLang |
|---|---|---|---|
| Engine runs locally | ✅ | ❌ (Claude API call per file) | ✅ |
| Semantic validator | ✅ (0.85 / 0.90 recall floor + protected spans) | ❌ (structural only) | ❌ |
| Subagent-input compression | ✅ (PreToolUse hook) | ❌ | ❌ |
| Tool-result compression | ✅ (PostToolUse hook) | ❌ | ❌ |
| Context-file compression | ✅ | ✅ | partial |
| Output style guide | ✅ | ✅ | ❌ |
| Cost router (cheap-router / expensive-worker) | ✅ | ❌ | ❌ |
| Open source license | Apache 2.0 (patent grant) | MIT | varies |
| Patent-backed IP | ✅ (IP India 2025-10-06) | — | — |

The differentiator that matters: **the semantic validator** — every fold is checked for meaning-recall and protected spans before it's applied, so a compression that would drop a negation, number, or code span is rejected and the original passes through unchanged.

## Privacy

- The engine runs locally — no network calls during compression (the binary is downloaded once at install, then never phones home)
- Telemetry is **opt-in and off by default.** Turn it on/off with `/tokelang-telemetry on|off` (state in `~/.claude/.tokelang-telemetry.json`). When on, the Stop hook sends one aggregate ping per session: schema/CLI version, level, coarse OS/arch, this session's `tokens_saved` + event count, lifetime totals, and a locally-generated random `anon_id`. **Never** prompt text, responses, file paths, or session ids — the metrics are built from a sidecar that only stores `surface,orig,comp,timestamp` per event, so there is no content in it to send.
- Hosted API at tokelang.com is a *separate product* used by the dashboard

## License

Apache 2.0 with explicit patent grant. See [LICENSE](LICENSE).

Code is yours to use, modify, fork, and ship in commercial products. The name **Tokelang™** and the logo are reserved — see [TRADEMARKS.md](TRADEMARKS.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). DCO sign-off required (`git commit -s`).

## Status

v1.0.0 is the first OSS release (planned 2026-Q3). Companion projects:

- [`tokelang-core`](https://github.com/tokelang/tokelang-core) — the Rust engine crate
- [`vscode-extension`](https://github.com/tokelang/vscode-extension) — for Cursor / Windsurf / Copilot / Cline users

Hosted dashboard + paid API at [tokelang.com](https://tokelang.com).
