#!/usr/bin/env bash
# Source this script to export WF config variables.
# Usage: source scripts/wf-read-config.sh
#
# Effects:
#   - Exports WF_* variables (defaults applied if field missing)
#   - Validates each field against its list of allowed values
#   - Emits a markdown recap on stdout for the LLM (tool result)
#   - Exit 2 if a value is invalid (stops the bootstrap)

CONFIG=".wf-config.json"
CONFIG_SOURCE="DEFAULTS (file missing)"

# Defaults
WF_WATCHDOG_INTERVAL="3min"
WF_AGENT_MODE="team"
WF_DARK_FACTORY="off"
WF_MODEL_PM="sonnet"
WF_MODEL_OR="sonnet"
WF_MODEL_PO="sonnet"
WF_MODEL_TL="sonnet"
WF_MODEL_RV="sonnet"
WF_MODEL_QA="sonnet"
WF_MODEL_DV="sonnet"
WF_MODEL_DS="sonnet"
WF_REVIEW_ARTIFACTS=2
WF_REVIEW_CODE=3
WF_TOOLS_SEMGREP="off"

if [[ -f "$CONFIG" ]]; then
  CONFIG_SOURCE=".wf-config.json"
  WF_WATCHDOG_INTERVAL=$(jq -r '.watchdog.interval // "5min"' "$CONFIG")
  WF_AGENT_MODE=$(jq -r '.agent_mode // "team"' "$CONFIG")
  WF_DARK_FACTORY=$(jq -r '.dark_factory // "off"' "$CONFIG")
  WF_REVIEW_ARTIFACTS=$(jq -r '.review_loops.artifacts // 2' "$CONFIG")
  WF_REVIEW_CODE=$(jq -r '.review_loops.code // 3' "$CONFIG")
  WF_TOOLS_SEMGREP=$(jq -r '.tools.semgrep // "off"' "$CONFIG")
  for role in pm or po tl rv qa dv ds; do
    varname="WF_MODEL_${role^^}"
    val=$(jq -r ".models.${role} // empty" "$CONFIG")
    [[ -n "$val" ]] && declare "$varname=$val"
  done
fi

# --- Language: auto-detect from $LANG (override via env WF_LANGUAGE if set) ---
# Not read from .wf-config.json — selection is automatic.
if [[ -z "${WF_LANGUAGE:-}" ]]; then
  case "${LANG:-}" in
    fr*) WF_LANGUAGE="fr" ;;
    *)   WF_LANGUAGE="en" ;;
  esac
fi

# --- Validation ---
errors=()

_in() {  # _in <val> <choice1> <choice2> ...
  local v="$1"; shift
  for c in "$@"; do [[ "$v" == "$c" ]] && return 0; done
  return 1
}

_in "$WF_WATCHDOG_INTERVAL" off 3min 5min 10min || errors+=("watchdog.interval='$WF_WATCHDOG_INTERVAL' (expected:off|3min|5min|10min)")
_in "$WF_LANGUAGE" fr en                        || errors+=("WF_LANGUAGE='$WF_LANGUAGE' (expected:fr|en — auto-detected from \$LANG, override via env)")
_in "$WF_AGENT_MODE" team subagent subagent-light || errors+=("agent_mode='$WF_AGENT_MODE' (expected:team|subagent|subagent-light)")
# F-039 Theme C: 'subagent' fusionne dans 'team' (equipe implicite native, CLI v2.1.178+).
# Encore accepte comme alias deprecie -> mappe sur 'team'. 'subagent-light' reste distinct.
WF_AGENT_MODE_DEPRECATED=""
if [[ "$WF_AGENT_MODE" == "subagent" ]]; then
  WF_AGENT_MODE_DEPRECATED="subagent"
  WF_AGENT_MODE="team"
fi
_in "$WF_DARK_FACTORY" on off                    || errors+=("dark_factory='$WF_DARK_FACTORY' (expected:on|off)")
_in "$WF_TOOLS_SEMGREP" on off                   || errors+=("tools.semgrep='$WF_TOOLS_SEMGREP' (expected:on|off)")

# tools.semgrep_rules — optional array of strings (registry packs or local paths)
WF_TOOLS_SEMGREP_RULES_RECAP="default (p/owasp-top-ten, p/cwe-top-25, p/default)"
if [[ -f "$CONFIG" ]]; then
  rules_kind=$(jq -r '.tools.semgrep_rules | type' "$CONFIG" 2>/dev/null)
  case "$rules_kind" in
    array)
      rules_count=$(jq -r '.tools.semgrep_rules | length' "$CONFIG")
      if (( rules_count == 0 )); then
        errors+=("tools.semgrep_rules=[] (expected: non-empty array of strings, or omit to use the strict default)")
      else
        bad=$(jq -r '.tools.semgrep_rules[] | select(type != "string" or length == 0) | "1"' "$CONFIG" | head -1)
        if [[ -n "$bad" ]]; then
          errors+=("tools.semgrep_rules contains non-string or empty entries (expected: array of non-empty strings)")
        else
          WF_TOOLS_SEMGREP_RULES_RECAP=$(jq -r '.tools.semgrep_rules | join(", ")' "$CONFIG")
        fi
      fi
      ;;
    null|"") ;;  # absent → use default
    *) errors+=("tools.semgrep_rules type='$rules_kind' (expected:array of strings)") ;;
  esac
