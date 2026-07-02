#!/usr/bin/env bash
# Tokelang SessionStart hook
# Fires on session start/resume/clear/compact.
# Responsibilities:
#   1. Load level setting from ~/.claude/settings.json
#   2. Emit the output style guide via additionalContext (lite/full → inject; off → no injection)
#   3. Emit one-line off-switch reminder so user always knows how to disable
#
# Reads stdin JSON: { session_id, transcript_path, cwd, model, source }
# Writes stdout JSON with optional { additionalContext: "..." }

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(readlink -f "$0")")")}"
SETTINGS_FILE="${HOME}/.claude/settings.json"
CLI_BIN="${PLUGIN_ROOT}/bin/tokelang-cli-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"

# Default level if settings missing or unreadable
LEVEL="lite"
if [[ -f "${SETTINGS_FILE}" ]]; then
  LEVEL="$(jq -r '.["tokelang.level"] // "lite"' "${SETTINGS_FILE}" 2>/dev/null || echo "lite")"
fi
# Legacy numeric levels (pre-1.0.1): 1/2 → lite, 3 → full
case "${LEVEL}" in 1|2) LEVEL="lite" ;; 3) LEVEL="full" ;; esac

# Read source field from stdin (startup / resume / clear / compact)
STDIN_JSON="$(cat)"
SOURCE="$(echo "${STDIN_JSON}" | jq -r '.source // "startup"' 2>/dev/null || echo "startup")"

# If level is off, emit nothing — skill stays loaded but inert
if [[ "${LEVEL}" == "off" ]]; then
  echo '{}'
  exit 0
fi

# Style-guide content varies by level (off already returned above)
case "${LEVEL}" in
  "full") STYLE="medium" ;;
  *)      STYLE="lite" ;;   # lite (default) or unknown → conservative
esac

# Build the additionalContext payload
case "${STYLE}" in
  "lite")
    CONTEXT="Tokelang is active (lite). Respond concisely. Drop pleasantries, hedges, and filler. Be direct. Run /tokelang-output off any time to disable."
    ;;
  "medium")
    CONTEXT="Tokelang is active (full). Respond in compact form: fragments OK, drop articles where unambiguous, use bullet/key:value over prose paragraphs. Code blocks and exact quotations stay verbatim. Run /tokelang-output lite or off to dial back."
    ;;
esac

# Emit JSON with additionalContext
jq -n --arg ctx "${CONTEXT}" '{additionalContext: $ctx}'
