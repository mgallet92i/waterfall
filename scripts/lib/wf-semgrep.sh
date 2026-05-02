#!/usr/bin/env bash
# Optional static analysis via Semgrep, used by TL during code review.
# Auto-detects the available runner: native CLI first, Docker fallback,
# silent skip if neither is available.
#
# Usage:
#   source scripts/lib/wf-semgrep.sh
#   wf_semgrep_scan <repo_root> <output_json> <file_rel_to_repo> [<file_rel_to_repo>...]
#
# Always returns 0. The caller (TL) reads <output_json> to interpret findings.
# Output JSON is the standard Semgrep schema. When the scan is skipped, the
# JSON contains an extra top-level "wf_skipped" field describing the reason
# (none|disabled|no-files|no-tool|docker-pull-failed).

wf_semgrep_scan() {
  local repo_root="$1"; shift
  local out_json="$1"; shift
  local files=("$@")

  local enabled
  enabled=$(jq -r '.tools.semgrep // "off"' "${repo_root}/.wf-config.json" 2>/dev/null || echo "off")
  if [[ "$enabled" != "on" ]]; then
    printf '{"results":[],"errors":[],"paths":{"scanned":[]},"wf_skipped":"disabled"}\n' > "$out_json"
    return 0
  fi

  if (( ${#files[@]} == 0 )); then
    printf '{"results":[],"errors":[],"paths":{"scanned":[]},"wf_skipped":"no-files"}\n' > "$out_json"
    return 0
  fi

  # Build --config flags from .wf-config.json or fall back to the strict default
  local -a config_flags=()
  local rules_kind
  rules_kind=$(jq -r '.tools.semgrep_rules | type' "${repo_root}/.wf-config.json" 2>/dev/null)
  if [[ "$rules_kind" == "array" ]]; then
    while IFS= read -r r; do
      [[ -n "$r" ]] && config_flags+=(--config "$r")
    done < <(jq -r '.tools.semgrep_rules[]' "${repo_root}/.wf-config.json" 2>/dev/null)
  fi
  if (( ${#config_flags[@]} == 0 )); then
    config_flags=(--config p/owasp-top-ten --config p/cwe-top-25 --config p/default)
  fi

  # Mode 1 — native CLI
  if command -v semgrep >/dev/null 2>&1; then
    ( cd "$repo_root" && semgrep scan "${config_flags[@]}" --json --quiet "${files[@]}" ) > "$out_json" 2>/dev/null
    return 0
  fi

  # Mode 2 — Docker fallback
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    if ! docker image inspect semgrep/semgrep >/dev/null 2>&1; then
      if ! docker pull semgrep/semgrep >/dev/null 2>&1; then
        printf '{"results":[],"errors":[],"paths":{"scanned":[]},"wf_skipped":"docker-pull-failed"}\n' > "$out_json"
        return 0
      fi
    fi
    local mount_root="$repo_root"
    if command -v cygpath >/dev/null 2>&1; then
      mount_root=$(cygpath -w "$repo_root" | tr '\\' '/')
    fi
    local container_files=()
    local f
    for f in "${files[@]}"; do
      container_files+=("/src/$f")
    done
    MSYS_NO_PATHCONV=1 docker run --rm -v "${mount_root}:/src" semgrep/semgrep \
      semgrep scan "${config_flags[@]}" --json --quiet "${container_files[@]}" > "$out_json" 2>/dev/null
    return 0
  fi

  printf '{"results":[],"errors":[],"paths":{"scanned":[]},"wf_skipped":"no-tool"}\n' > "$out_json"
  return 0
}
