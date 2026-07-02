#!/usr/bin/env bash
# Tokelang router config applier.
# Single deterministic entry point for the /tokelang-router skill. The model (router) maps the
# user's natural-language request to ONE of these subcommands and runs it; this script does the
# actual file edits so nothing is left to the model guessing line numbers.
#
# Source of truth: ~/.claude/.tokelang-router.json
# Side effects it applies from that config:
#   - ~/.claude/settings.json  ."agent"          (on/off toggle)
#   - <plugin>/agents/tokelang-router.md  model:  (router seat)
#   - <plugin>/agents/tokelang-worker.md  model:/effort:/maxTurns:  (worker seat)
#
# Usage:
#   apply.sh status
#   apply.sh enable | disable
#   apply.sh set <router-model|worker-model|worker-effort|worker-max-turns> <value>
#   apply.sh preset <max-savings|balanced|quality>
#
# Notes:
#   - Router-model changes take effect NEXT session (the session agent's model is fixed at launch).
#   - Worker-model/effort/max-turns take effect on the NEXT worker spawn (fresh each delegation).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AGENTS_DIR="${PLUGIN_ROOT}/agents"
ROUTER_MD="${AGENTS_DIR}/tokelang-router.md"
WORKER_MD="${AGENTS_DIR}/tokelang-worker.md"
SETTINGS="${HOME}/.claude/settings.json"
CONFIG="${HOME}/.claude/.tokelang-router.json"

VALID_MODELS="haiku sonnet opus fable inherit"
VALID_EFFORT="low medium high max"
VALID_ROUTING="fixed dynamic"

die() { echo "error: $*" >&2; exit 1; }
in_list() { local x="$1"; shift; for y in "$@"; do [[ "$x" == "$y" ]] && return 0; done; return 1; }

# --- config bootstrap -------------------------------------------------------------------
ensure_config() {
  [[ -f "${CONFIG}" ]] && return 0
  jq -n '{enabled:false, router_model:"haiku", router_effort:"medium", worker_model:"opus",
          worker_effort:"high", worker_max_turns:null, routing:"fixed", schema:1}' > "${CONFIG}"
}
cfg_get() { jq -r --arg k "$1" '.[$k] // empty' "${CONFIG}"; }
cfg_set() { # key, raw-json-value
  local tmp; tmp="$(mktemp)"
  jq --arg k "$1" --argjson v "$2" '.[$k]=$v' "${CONFIG}" > "${tmp}" && mv "${tmp}" "${CONFIG}"
}

# --- frontmatter rewrite (first match only, stays inside YAML head) ----------------------
fm_set() { # file, key, value
  local file="$1" key="$2" val="$3"
  [[ -f "${file}" ]] || die "agent file not found: ${file}"
  if grep -qE "^${key}:" "${file}"; then
    sed -i "0,/^${key}:.*/s//${key}: ${val}/" "${file}"
  else
    # insert after the 'name:' line so it lands inside frontmatter
    sed -i "0,/^name:.*/s//&\n${key}: ${val}/" "${file}"
  fi
}
fm_del() { # file, key  — remove first matching frontmatter line
  local file="$1" key="$2"
  grep -qE "^${key}:" "${file}" && sed -i "0,/^${key}:.*/{/^${key}:.*/d}" "${file}" || true
}

# --- settings.json agent toggle ---------------------------------------------------------
settings_enable() {
  mkdir -p "$(dirname "${SETTINGS}")"
  [[ -f "${SETTINGS}" ]] || echo '{}' > "${SETTINGS}"
  local tmp; tmp="$(mktemp)"
  jq '.agent="tokelang-router"' "${SETTINGS}" > "${tmp}" && mv "${tmp}" "${SETTINGS}"
}
settings_disable() {
  [[ -f "${SETTINGS}" ]] || return 0
  local tmp; tmp="$(mktemp)"
  # only remove if it's OUR agent (don't clobber a user's custom session agent)
  jq 'if .agent=="tokelang-router" then del(.agent) else . end' "${SETTINGS}" > "${tmp}" && mv "${tmp}" "${SETTINGS}"
}

