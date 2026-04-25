#!/usr/bin/env bash
# wf-check-bash.sh — Preflight check for a real bash environment.
# Usage: called by skills/wf-new/SKILL.md and skills/wf-resume/SKILL.md before any other preflight.
# Fails fast with a clear error if not running under bash, or on Windows outside Git Bash / MSYS.

set -euo pipefail

# 1. Must be running under bash itself (not sh, dash, zsh, fish, …).
#    BASH_VERSION is set by bash and only by bash.
if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "ERROR: bash is required to run the waterfall plugin." >&2
  echo "" >&2
  echo "The current shell is not bash. All scripts shipped by this plugin use bash-only features." >&2
  echo "" >&2
  echo "  - macOS/Linux: re-run from a bash shell (\`bash\`) or install bash via your package manager." >&2
  echo "  - Windows:     install Git for Windows and run from Git Bash." >&2
  echo "                 Download: https://git-scm.com/download/win" >&2
  echo "" >&2
  exit 1
fi

# 2. On Windows, require Git Bash / MSYS / MINGW. cmd.exe and PowerShell are not supported,
#    even when bash.exe is available via WSL — file paths and process semantics differ.
case "${OS:-}${OSTYPE:-}" in
  *Windows_NT*|*msys*|*cygwin*|*mingw*) is_windows=1 ;;
  *) is_windows=0 ;;
esac

if [[ "$is_windows" == "1" ]] && [[ -z "${MSYSTEM:-}" ]]; then
  echo "ERROR: on Windows, the waterfall plugin must run from Git Bash (MSYS/MINGW)." >&2
  echo "" >&2
  echo "Detected Windows but MSYSTEM is unset — this looks like cmd.exe, PowerShell, or WSL bash." >&2
  echo "Launch Claude Code from a Git Bash terminal (\"Git Bash\" entry in the Start menu)." >&2
  echo "" >&2
  echo "If you do not have Git Bash, install Git for Windows: https://git-scm.com/download/win" >&2
  echo "" >&2
  exit 1
fi

echo "OK: bash ${BASH_VERSION%%[^0-9.]*} detected${MSYSTEM:+ (MSYSTEM=$MSYSTEM)}."
exit 0
