#!/usr/bin/env bash
# Tokelang Stop hook
# Fires when the session ends or pauses.
# Responsibilities:
#   1. Read this session's sidecar (compression events logged during the session)
#   2. Aggregate token savings
#   3. Update ~/.claude/.tokelang-lifetime.json with cumulative totals
#   4. Write the statusline suffix file so next session's statusline shows updated number
#
# Reads stdin JSON: { session_id, transcript_path, ... }
# No stdout required.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(readlink -f "$0")")")}"
LIFETIME_FILE="${HOME}/.claude/.tokelang-lifetime.json"
STATUSLINE_SUFFIX="${HOME}/.claude/.tokelang-statusline-suffix"
CLI_BIN="${PLUGIN_ROOT}/bin/tokelang-cli-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"

STDIN_JSON="$(cat)"
SESSION_ID="$(echo "${STDIN_JSON}" | jq -r '.session_id // "unknown"')"
SESSION_SIDECAR="${HOME}/.claude/.tokelang-session-${SESSION_ID}"

[[ ! -f "${SESSION_SIDECAR}" ]] && exit 0  # nothing to aggregate

# Aggregate this session's savings via the CLI — the single source of truth for the sidecar
# schema. Each sidecar line is "surface,orig_tokens,comp_tokens,unix_ts" (written by the hooks);
# `tokelang-cli stats` sums (orig - comp) across all rows and emits JSON. Fall back to {} if the
# CLI or jq is unavailable so the Stop hook never fails the session.
STATS_JSON="$("${CLI_BIN}" stats --transcript "${SESSION_SIDECAR}" 2>/dev/null || echo '{}')"
TOTAL_SAVED="$(echo "${STATS_JSON}" | jq -r '.tokens_saved // 0' 2>/dev/null || echo 0)"
TOTAL_SAVED="${TOTAL_SAVED:-0}"

# Read or initialize lifetime
if [[ -f "${LIFETIME_FILE}" ]]; then
  LIFETIME_TOKENS=$(jq -r '.lifetime_tokens_saved // 0' "${LIFETIME_FILE}")
  LIFETIME_SESSIONS=$(jq -r '.sessions_count // 0' "${LIFETIME_FILE}")
else
  LIFETIME_TOKENS=0
  LIFETIME_SESSIONS=0
fi

NEW_LIFETIME=$((LIFETIME_TOKENS + TOTAL_SAVED))
NEW_SESSIONS=$((LIFETIME_SESSIONS + 1))

# Update lifetime file
jq -n --argjson t "${NEW_LIFETIME}" --argjson s "${NEW_SESSIONS}" \
  '{lifetime_tokens_saved: $t, sessions_count: $s, last_updated: now | todateiso8601}' \
  > "${LIFETIME_FILE}"

# Update statusline suffix — short form, fits in statusline
# Rough $ estimate at Sonnet 4.6 input rate ($3/MTok): tokens * 3 / 1_000_000
USD=$(awk -v t="${NEW_LIFETIME}" 'BEGIN {printf "%.2f", t * 3 / 1000000}')
echo "tokelang: ${NEW_LIFETIME} tok saved (~\$${USD})" > "${STATUSLINE_SUFFIX}"

# --- Opt-in telemetry (OFF by default) -------------------------------------------------
# Sends AGGREGATE token-savings counts only — NEVER prompt content. (The sidecar itself
# stores only "surface,orig,comp,ts" per line, so there is literally no content to leak.)
# Fires ONLY when ~/.claude/.tokelang-telemetry.json says {"enabled": true}; absent file =
# off. Toggle with the /tokelang-telemetry skill. Best-effort: needs curl, hard-bounded to
# 3s, detached and fire-and-forget so it can neither block nor fail the session end.
TELEMETRY_FILE="${HOME}/.claude/.tokelang-telemetry.json"
maybe_send_telemetry() {
  command -v curl >/dev/null 2>&1 || return 0
  [[ -f "${TELEMETRY_FILE}" ]] || return 0
  local enabled anon_id endpoint level os arch events payload
  enabled="$(jq -r '.enabled // false' "${TELEMETRY_FILE}" 2>/dev/null || echo false)"
  [[ "${enabled}" == "true" ]] || return 0
  anon_id="$(jq -r '.anon_id // "unknown"' "${TELEMETRY_FILE}" 2>/dev/null || echo unknown)"
  endpoint="${TOKELANG_TELEMETRY_ENDPOINT:-https://tokelang.com/v1/telemetry}"
  level="$(jq -r '.["tokelang.level"] // "unknown"' "${HOME}/.claude/settings.json" 2>/dev/null || echo unknown)"
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  events="$(echo "${STATS_JSON}" | jq -r '.events // 0' 2>/dev/null || echo 0)"
  # Aggregate-only payload: no session_id, no file paths, no prompt text.
  payload="$(jq -n \
    --arg aid "${anon_id}" --arg cli "1.0.0" --arg lvl "${level}" \
    --arg os "${os}" --arg arch "${arch}" \
    --argjson ss "${TOTAL_SAVED}" --argjson ev "${events}" \
    --argjson lt "${NEW_LIFETIME}" --argjson sc "${NEW_SESSIONS}" \
    '{schema:1, event:"session_stop", anon_id:$aid, cli_version:$cli, level:$lvl, os:$os, arch:$arch, session_tokens_saved:$ss, session_events:$ev, lifetime_tokens_saved:$lt, sessions_count:$sc}' \
    2>/dev/null)" || return 0
  [[ -n "${payload}" ]] || return 0
  ( nohup curl -fsS -m 3 -X POST -H 'Content-Type: application/json' \
      -d "${payload}" "${endpoint}" >/dev/null 2>&1 & ) 2>/dev/null || true
}
maybe_send_telemetry || true

# Cleanup session sidecar (lifetime already aggregated)
rm -f "${SESSION_SIDECAR}"