# --- apply config -> files --------------------------------------------------------------
apply_all() {
  local rm re wm we wt
  rm="$(cfg_get router_model)"; re="$(cfg_get router_effort)"; wm="$(cfg_get worker_model)"
  we="$(cfg_get worker_effort)"; wt="$(cfg_get worker_max_turns)"
  [[ -n "${rm}" ]] && fm_set "${ROUTER_MD}" "model" "${rm}"
  [[ -n "${re}" ]] && fm_set "${ROUTER_MD}" "effort" "${re}"
  [[ -n "${wm}" ]] && fm_set "${WORKER_MD}" "model" "${wm}"
  [[ -n "${we}" ]] && fm_set "${WORKER_MD}" "effort" "${we}"
  if [[ -n "${wt}" && "${wt}" != "null" ]]; then fm_set "${WORKER_MD}" "maxTurns" "${wt}"; else fm_del "${WORKER_MD}" "maxTurns"; fi
  [[ "$(cfg_get enabled)" == "true" ]] && settings_enable || settings_disable
}

status() {
  ensure_config
  local agent; agent="$(jq -r '.agent // "(none)"' "${SETTINGS}" 2>/dev/null || echo '(none)')"
  local level; level="$(jq -r '.["tokelang.level"] // "2"' "${SETTINGS}" 2>/dev/null || echo 2)"
  echo "tokelang-router config (${CONFIG}):"
  jq -r '"  enabled        : \(.enabled)\n  router_model   : \(.router_model)\n  router_effort  : \(.router_effort // "medium")\n  routing        : \(.routing // "fixed")\n  worker_model   : \(.worker_model)\n  worker_effort  : \(.worker_effort)\n  worker_max_turns: \(.worker_max_turns // "(unset)")"' "${CONFIG}"
  echo "  session agent  : ${agent}   (settings.json .agent)"
  echo "  tokelang.level : ${level}   (Task-brief compression; keep >=2)"
  [[ "$(cfg_get enabled)" == "true" ]] && echo "  -> ON next session. Or this session: claude --agent tokelang-router" \
                                       || echo "  -> OFF. Enable: /tokelang-router on"
}

# --- main -------------------------------------------------------------------------------
ensure_config
cmd="${1:-status}"; shift || true
case "${cmd}" in
  status) status ;;
  enable|on)   cfg_set enabled true;  apply_all; echo "router ENABLED."; status ;;
  disable|off) cfg_set enabled false; apply_all; echo "router DISABLED."; status ;;
  set)
    key="${1:-}"; val="${2:-}"; [[ -n "${key}" && -n "${val}" ]] || die "usage: set <key> <value>"
    case "${key}" in
      router-model)  in_list "${val}" ${VALID_MODELS} || die "router-model must be: ${VALID_MODELS}"; cfg_set router_model "\"${val}\"" ;;
      router-effort) in_list "${val}" ${VALID_EFFORT} || die "router-effort must be: ${VALID_EFFORT}"; cfg_set router_effort "\"${val}\"" ;;
      worker-model)  in_list "${val}" ${VALID_MODELS} || die "worker-model must be: ${VALID_MODELS}"; cfg_set worker_model "\"${val}\"" ;;
      worker-effort) in_list "${val}" ${VALID_EFFORT} || die "worker-effort must be: ${VALID_EFFORT}"; cfg_set worker_effort "\"${val}\"" ;;
      worker-max-turns) [[ "${val}" =~ ^[0-9]+$ ]] || die "worker-max-turns must be an integer"; cfg_set worker_max_turns "${val}" ;;
      routing) in_list "${val}" ${VALID_ROUTING} || die "routing must be: ${VALID_ROUTING}"; cfg_set routing "\"${val}\"" ;;
      *) die "unknown key: ${key} (router-model|router-effort|worker-model|worker-effort|worker-max-turns|routing)" ;;
    esac
    apply_all; echo "set ${key}=${val}."; status ;;
  preset)
    name="${1:-}"
    case "${name}" in
      max-savings) cfg_set router_model '"haiku"';  cfg_set router_effort '"medium"'; cfg_set worker_model '"opus"'; cfg_set worker_effort '"high"' ;;
      balanced)    cfg_set router_model '"sonnet"'; cfg_set router_effort '"medium"'; cfg_set worker_model '"opus"'; cfg_set worker_effort '"high"' ;;
      quality)     cfg_set router_model '"sonnet"'; cfg_set router_effort '"high"';   cfg_set worker_model '"opus"'; cfg_set worker_effort '"max"'  ;;
      *) die "preset must be: max-savings | balanced | quality" ;;
    esac
    apply_all; echo "applied preset: ${name}."; status ;;
  *) die "unknown command: ${cmd} (status|enable|disable|set|preset)" ;;
esac
