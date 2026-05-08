#!/usr/bin/env bats
# Tests for plugin-path hygiene.
#
# When the waterfall plugin is installed from the marketplace, the plugin
# files live under ~/.claude/plugins/cache/<marketplace>/waterfall/<version>/,
# and agents run with cwd = user project (NOT the plugin tree).
#
# Therefore agent-facing instructions and runtime scripts MUST reference
# scripts via ${CLAUDE_PLUGIN_ROOT}/scripts/... (or via BASH_SOURCE-relative
# resolution for shell scripts), never via the bare relative form
# `bash scripts/wf-...` or `$PROJECT_ROOT/scripts/wf-...`.
#
# This test guards against regressions of the bug fixed in 2026-05-08
# (wf-auth.sh sourcing wf-step-agents.sh from $PROJECT_ROOT/scripts/).
#
# Invocation: bats tests/wf-plugin-paths.bats

# Roots scanned for forbidden patterns. Paths are relative to repo root.
AGENT_FACING_DIRS=("agents" "skills")

# ─── TG-001 — agents/ and skills/ must use ${CLAUDE_PLUGIN_ROOT} ─────────────
@test "TG-001: no bare 'bash scripts/wf-' in agents/ or skills/" {
  run bash -c "
    set -e
    hits=\$(grep -rn --include='*.md' -E 'bash[[:space:]]+scripts/wf-' agents skills 2>/dev/null || true)
    if [[ -n \"\$hits\" ]]; then
      echo 'FORBIDDEN: bare relative scripts/ path in agent-facing docs:'
      echo \"\$hits\"
      exit 1
    fi
  "
  [ "$status" -eq 0 ]
}

# ─── TG-002 — runtime shell scripts must not hardcode \$PROJECT_ROOT/scripts ─
# Exception: wf-auth.sh and wf-statusline.sh keep $PROJECT_ROOT as a
# documented final fallback in their cascade. Allowed only inside a
# multi-candidate `for _candidate in ...; do` loop.
@test "TG-002: no naked \$PROJECT_ROOT/scripts source in shell scripts" {
  run bash -c "
    set -e
    # Find any line that sources/execs scripts/ via \$PROJECT_ROOT outside
    # of a fallback cascade. We allow occurrences inside a 'for _candidate'
    # block by filtering out indented continuations.
    hits=\$(grep -rn --include='*.sh' -E '(source|bash|\\.)[[:space:]]+\"?\\\$PROJECT_ROOT/scripts/wf-' scripts hooks 2>/dev/null || true)
    if [[ -n \"\$hits\" ]]; then
      echo 'FORBIDDEN: direct \$PROJECT_ROOT/scripts/ usage (use plugin-aware fallback):'
      echo \"\$hits\"
      exit 1
    fi
  "
  [ "$status" -eq 0 ]
}

# ─── TG-003 — hooks.json must use \${CLAUDE_PLUGIN_ROOT} ─────────────────────
@test "TG-003: hooks.json references \${CLAUDE_PLUGIN_ROOT}" {
  run bash -c "
    grep -q 'CLAUDE_PLUGIN_ROOT' hooks/hooks.json
  "
  [ "$status" -eq 0 ]
}
