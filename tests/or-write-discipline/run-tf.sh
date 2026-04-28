#!/usr/bin/env bash
# run-tf.sh — Suite TF-OR-01..07 pour le need or-write-discipline
# Usage : bash tests/or-write-discipline/run-tf.sh
# Exit 0 si tous PASS, exit 1 si au moins un FAIL.
# Idempotent : aucun effet de bord persistant.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NEED="or-write-discipline"
NEED_DIR="$REPO_ROOT/wf/needs/$NEED"
FIXTURES="$NEED_DIR/.test-fixtures"

pass=0
fail=0

_pass() { echo "PASS  $1"; ((pass++)); }
_fail() { echo "FAIL  $1 — $2"; ((fail++)); }

# ─── TF-OR-01 — Hook bloque Write OR sur PRD.md ──────────────────────────────
run_tf_or_01() {
  local payload result
  payload='{"tool_name":"Write","agent_type":"or","tool_input":{"file_path":"wf/needs/or-write-discipline/PRD.md","content":"test"}}'
  result=$(cd "$REPO_ROOT" && echo "$payload" | bash hooks/wf-auth.sh 2>&1; echo "EXIT:$?")
  if echo "$result" | grep -q "EXIT:2" && echo "$result" | grep -q "blocked\|block"; then
    _pass "TF-OR-01 (Write OR PRD.md → exit 2 + blocked)"
  else
    _fail "TF-OR-01" "exit non-2 ou message absent (got: $result)"
  fi
}

# ─── TF-OR-02 — Hook bloque Edit OR sur specs.md ─────────────────────────────
run_tf_or_02() {
  local payload result
  payload='{"tool_name":"Edit","agent_type":"or","tool_input":{"file_path":"wf/needs/or-write-discipline/specs.md","old_string":"x","new_string":"y"}}'
  result=$(cd "$REPO_ROOT" && echo "$payload" | bash hooks/wf-auth.sh 2>&1; echo "EXIT:$?")
  echo "$result" | grep -q "EXIT:2" \
    && _pass "TF-OR-02 (Edit OR specs.md → exit 2)" \
    || _fail "TF-OR-02" "exit non-2 (got: $result)"
}

# ─── TF-OR-03 — --query émet spawn_role_mismatch avec fixtures ───────────────
run_tf_or_03() {
  local query_out mismatch
  query_out=$(
    cd "$REPO_ROOT"
    export WF_TEST_TRANSCRIPT_PATH="$FIXTURES/pending-spawn-role-tl.txt"
    export WF_TEST_STATE_PATH="$FIXTURES/state-requirements.json"
    bash scripts/wf-orchestrate.sh "$NEED" --query 2>/dev/null
  )
  mismatch=$(echo "$query_out" | node -e "
    let d = '';
    process.stdin.on('data', c => d += c);
    process.stdin.on('end', () => {
      try {
        const o = JSON.parse(d);
        process.stdout.write(o.spawn_role_mismatch ? JSON.stringify(o.spawn_role_mismatch) : 'ABSENT');
      } catch(e) { process.stdout.write('PARSE_ERROR'); }
    });
  " 2>/dev/null)
  if echo "$mismatch" | grep -q '"requested_role":"tl"' \
    && echo "$mismatch" | grep -q '"expected_role":"po"' \
    && echo "$mismatch" | grep -q '"phase":"REQUIREMENTS"'; then
    _pass "TF-OR-03 (spawn_role_mismatch tl→po en REQUIREMENTS)"
  else
    _fail "TF-OR-03" "champ absent ou valeurs incorrectes (got: $mismatch)"
  fi
}

# ─── TF-OR-04 — doc ARTIFACT_UPDATE dans wf-pm/SKILL.md ──────────────────────
run_tf_or_04() {
  local ok=1
  grep -q "ARTIFACT_UPDATE" "$REPO_ROOT/skills/wf-pm/SKILL.md" || ok=0
  grep -qE "ERROR_UNRECOVERABLE|shutdown_request" "$REPO_ROOT/skills/wf-pm/SKILL.md" || ok=0
  [[ $ok -eq 1 ]] \
    && _pass "TF-OR-04 (ARTIFACT_UPDATE + sanction dans wf-pm/SKILL.md)" \
    || _fail "TF-OR-04" "grep ARTIFACT_UPDATE ou sanction manquant"
}

# ─── TF-OR-05 — Dispatch matrix avec colonne artéfacts interdits ─────────────
run_tf_or_05() {
  local ok=1
  grep -qE "Artéfact.*interdit|forbidden.*artifact|interdit.*OR" "$REPO_ROOT/agents/wf-or.md" || ok=0
  grep -A3 "FUNCTIONAL_SPECS" "$REPO_ROOT/agents/wf-or.md" | grep -qi "po" || ok=0
  [[ $ok -eq 1 ]] \
    && _pass "TF-OR-05 (colonne artéfacts interdits + FUNCTIONAL_SPECS=PO)" \
    || _fail "TF-OR-05" "colonne ou agent PO absent"
}

# ─── TF-OR-06 — Hook autorise Write OR sur or.log ────────────────────────────
run_tf_or_06() {
  local payload result
  payload='{"tool_name":"Write","agent_type":"or","tool_input":{"file_path":"wf/needs/or-write-discipline/or.log","content":"test log entry"}}'
  result=$(cd "$REPO_ROOT" && echo "$payload" | bash hooks/wf-auth.sh 2>&1; echo "EXIT:$?")
  echo "$result" | grep -q "EXIT:0" \
    && _pass "TF-OR-06 (Write OR or.log → exit 0)" \
    || _fail "TF-OR-06" "exit non-0 (got: $result)"
}

# ─── TF-OR-07 — Auto-test Q1/Q2/Q3 présent dans wf-or.md ────────────────────
run_tf_or_07() {
  local ok=1
  grep -qE "Q1\..*or\.log" "$REPO_ROOT/agents/wf-or.md" || ok=0
  grep -qE "Q3\..*(PRD|specs|design)" "$REPO_ROOT/agents/wf-or.md" || ok=0
  [[ $ok -eq 1 ]] \
    && _pass "TF-OR-07 (Q1 or.log + Q3 PRD/specs/design dans wf-or.md)" \
    || _fail "TF-OR-07" "Q1 ou Q3 absent de wf-or.md"
}

# ─── Run all ──────────────────────────────────────────────────────────────────
echo "=== TF or-write-discipline ==="
run_tf_or_01
run_tf_or_02
run_tf_or_03
run_tf_or_04
run_tf_or_05
run_tf_or_06
run_tf_or_07
echo ""
echo "Résultat : $pass PASS / $((pass + fail)) total"
[[ $fail -eq 0 ]] && echo "ALL PASS" && exit 0 || echo "$fail FAIL(s)" && exit 1
