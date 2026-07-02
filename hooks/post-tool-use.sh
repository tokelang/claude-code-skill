#!/usr/bin/env bash
# Tokelang PostToolUse hook
# Fires AFTER a tool runs, before its result enters the model's context. Matcher in hooks.json
# restricts this to WebFetch / WebSearch — verbose, prose-heavy results that bloat the loop.
#
# Why only WebFetch/WebSearch (not Read/Edit/Bash/Grep):
#   Tool results are correctness-critical. Code, diffs, logs, and structured data must reach the
#   model byte-exact — lossy compression there risks silent breakage. WebFetch/WebSearch return
#   prose we can safely fold. (Read/Bash/etc. pass through untouched.)
#
#   updatedToolOutput REPLACES the tool result the model sees (the PostToolUse analogue of
#   PreToolUse's updatedInput). The engine is validator-gated and returns the ORIGINAL unchanged
#   on any recall / protected-span failure, so worst case here is a no-op, never a corrupted result.
#
# Reads stdin JSON:  { tool_name, tool_response, session_id, ... }
# Writes stdout JSON: { hookSpecificOutput: { hookEventName: "PostToolUse",
#                                             updatedToolOutput: "<compressed>" } }
# Any error / passthrough condition emits `{}` (leaves the result unchanged).

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(readlink -f "$0")")")}"
SETTINGS_FILE="${HOME}/.claude/settings.json"
CLI_BIN="${PLUGIN_ROOT}/bin/tokelang-cli-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"

pass() { echo '{}'; exit 0; }

# --- level -> compression mode -----------------------------------------------------------
# off/L1 : passthrough (tool results untouched at Safe level)
# L2     : context_file mode — highest recall floor, no MEC stage, code-dense text near-0% (safe)
# L3     : default mode — more aggressive ("medium" depth)
# custom : tokelang.custom.tool_output (bool) + tokelang.custom.tool_output.depth (lite|medium)
LEVEL="2"
if [[ -f "${SETTINGS_FILE}" ]]; then
  LEVEL="$(jq -r '.["tokelang.level"] // "2"' "${SETTINGS_FILE}" 2>/dev/null || echo "2")"
fi

MODE=""
case "${LEVEL}" in
  "1"|"off"|"") pass ;;
  "2") MODE="context_file" ;;
  "3") MODE="default" ;;
  "custom")
    C_ON="$(jq -r '.["tokelang.custom"].tool_output // false' "${SETTINGS_FILE}" 2>/dev/null || echo false)"
    [[ "${C_ON}" == "true" ]] || pass
    C_DEPTH="$(jq -r '.["tokelang.custom"]["tool_output.depth"] // "lite"' "${SETTINGS_FILE}" 2>/dev/null || echo lite)"
    [[ "${C_DEPTH}" == "medium" ]] && MODE="default" || MODE="context_file"
    ;;
  *) MODE="context_file" ;;  # unknown level → conservative
esac

STDIN_JSON="$(cat)"
TOOL_NAME="$(echo "${STDIN_JSON}" | jq -r '.tool_name // empty')"

# Scope guard (matcher should already restrict this; defensive)
case "${TOOL_NAME}" in
  WebFetch|WebSearch) : ;;
  *) pass ;;
esac

# Extract the textual result. tool_response may be a bare string or an object; coerce to text,
# preferring common content fields, else the raw JSON (which context_file mode folds near-0%).
RESULT="$(echo "${STDIN_JSON}" | jq -r '
  .tool_response
  | if type=="string" then .
    elif type=="object" then (.content // .result // .text // .output // tostring)
    else tostring end
  | if type=="string" then . else tostring end
' 2>/dev/null || echo "")"

# Nothing worth compressing
[[ -z "${RESULT}" || "${#RESULT}" -lt 500 ]] && pass

# Auto-clarity escape hatch — never fold a result carrying secrets/dangerous ops (mirror PreToolUse)
if echo "${RESULT}" | grep -qiE "(password|secret|api[ _-]?key|delete|drop table|rm -rf|force.push|production)"; then
  pass
fi

COMPRESSED="$(echo "${RESULT}" | "${CLI_BIN}" compress --mode "${MODE}" 2>/dev/null || echo "${RESULT}")"

# No gain (engine passed the original through, or empty) → leave result unchanged
if [[ -z "${COMPRESSED}" || "${COMPRESSED}" == "${RESULT}" ]]; then
  pass
fi

# Log savings to this session's sidecar (surface,orig,comp,unix_ts — same schema stats/stop.sh sum)
SESSION_ID="$(echo "${STDIN_JSON}" | jq -r '.session_id // "unknown"')"
SESSION_SIDECAR="${HOME}/.claude/.tokelang-session-${SESSION_ID}"
ORIG_TOKENS="$(echo "${RESULT}"     | "${CLI_BIN}" count --tokenizer cl100k 2>/dev/null || echo "0")"
COMP_TOKENS="$(echo "${COMPRESSED}" | "${CLI_BIN}" count --tokenizer cl100k 2>/dev/null || echo "0")"
echo "tooloutput,${ORIG_TOKENS},${COMP_TOKENS},$(date +%s)" >> "${SESSION_SIDECAR}" 2>/dev/null || true

# Replace the tool result the model sees
jq -n --arg out "${COMPRESSED}" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    updatedToolOutput: $out
  }
}'
