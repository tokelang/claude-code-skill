# Tokelang for Claude Code

> Compressed prompts make models think better. Not our claim — [arXiv:2604.00025](https://arxiv.org/abs/2604.00025).

[![License](https://img.shields.io/badge/license-Apache_2.0-blue.svg)](LICENSE)

Tokelang compresses tokens in your Claude Code session via a semantic validator that refuses any compression that drops meaning. Engine runs locally — your data never leaves your machine.

## Two parts, two install paths

| Part | Install | What it does |
|---|---|---|
| **Claude Code skill** | `claude plugin install tokelang` | Compresses your context files (slash command), your subagent invocations (Task tool prompts), and injects an output style guide so the model responds briefly. |
| **`tokelang-cli wrap` alias** | `alias claude='tokelang-cli wrap claude'` | Compresses **every prompt you type** before it reaches Claude Code. The only way to get true input compression — Claude Code's plugin hooks are additive only and can't rewrite user input. |

You can install just the skill (lighter touch) or skill + wrap alias (full compression). Both share the same local engine. **Most users want both.**

## Install — skill only

```bash
claude plugin marketplace add tokelang/claude-code-skill
claude plugin install tokelang
```

That's it. Start a new Claude Code session and the skill is active at Level 2 (Balanced — subagent input compression + lite output style guide). Slash commands available.

## Install — skill + wrap mode (recommended for full compression)

```bash
# 1. Install the skill (as above)
claude plugin marketplace add tokelang/claude-code-skill
claude plugin install tokelang

# 2. Install the standalone CLI binary
brew install tokelang/tap/tokelang-cli         # macOS
# OR
curl -fsSL https://tokelang.com/install.sh | bash   # Linux/macOS

# 3. Add the wrap alias to your shell config (~/.bashrc, ~/.zshrc):
alias claude='tokelang-cli wrap claude'

# 4. (Optional) wrap other CLIs too:
alias codex='tokelang-cli wrap codex'
alias gemini='tokelang-cli wrap gemini'
```

Now every prompt you type to claude/codex/gemini gets compressed first.

## What runs where

```
You type:    "explain database connection pooling in detail please"
              │
              ▼
tokelang-cli wrap (intercepts stdin)
              │
              ▼
Engine compresses to: "explain DB conn pooling detailed"
              │
              ▼
              claude (sees compressed version)
              │
              ▼
              ── SessionStart hook fires (skill)
              ── Style guide injected: "respond concisely"
              ── PreToolUse hook fires on Task tool (skill compresses subagent prompts)
              │
              ▼
Model responds:  brief, focused answer (because style guide nudged it)
              │
              ▼
You see:     model's response

(meanwhile statusline shows running savings counter)
```

## How to turn it down or off

| Want | Action |
|---|---|
| Skill less aggressive (no subagent compression) | `/tokelang-level 1` |
| Skill loaded but doing nothing | `/tokelang-level off` |
| Skill more aggressive | `/tokelang-level 3` |
| Wrap mode disabled | `unalias claude` or comment out the alias line |
| Usage metrics (opt-in) | `/tokelang-telemetry on` / `off` — **off by default**; aggregate counts only, never content |
| Uninstall skill | `claude plugin uninstall tokelang` |
| Uninstall CLI | `brew uninstall tokelang-cli` or delete the binary |

Skill settings persist in `~/.claude/settings.json` under `"tokelang.level"`.

## Why brevity helps the model

Hakim 2026 found that constraining large models to brief responses **improves accuracy by 26 percentage points** on hard reasoning benchmarks — and **reverses performance hierarchies** between small and large models. The mechanism: verbose generation introduces overelaboration errors. Strip the verbosity, the reasoning improves.

Tokelang is the productionized version of that finding. We compress your input (via wrap mode) so the model isn't burning attention parsing verbose English, and we nudge it (via style guide injection) to respond briefly so it doesn't overelaborate.

## What gets compressed vs preserved

**Compressed** (when validator passes): articles (`a`, `the`), filler (`just`, `really`), pleasantries (`sure`, `of course`), hedging (`maybe`, `it might be worth`), prose connectives (`however`, `furthermore`), redundant phrasing (`in order to` → `to`).

**Always preserved exactly** (hard zones): negations (`not`, `never`, `only`), numbers and thresholds (`$5000`, `0.85`, `500ms`), code blocks (fenced + indented), URLs, file paths, command literals, regex literals (`\d{4}`), template placeholders (`{VAR}`), quoted strings, contract vocabulary (`shall`, `must`, `required`, `strictly`).

## Vs. Caveman and others

| | Tokelang (skill + wrap) | Caveman | LLMLingua / SynthLang |
|---|---|---|---|
| Engine runs locally | ✅ | ❌ (Claude API call per file) | ✅ |
| Semantic validator | ✅ (0.85 / 0.90 recall floor + protected spans) | ❌ (structural only) | ❌ |
| User-input compression | ✅ (wrap mode) | ❌ | ✅ (proxy) |
| Subagent-input compression | ✅ (PreToolUse hook) | ❌ | ❌ |
| Context-file compression | ✅ | ✅ | partial |
| Output style guide | ✅ | ✅ | ❌ |
| Cross-CLI (Codex, Gemini, Aider) | ✅ (wrap works for all) | ❌ Claude Code only | varies |
| Open source license | Apache 2.0 (patent grant) | MIT | varies |
| Patent-backed IP | ✅ (IP India 2025-10-06) | — | — |

The differentiator that matters: **the validator + the dual-frontend architecture**. The skill gives you what plugin hooks make possible; the wrap mode gives you what they don't.

## Privacy

- Engine bundled is local-only — no network calls during compression
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
- [`tokelang-cli`](https://github.com/tokelang/tokelang-cli) — the standalone binary + wrap mode
- [`vscode-extension`](https://github.com/tokelang/vscode-extension) — for Cursor / Windsurf / Copilot / Cline users

Hosted dashboard + paid API at [tokelang.com](https://tokelang.com).