fi

for role in pm or po tl rv qa dv ds; do
  varname="WF_MODEL_${role^^}"
  _in "${!varname}" opus sonnet haiku fable || errors+=("models.$role='${!varname}' (expected:opus|sonnet|haiku|fable)")
done

[[ "$WF_REVIEW_ARTIFACTS" =~ ^[0-9]+$ ]] && (( WF_REVIEW_ARTIFACTS >= 1 )) || errors+=("review_loops.artifacts='$WF_REVIEW_ARTIFACTS' (expected: integer >= 1)")
[[ "$WF_REVIEW_CODE"      =~ ^[0-9]+$ ]] && (( WF_REVIEW_CODE >= 1 ))      || errors+=("review_loops.code='$WF_REVIEW_CODE' (expected: integer >= 1)")

export WF_WATCHDOG_INTERVAL WF_LANGUAGE WF_AGENT_MODE WF_DARK_FACTORY
export WF_REVIEW_ARTIFACTS WF_REVIEW_CODE
export WF_TOOLS_SEMGREP WF_TOOLS_SEMGREP_RULES_RECAP
export WF_MODEL_PM WF_MODEL_OR WF_MODEL_PO WF_MODEL_TL
export WF_MODEL_RV WF_MODEL_QA WF_MODEL_DV WF_MODEL_DS

# EX-001 — Session ID (INV-001: jamais synthétique, vide hors Claude Code)
# Claude Code n'exporte pas toujours $CLAUDE_SESSION_ID au shell des Bash tool
# calls. Fallback: répertoire le plus récent dans ~/.claude/session-env/ — son
# nom est le sid de la session active.
WF_SID="${CLAUDE_SESSION_ID:-}"
if [[ -z "$WF_SID" && -d "$HOME/.claude/session-env" ]]; then
  WF_SID="$(ls -1t "$HOME/.claude/session-env/" 2>/dev/null | head -1)"
fi
export WF_SID

# --- Markdown recap (stdout, visible in tool result) ---
if (( ${#errors[@]} > 0 )); then
  echo "## ❌ Invalid waterfall config"
  echo ""
  echo "Source: $CONFIG_SOURCE"
  echo ""
  echo "Errors:"
  for e in "${errors[@]}"; do echo "- $e"; done
  echo ""
  echo "Fix \`.wf-config.json\` or re-run \`/waterfall:config\`."
  exit 2
fi

cat <<EOF
## Waterfall config resolved

- **source**: $CONFIG_SOURCE
- **agent_mode**: $WF_AGENT_MODE${WF_AGENT_MODE_DEPRECATED:+ _(alias déprécié \`subagent\` → \`team\`)_}  _(team = Agent Teams, implicit team via Agent spawn + inter-agent SendMessage, no TeamCreate; subagent-light = Agent tool, 2 agents PM+TL, 3 artefacts, 3 interactions HO. \`subagent\` est fusionné dans \`team\` — F-039.)_
- **dark_factory**: $WF_DARK_FACTORY  _(on = max autonomy, validate checkpoints alone; off = escalate decisions to HO)_
- **watchdog**: $WF_WATCHDOG_INTERVAL
- **language**: $WF_LANGUAGE  _(auto-detected from \$LANG; override via env WF_LANGUAGE)_
- **models**: pm=$WF_MODEL_PM, or=$WF_MODEL_OR, po=$WF_MODEL_PO, tl=$WF_MODEL_TL, rv=$WF_MODEL_RV, qa=$WF_MODEL_QA, dv=$WF_MODEL_DV, ds=$WF_MODEL_DS
- **review_loops**: artifacts=$WF_REVIEW_ARTIFACTS, code=$WF_REVIEW_CODE
- **tools**: semgrep=$WF_TOOLS_SEMGREP  _(on = TL runs Semgrep static analysis on the diff during code review; off = skip)_
- **semgrep rules**: $WF_TOOLS_SEMGREP_RULES_RECAP
- **sid**: ${WF_SID:-non défini}

> To modify: edit \`.wf-config.json\` at the root (schema: \`.wf-config.example.md\`).
EOF
