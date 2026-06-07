# wf-orchestrate-helper.bash — shared setup for wf-orchestrate.sh state-machine tests.
#
# Each test runs against an ISOLATED, git-initialised fake project under
# BATS_TEST_TMPDIR, pointed to via WF_PROJECT_ROOT (the resolver honours it first).
# No pollution of the real wf/needs/, no git noise in the actual repo.
#
# Usage in a .bats file:
#   load wf-orchestrate-helper
#   setup()    { wf_proj_init; }
#   teardown() { wf_proj_cleanup; }
#   @test "..." {
#     wf_mk_need foo '{"phase":"REVIEW","step":"RV_REVIEW","status":"in_progress"}'
#     run wf_run foo --query
#     [ "$status" -eq 0 ]
#     [ "$(wf_step foo)" = "REVIEW:RV_REVIEW" ]
#   }

WF_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF_SCRIPT="$WF_REPO/scripts/wf-orchestrate.sh"

# Create + git-init an isolated project root for the current test.
wf_proj_init() {
  WF_PROJ="${BATS_TEST_TMPDIR:-/tmp}/wfproj"
  rm -rf "$WF_PROJ"
  mkdir -p "$WF_PROJ"
  git init -q "$WF_PROJ" 2>/dev/null
  git -C "$WF_PROJ" config user.email t@t.t 2>/dev/null
  git -C "$WF_PROJ" config user.name wf-test 2>/dev/null
  export WF_PROJECT_ROOT="$WF_PROJ"
}

# Write a need state file under the isolated project.
# $1 = need name, $2 = JSON content of .wf-state.json
wf_mk_need() {
  local name="$1" json="$2"
  mkdir -p "$WF_PROJ/wf/needs/$name"
  printf '%s\n' "$json" > "$WF_PROJ/wf/needs/$name/.wf-state.json"
}

# Write an artifact file inside a need dir. $1=need $2=filename $3=content
wf_mk_artifact() {
  local name="$1" file="$2" content="${3:-content}"
  mkdir -p "$WF_PROJ/wf/needs/$name"
  printf '%s\n' "$content" > "$WF_PROJ/wf/needs/$name/$file"
}

# Invoke wf-orchestrate for a need: run wf_run <name> <args...>
wf_run() {
  local name="$1"; shift
  bash "$WF_SCRIPT" "$name" "$@"
}

# Read a top-level field from a need's state file.
wf_field() {
  jq -r --arg k "$2" '.[$k] // ""' "$WF_PROJ/wf/needs/$1/.wf-state.json"
}

# "PHASE:STEP" of a need from its state file.
wf_step() {
  jq -r '"\(.phase):\(.step)"' "$WF_PROJ/wf/needs/$1/.wf-state.json"
}

wf_proj_cleanup() { [ -n "${WF_PROJ:-}" ] && rm -rf "$WF_PROJ"; }
