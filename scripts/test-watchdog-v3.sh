#!/usr/bin/env bash
# test-watchdog-v3.sh — Tests automatisés TF-001..TF-013 pour wf-watchdog.sh ACTOR_IDLE
# Usage: bash scripts/test-watchdog-v3.sh
# Exit: 0 si tous OK, 1 sinon.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
watchdog="$script_dir/wf-watchdog.sh"

# ─── Fixtures setup ──────────────────────────────────────────────────────────

FIXTURE_DIR="$project_root/wf/needs/wf-watchdog-v3/test-fixtures"
NEED_DIR="$FIXTURE_DIR/need"

pass=0
fail=0
errors=()

assert_pass() { pass=$(( pass + 1 )); }
assert_fail() {
  local tf="$1" reason="$2"
  fail=$(( fail + 1 ))
  errors+=("FAIL: $tf — $reason")
  echo "FAIL: $tf — $reason" >&2
}

# Setup fixture need directory
setup_need() {
  rm -rf "$NEED_DIR"
  mkdir -p "$NEED_DIR"

  # heartbeat.log avec timestamp récent (pour ne pas déclencher HEARTBEAT_STALE par défaut)
  local recent_ts
  recent_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "[$recent_ts] OR heartbeat" > "$NEED_DIR/heartbeat.log"

  # .wf-state.json minimal
  cat > "$NEED_DIR/.wf-state.json" <<EOF
{
  "phase": "FUNCTIONAL_SPECS",
  "step": "INTERVIEW_SPECS",
  "history": [
    {"agent": "po", "ts": "2020-01-01T00:00:00Z"}
  ]
}
EOF

  # .watchdog-state.json vide
  echo '{"last_history_ts":"","stuck_ticks":0}' > "$NEED_DIR/.watchdog-state.json"

  # ack-registry.json vide
  echo '{"entries":[]}' > "$NEED_DIR/ack-registry.json"

  # watchdog.alert vide
  > "$NEED_DIR/watchdog.alert"
}

run_watchdog() {
  bash "$watchdog" wf-watchdog-v3/test-fixtures/need "$@" 2>/dev/null
}

# ─── TF-001 — Détection ACTOR_IDLE quand PO idle > seuil ─────────────────────

tf001() {
  setup_need
  # ACK po datant de > 480s
  local old_epoch
  old_epoch="$(date -d '20 minutes ago' +%s 2>/dev/null || date -v-20M +%s)"
  cat > "$NEED_DIR/ack-registry.json" <<EOF
{"entries":[{"from":"po","status":"sent","last_sent_at":$old_epoch}]}
EOF

  WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=480 run_watchdog

  local reason actor poke elapsed
  reason="$(jq -r '.reason // ""' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"
  actor="$(jq -r '.actor // ""' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"
  poke="$(jq -r '.poke_sent // ""' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"
  elapsed="$(jq -r '.idle_elapsed_s // 0' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "0")"

  if [[ "$reason" == "ACTOR_IDLE" && "$actor" == "po" && "$poke" == "true" && "$elapsed" -gt 480 ]]; then
    assert_pass
    echo "PASS: TF-001"
  else
    assert_fail "TF-001" "reason=$reason actor=$actor poke=$poke elapsed=$elapsed"
  fi
}

# ─── TF-002 — Pas de détection ACTOR_IDLE quand agent actif ──────────────────

tf002() {
  setup_need
  # ACK po récent (< 480s)
  local recent_epoch
  recent_epoch="$(date +%s)"
  cat > "$NEED_DIR/ack-registry.json" <<EOF
{"entries":[{"from":"po","status":"sent","last_sent_at":$recent_epoch}]}
EOF

  WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=480 run_watchdog

  local reason ticks
  reason="$(jq -r '.reason // ""' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"
  ticks="$(jq -r '.actor_idle_ticks // -1' "$NEED_DIR/.watchdog-state.json" 2>/dev/null || echo "-1")"

  if [[ "$reason" != "ACTOR_IDLE" && "$ticks" == "0" ]]; then
    assert_pass
    echo "PASS: TF-002"
  else
    assert_fail "TF-002" "reason=$reason actor_idle_ticks=$ticks"
  fi
}

# ─── TF-003 — Skip silencieux quand actor=or ─────────────────────────────────

