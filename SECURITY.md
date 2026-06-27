# Security Policy

## Reporting a vulnerability

**Do not file security issues as public GitHub issues.**

Use one of:

1. **GitHub Security Advisory** — go to the [Security tab](https://github.com/tokelang/claude-code-skill/security) of this repo and click "Report a vulnerability." Private disclosure flow built into GitHub.
2. **Email** — security@tokelang.com (placeholder; update before launch). Encrypt with PGP if you have it: [pgp key TBD].

Either channel reaches the maintainers privately.

## What we consider in-scope

- Hook scripts that mishandle user input or shell-inject
- Compression behavior that exfiltrates or transforms sensitive content unexpectedly
- Privilege escalation via the plugin install path
- Any way for a malicious context file to compromise Claude Code's host environment
- Issues with the bundled `tokelang-cli` binary that affect security

## Out of scope (please don't report)

- Token-saving accuracy variance (this is a feature, not a security issue)
- "Tokelang compresses my prompts and I don't like that" — that's `/tokelang-level off`, not a vulnerability
- Issues in dependencies that don't have a clear exploit path through this skill

## Response timeline

| Phase | Target |
|---|---|
| Acknowledge receipt | 72 hours |
| Initial triage | 7 days |
| Fix in flight | 30 days for critical / 90 days for high / 180 days for medium |
| Public disclosure | After fix ships + we coordinate timing with you |

## Disclosure credit

If you report a valid issue, we'll credit you in the security advisory and release notes (or keep you anonymous if you prefer).

## Supported versions

Only the latest v1.x.y minor release receives security fixes. Older minor versions are not back-patched.

## Bounty

No paid bounty program at this point. We may add one once revenue + headcount allow.
