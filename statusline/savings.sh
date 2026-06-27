#!/usr/bin/env bash
# Tokelang statusline reader
# Invoked by Claude Code statusline.command setting.
# Reads the suffix file written by stop.sh and prints to stdout.

set -euo pipefail

STATUSLINE_SUFFIX="${HOME}/.claude/.tokelang-statusline-suffix"

if [[ -f "${STATUSLINE_SUFFIX}" ]]; then
  cat "${STATUSLINE_SUFFIX}"
else
  # First-run: no data yet
  echo "tokelang: tracking"
fi