tf003() {
  setup_need
  # Step dont agent=or
  cat > "$NEED_DIR/.wf-state.json" <<EOF
{
  "phase": "FUNCTIONAL_SPECS",
  "step": "VALIDATE_SPECS",
  "history": [{"agent": "or", "ts": "2020-01-01T00:00:00Z"}]
}
EOF
  # Pas d'ACK or
  echo '{"entries":[]}' > "$NEED_DIR/ack-registry.json"

  WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=1 run_watchdog

  local reason
  reason="$(jq -r '.reason // ""' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"

  if [[ "$reason" != "ACTOR_IDLE" ]]; then
    assert_pass
    echo "PASS: TF-003"
  else
    assert_fail "TF-003" "reason=$reason (expected no ACTOR_IDLE for agent=or)"
  fi
}

# ─── TF-004 — Skip silencieux sur phase BOOTSTRAP ────────────────────────────

tf004() {
  setup_need
  cat > "$NEED_DIR/.wf-state.json" <<EOF
{
  "phase": "BOOTSTRAP",
  "step": "SPAWN_TEAM",
  "history": [{"agent": "pm", "ts": "2020-01-01T00:00:00Z"}]
}
EOF
  echo '{"entries":[]}' > "$NEED_DIR/ack-registry.json"

  WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=1 run_watchdog

  local reason
  reason="$(jq -r '.reason // ""' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"

  if [[ "$reason" != "ACTOR_IDLE" ]]; then
    assert_pass
    echo "PASS: TF-004"
  else
    assert_fail "TF-004" "reason=$reason (expected no ACTOR_IDLE for BOOTSTRAP phase)"
  fi
}

# ─── TF-005 — Cas PM : poke_sent=false, log [WATCHDOG-POKE-PM] ───────────────

tf005() {
  setup_need
  cat > "$NEED_DIR/.wf-state.json" <<EOF
{
  "phase": "REQUIREMENTS",
  "step": "CHECKPOINT_REQ",
  "history": [{"agent": "pm", "ts": "2020-01-01T00:00:00Z"}]
}
EOF
  local old_epoch
  old_epoch="$(date -d '20 minutes ago' +%s 2>/dev/null || date -v-20M +%s)"
  cat > "$NEED_DIR/ack-registry.json" <<EOF
{"entries":[{"from":"pm","status":"sent","last_sent_at":$old_epoch}]}
EOF
  > "$NEED_DIR/or.log"

  WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=480 run_watchdog

  local reason actor poke poke_pm_log
  reason="$(jq -r '.reason // ""' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"
  actor="$(jq -r '.actor // ""' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"
  poke="$(jq -r '.poke_sent' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"
  poke_pm_log="$(grep -c 'WATCHDOG-POKE-PM' "$NEED_DIR/or.log" 2>/dev/null || echo "0")"

  if [[ "$reason" == "ACTOR_IDLE" && "$actor" == "pm" && "$poke" == "false" && "$poke_pm_log" -ge 1 ]]; then
    assert_pass
    echo "PASS: TF-005"
  else
    assert_fail "TF-005" "reason=$reason actor=$actor poke=$poke poke_pm_log=$poke_pm_log"
  fi
}

# ─── TF-006 — Désactivation via WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=0 ───────────

tf006() {
  setup_need
  echo '{"entries":[]}' > "$NEED_DIR/ack-registry.json"  # Aucun ACK

  WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=0 run_watchdog

  local reason
  reason="$(jq -r '.reason // ""' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"

  if [[ "$reason" != "ACTOR_IDLE" ]]; then
    assert_pass
    echo "PASS: TF-006"
  else
    assert_fail "TF-006" "reason=$reason (ACTOR_IDLE should be disabled when threshold=0)"
  fi
}

# ─── TF-007 — actor_idle_ticks incrémenté et capé à 2 ───────────────────────

tf007() {
  setup_need
  local old_epoch
  old_epoch="$(date -d '20 minutes ago' +%s 2>/dev/null || date -v-20M +%s)"
  cat > "$NEED_DIR/ack-registry.json" <<EOF
{"entries":[{"from":"po","status":"sent","last_sent_at":$old_epoch}]}
EOF

  # Tick 1
  WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=480 run_watchdog
  # Tick 2 — simule le deuxième tick en gardant le watchdog-state du tick 1
  WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=480 run_watchdog

  local ticks lhts lsticks
  ticks="$(jq -r '.actor_idle_ticks // -1' "$NEED_DIR/.watchdog-state.json" 2>/dev/null || echo "-1")"
  lhts="$(jq -r 'has("last_history_ts")' "$NEED_DIR/.watchdog-state.json" 2>/dev/null || echo "false")"
  lsticks="$(jq -r 'has("stuck_ticks")' "$NEED_DIR/.watchdog-state.json" 2>/dev/null || echo "false")"

  if [[ "$ticks" == "2" && "$lhts" == "true" && "$lsticks" == "true" ]]; then
    assert_pass
    echo "PASS: TF-007"
  else
    assert_fail "TF-007" "actor_idle_ticks=$ticks has_last_history_ts=$lhts has_stuck_ticks=$lsticks"
  fi
}

