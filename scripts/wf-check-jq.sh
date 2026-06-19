#!/usr/bin/env bash
# wf-check-jq.sh — Verifies jq is available; suggests an OS-aware install command if not.
# Used by wf scripts to parse .wf-state.json, .team-registry.json, etc.
# Exit codes:
#   0 — jq present (stdout: version line)
#   2 — jq absent (stdout: install command if a package manager is detected, else empty;
#                  stderr: human-readable message)

set -euo pipefail

if command -v jq >/dev/null 2>&1; then
  echo "OK: jq $(jq --version 2>/dev/null || echo '?') available."
  exit 0
fi

detect_install_cmd() {
  case "${OSTYPE:-}" in
    msys*|cygwin*|win32)
      if command -v winget >/dev/null 2>&1; then
        echo "winget install jqlang.jq -e --accept-package-agreements --accept-source-agreements"
      elif command -v choco >/dev/null 2>&1; then
        echo "choco install jq -y"
      elif command -v scoop >/dev/null 2>&1; then
        echo "scoop install jq"
      fi
      ;;
    darwin*)
      if command -v brew >/dev/null 2>&1; then
        echo "brew install jq"
      elif command -v port >/dev/null 2>&1; then
        echo "sudo port install jq"
      fi
      ;;
    linux*|*)
      if command -v apt-get >/dev/null 2>&1; then
        echo "sudo apt-get update && sudo apt-get install -y jq"
      elif command -v dnf >/dev/null 2>&1; then
        echo "sudo dnf install -y jq"
      elif command -v yum >/dev/null 2>&1; then
        echo "sudo yum install -y jq"
      elif command -v pacman >/dev/null 2>&1; then
        echo "sudo pacman -S --noconfirm jq"
      elif command -v zypper >/dev/null 2>&1; then
        echo "sudo zypper install -y jq"
      elif command -v apk >/dev/null 2>&1; then
        echo "sudo apk add jq"
      fi
      ;;
  esac
}

CMD="$(detect_install_cmd)"

{
  echo "ERROR: jq is required by the waterfall plugin scripts (parses .wf-state.json, .team-registry.json, etc.)."
  echo ""
  if [[ -n "$CMD" ]]; then
    echo "Suggested install command (OSTYPE=${OSTYPE:-unknown}):"
    echo "  $CMD"
  else
    echo "No supported package manager detected on OSTYPE=${OSTYPE:-unknown}."
    echo "Install jq manually: https://jqlang.github.io/jq/download/"
  fi
} >&2

echo "$CMD"
exit 2
