#!/usr/bin/env bash
# Tokelang PreToolUse hook
# Fires before the model invokes a tool. Matcher in hooks.json restricts this to the Task tool
# (subagent invocations) — other tools pass through untouched.
#
# Why Task only:
#   The Task tool invokes a subagent with a prompt argument that is often long verbose prose
#   ("research X, then summarize Y, then check Z"). Subagent context bloat is a real cost
#   on multi-turn agent loops. updatedInput field actually replaces the input (unlike
#   UserPromptSubmit / PostToolUse which are additive-only). So this is the one place
#   where the plugin can do real input compression.
#
# Reads stdin JSON: { tool_name, tool_input, session_id, ... }
# Writes stdout JSON: { hookSpecificOutput: { updatedInput: { ... } } } to replace tool args.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(readlink -f "$0")")")}"
SETTINGS_FILE="${HOME}/.claude/settings.json"
CLI_BIN="${PLUGIN_ROOT}/bin/tokelang-cli-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"

LEVEL="2"
if [[ -f "${SETTINGS_FILE}" ]]; then
  LEVEL="$(jq -r '.["tokelang.level"] // "2"' "${SETTINGS_FILE}" 2>/dev/null || echo "2")"
fi

STDIN_JSON="$(cat)"

# L1 / off: pass through unchanged (still need to emit valid JSON)
case "${LEVEL}" in
  "1"|"off"|"")
    echo '{}'; exit 0
    ;;
esac

TOOL_NAME="$(echo "${STDIN_JSON}" | jq -r '.tool_name // empty')"
PROMPT="$(echo "${STDIN_JSON}" | jq -r '.tool_input.prompt // empty')"

# Only act on Task tool (matcher should already restrict this, defensive check anyway)
if [[ "${TOOL_NAME}" != "Task" ]]; then
  echo '{}'; exit 0
fi

# Nothing to compress
if [[ -z "${PROMPT}" || "${#PROMPT}" -lt 200 ]]; then
  echo '{}'; exit 0
fi

# Auto-clarity escape hatch
if echo "${PROMPT}" | grep -qiE "(password|secret|api[ _-]?key|delete|drop table|rm -rf|force.push|production)"; then
  echo '{}'; exit 0
fi

# Compress in subagent_input mode (tighter recall floor 0.90)
COMPRESSED="$(echo "${PROMPT}" | "${CLI_BIN}" compress --mode subagent_input 2>/dev/null || echo "${PROMPT}")"

if [[ -z "${COMPRESSED}" || "${COMPRESSED}" == "${PROMPT}" ]]; then
  echo '{}'; exit 0
fi

# Log savings
SESSION_ID="$(echo "${STDIN_JSON}" | jq -r '.session_id // "unknown"')"
SESSION_SIDECAR="${HOME}/.claude/.tokelang-session-${SESSION_ID}"
ORIG_TOKENS="$(echo "${PROMPT}" | "${CLI_BIN}" count --tokenizer cl100k 2>/dev/null || echo "0")"
COMP_TOKENS="$(echo "${COMPRESSED}" | "${CLI_BIN}" count --tokenizer cl100k 2>/dev/null || echo "0")"
echo "subagent,${ORIG_TOKENS},${COMP_TOKENS},$(date +%s)" >> "${SESSION_SIDECAR}" 2>/dev/null || true

# Emit hookSpecificOutput with updatedInput — the field that ACTUALLY replaces tool args
# Build a new tool_input object with the compressed prompt
UPDATED_INPUT="$(echo "${STDIN_JSON}" | jq --arg p "${COMPRESSED}" '.tool_input | .prompt = $p')"
jq -n --argjson ui "${UPDATED_INPUT}" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    updatedInput: $ui
  }
}'