# ─── TF-008 — Reset actor_idle_ticks quand ACK acteur progresse ──────────────

tf008() {
  setup_need
  local old_epoch
  old_epoch="$(date -d '20 minutes ago' +%s 2>/dev/null || date -v-20M +%s)"
  cat > "$NEED_DIR/ack-registry.json" <<EOF
{"entries":[{"from":"po","status":"sent","last_sent_at":$old_epoch}]}
EOF

  # Tick 1 — génère actor_idle_ticks=1
  WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=480 run_watchdog

  local ticks_after_1
  ticks_after_1="$(jq -r '.actor_idle_ticks // 0' "$NEED_DIR/.watchdog-state.json" 2>/dev/null || echo "0")"

  # Nouvel ACK po (timestamp récent)
  local new_epoch
  new_epoch="$(date +%s)"
  cat > "$NEED_DIR/ack-registry.json" <<EOF
{"entries":[{"from":"po","status":"sent","last_sent_at":$new_epoch}]}
EOF

  # Tick 2 — ACK a progressé → reset
  WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=480 run_watchdog

  local ticks_after_2
  ticks_after_2="$(jq -r '.actor_idle_ticks // -1' "$NEED_DIR/.watchdog-state.json" 2>/dev/null || echo "-1")"

  if [[ "$ticks_after_1" -ge 1 && "$ticks_after_2" == "0" ]]; then
    assert_pass
    echo "PASS: TF-008"
  else
    assert_fail "TF-008" "ticks_after_tick1=$ticks_after_1 ticks_after_ack=$ticks_after_2"
  fi
}

# ─── TF-009 — Priorité idle_post_step_advanced sur ACTOR_IDLE ────────────────

tf009() {
  setup_need
  local old_epoch old_ts
  old_epoch="$(date -d '20 minutes ago' +%s 2>/dev/null || date -v-20M +%s)"
  old_ts="$(date -u -d '20 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-20M +%Y-%m-%dT%H:%M:%SZ)"
  cat > "$NEED_DIR/ack-registry.json" <<EOF
{"entries":[{"from":"po","status":"sent","last_sent_at":$old_epoch}]}
EOF

  # Simuler un step_advanced dans or.log daté de > 120s (sans PLEASE_COMPLETE_STEP postérieur)
  cat > "$NEED_DIR/or.log" <<EOF
{"ts":"$old_ts","type":"step_advanced","step":"INTERVIEW_SPECS"}
EOF

  WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=480 run_watchdog

  local reason
  reason="$(jq -r '.reason // ""' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"

  if [[ "$reason" == "idle_post_step_advanced" ]]; then
    assert_pass
    echo "PASS: TF-009"
  else
    assert_fail "TF-009" "reason=$reason (expected idle_post_step_advanced has priority over ACTOR_IDLE)"
  fi
}

# ─── TF-010 — Rétrocompatibilité HEARTBEAT_STALE non impactée ────────────────

tf010() {
  setup_need
  # heartbeat stale (> 2 min par défaut)
  local old_ts
  old_ts="$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-10M +%Y-%m-%dT%H:%M:%SZ)"
  echo "[$old_ts] OR heartbeat" > "$NEED_DIR/heartbeat.log"

  # ACK po récent → pas de ACTOR_IDLE
  local recent_epoch
  recent_epoch="$(date +%s)"
  cat > "$NEED_DIR/ack-registry.json" <<EOF
{"entries":[{"from":"po","status":"sent","last_sent_at":$recent_epoch}]}
EOF

  WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=480 run_watchdog

  local reason
  reason="$(jq -r '.reason // ""' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"

  if [[ "$reason" == "HEARTBEAT_STALE" ]]; then
    assert_pass
    echo "PASS: TF-010"
  else
    assert_fail "TF-010" "reason=$reason (expected HEARTBEAT_STALE)"
  fi
}

# ─── TF-011 — Skip silencieux quand step inconnu dans STEP_AGENT[] ───────────

