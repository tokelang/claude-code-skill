# Contributing to Tokelang (Claude Code skill)

Thanks for your interest. This skill is part of the broader Tokelang project — a token-efficient compression middleware for LLM workflows.

## What can be contributed

- Bug reports — anything that breaks or behaves unexpectedly
- Documentation improvements — clearer install instructions, better examples
- Hook improvements — bug fixes, performance fixes, edge-case handling
- Sub-skill additions — new slash commands that don't conflict with the existing five
- Testing on platforms we don't have — Windows + various WSL flavors especially

## What stays out of scope (for this repo)

These are intentionally out of scope here because they live elsewhere:

- **Engine changes** — those belong in [`tokelang-core`](https://github.com/tokelang/tokelang-core).
- **CLI changes** — those belong in [`tokelang-cli`](https://github.com/tokelang/tokelang-cli).
- **VS Code extension** — that's [`vscode-extension`](https://github.com/tokelang/vscode-extension).

If you're unsure where something belongs, open an issue here and we'll redirect.

## How to file a bug report

Include:

1. Claude Code version (`claude --version`)
2. Tokelang version (`claude plugin list`)
3. Operating system + architecture
4. Steps to reproduce
5. Expected vs. actual behavior
6. If relevant: a minimal context file or prompt that triggers the bug

For security issues: see [SECURITY.md](SECURITY.md). **Do not file security issues as public GitHub issues.**

## Pull request process

1. Open an issue first to discuss the change. Saves you and us time on rejected PRs.
2. Fork, branch, code.
3. Add or update tests. Hooks are bash scripts — test on Linux + macOS at minimum.
4. Sign your commits with the DCO (`git commit -s`). See "Developer Certificate of Origin" below.
5. Open the PR. Link the original issue. Explain what changed and why.
6. CI must be green.

## DCO sign-off (instead of CLA)

We don't require a Contributor License Agreement. Instead we ask for a Developer Certificate of Origin sign-off — a single line in each commit certifying you have the right to contribute the change.

Add the sign-off automatically with `git commit -s`. It appends:

```
Signed-off-by: Your Name <your@email>
```

By signing, you certify that you wrote the contribution OR have the right to submit it under the same Apache 2.0 license. Full DCO text: https://developercertificate.org/.

## Code style

- Bash scripts: shellcheck-clean (`shellcheck hooks/*.sh statusline/*.sh`). No shellcheck-disable lines unless explicitly justified in a comment.
- SKILL.md files: keep the frontmatter `description` under 500 characters.
- Markdown: standard CommonMark; no HTML unless absolutely necessary.

## Naming the slash command for a new sub-skill

All sub-skills are prefixed `tokelang-*`. Pick a verb-first short name (`tokelang-foo`, not `tokelang-do-foo`). Avoid acronyms.

## License

By contributing, you agree your contribution is licensed under Apache 2.0 (the project license) — see [LICENSE](LICENSE). The DCO sign-off makes this explicit on a per-commit basis.

## Maintainer expectations

We aim to respond to issues within 7 days and review PRs within 14 days. We are not always fast; bear with us.
