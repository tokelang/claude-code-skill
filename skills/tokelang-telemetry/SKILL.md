---
name: tokelang-telemetry
description: >
  Turn Tokelang's opt-in usage metrics on or off. OFF by default. When ON, only AGGREGATE
  token-savings counts are sent (per session) — never prompt content, file paths, or session
  ids. Toggling writes ~/.claude/.tokelang-telemetry.json. Trigger: /tokelang-telemetry [on|off]
---

# Telemetry (opt-in, off by default)

Tokelang sends **nothing** unless you explicitly turn this on. When on, the Stop hook sends one
small aggregate ping per session so the project can see real-world savings in the aggregate.

## What is / isn't sent

**Sent (aggregate only):** schema version, CLI version, level, coarse OS/arch, this session's
`tokens_saved` + event count, and lifetime `tokens_saved` + session count, plus a random
`anon_id` (generated locally at opt-in, for de-duplicating installs).

**Never sent:** prompt text, responses, file paths, file names, session ids, repo info, or
anything derived from your content. The session sidecar the ping is built from only ever stores
`surface,orig_tokens,comp_tokens,timestamp` per event — there is no content in it to leak.

Endpoint: `https://tokelang.com/v1/telemetry` (override with `TOKELANG_TELEMETRY_ENDPOINT`).
The ping is best-effort: it needs `curl`, is capped at 3s, and is fired detached so it can
never block or fail your session.

## Trigger

- `/tokelang-telemetry on` — opt in
- `/tokelang-telemetry off` — opt out (the default state)
- `/tokelang-telemetry` (no arg) — show current status and exactly what would be sent

## Process

Parse the argument (case-insensitive). The state lives in `~/.claude/.tokelang-telemetry.json`.

### on
Run this (preserves an existing `anon_id`, otherwise generates a fresh random one):

```bash
F="${HOME}/.claude/.tokelang-telemetry.json"
AID="$(jq -r '.anon_id // empty' "$F" 2>/dev/null)"
[ -z "$AID" ] && AID="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || python3 -c 'import uuid;print(uuid.uuid4())' 2>/dev/null || echo "anon-$(date +%s)-$RANDOM")"
mkdir -p "${HOME}/.claude"
jq -n --arg aid "$AID" '{enabled:true, anon_id:$aid}' > "$F"
echo "Telemetry ON. Aggregate token-savings metrics only — never prompt content. anon_id=$AID"
```

### off
Run this (keeps the file but disables it, so the same `anon_id` is reused if you later re-enable):

```bash
F="${HOME}/.claude/.tokelang-telemetry.json"
AID="$(jq -r '.anon_id // empty' "$F" 2>/dev/null)"
mkdir -p "${HOME}/.claude"
jq -n --arg aid "$AID" '{enabled:false} + (if $aid=="" then {} else {anon_id:$aid} end)' > "$F"
echo "Telemetry OFF. Nothing will be sent."
```

(Equivalent: just delete `~/.claude/.tokelang-telemetry.json`.)

### status (no arg)
Read the file and report:

```bash
F="${HOME}/.claude/.tokelang-telemetry.json"
if [ -f "$F" ] && [ "$(jq -r '.enabled // false' "$F" 2>/dev/null)" = "true" ]; then
  echo "Telemetry: ON  (anon_id=$(jq -r '.anon_id // "?"' "$F"))"
else
  echo "Telemetry: OFF (default)"
fi
```

Then summarize the "What is / isn't sent" section above so the user can decide.

## Notes

- This is independent of `tokelang.level`. Turning the skill off (`/tokelang off`) does not
  change telemetry; telemetry is governed solely by this file.
- No metrics are sent for sessions with zero compression events (the Stop hook exits early when
  there is no sidecar).