tf011() {
  setup_need
  cat > "$NEED_DIR/.wf-state.json" <<EOF
{
  "phase": "UNKNOWN_PHASE",
  "step": "UNKNOWN_STEP",
  "history": [{"agent": "po", "ts": "2020-01-01T00:00:00Z"}]
}
EOF
  echo '{"entries":[]}' > "$NEED_DIR/ack-registry.json"

  local exit_code=0
  WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=1 run_watchdog || exit_code=$?

  local reason
  reason="$(jq -r '.reason // ""' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"

  if [[ "$reason" != "ACTOR_IDLE" && "$exit_code" == "0" ]]; then
    assert_pass
    echo "PASS: TF-011"
  else
    assert_fail "TF-011" "reason=$reason exit_code=$exit_code"
  fi
}

# ─── TF-012 — Skip silencieux pour agent DV ──────────────────────────────────

tf012() {
  setup_need
  # Utiliser CODE_REVIEW:DV_FIX dont agent=dv dans STEP_AGENT
  cat > "$NEED_DIR/.wf-state.json" <<EOF
{
  "phase": "CODE_REVIEW",
  "step": "DV_FIX",
  "history": [{"agent": "dv1", "ts": "2020-01-01T00:00:00Z"}]
}
EOF
  echo '{"entries":[]}' > "$NEED_DIR/ack-registry.json"

  WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=1 run_watchdog

  local reason
  reason="$(jq -r '.reason // ""' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"

  if [[ "$reason" != "ACTOR_IDLE" ]]; then
    assert_pass
    echo "PASS: TF-012"
  else
    assert_fail "TF-012" "reason=$reason (expected skip for dv* actor)"
  fi
}

# ─── TF-013 — ACTOR_IDLE via un ack-registry produit par le VRAI producteur (F-031) ─
# Non-régression : prouve que watchdog et wf-orchestrate --ack-register partagent le
# même schéma ({"entries":[...]} + last_sent_at epoch). Pas de fixture écrite à la main.
tf013() {
  setup_need
  local orch="$script_dir/wf-orchestrate.sh"
  # Le producteur écrit ack-registry.json sous $PROJECT_ROOT/wf/needs/<need>/.
  # On vise le même need que run_watchdog : wf-watchdog-v3/test-fixtures/need.
  WF_PROJECT_ROOT="$project_root" bash "$orch" wf-watchdog-v3/test-fixtures/need \
    --ack-register --from po --to or --msg-id tf013-msg-001 --type step_complete >/dev/null 2>&1
  # Backdate last_sent_at à un epoch ancien (> seuil) en gardant le schéma producteur.
  local old_epoch tmp
  old_epoch="$(date -d '20 minutes ago' +%s 2>/dev/null || date -v-20M +%s)"
  tmp="$NEED_DIR/ack-registry.json.tmp"
  jq --argjson e "$old_epoch" '.entries |= map(.last_sent_at = $e)' \
    "$NEED_DIR/ack-registry.json" > "$tmp" && mv "$tmp" "$NEED_DIR/ack-registry.json"

  WF_WATCHDOG_ACTOR_IDLE_THRESHOLD=480 run_watchdog

  local reason actor schema
  reason="$(jq -r '.reason // ""' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"
  actor="$(jq -r '.actor // ""' "$NEED_DIR/watchdog.alert" 2>/dev/null || echo "")"
  # Garde-fou : le registre doit bien être au schéma producteur (objet .entries).
  schema="$(jq -r '.entries | type' "$NEED_DIR/ack-registry.json" 2>/dev/null || echo "")"

  if [[ "$reason" == "ACTOR_IDLE" && "$actor" == "po" && "$schema" == "array" ]]; then
    assert_pass
    echo "PASS: TF-013"
  else
    assert_fail "TF-013" "reason=$reason actor=$actor schema=$schema (producer-schema ACTOR_IDLE)"
  fi
}

# ─── Run all ──────────────────────────────────────────────────────────────────

echo "=== test-watchdog-v3.sh — TF-001..TF-013 ==="
echo ""

tf001
tf002
tf003
tf004
tf005
tf006
tf007
tf008
tf009
tf010
tf011
tf012
tf013

# Cleanup
rm -rf "$FIXTURE_DIR"

echo ""
echo "=== Results: $pass passed, $fail failed ==="

if [[ "$fail" -gt 0 ]]; then
  for e in "${errors[@]}"; do echo "$e"; done
  exit 1
fi

exit 0
