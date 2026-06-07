#!/usr/bin/env bats
# Characterisation tests for PROJECT_ROOT resolution (F-030 / F-032).
# Locks the CURRENT behaviour of _wf_resolve_project_root (scripts/lib/wf-paths.sh)
# and the loud STATE_NOT_FOUND error path of wf-orchestrate.sh --query. This is a
# non-regression net for ARCH-10 — it records observed behaviour, not an ideal.
#
# The lib function is exercised by SOURCING it directly in a subshell from a
# constructed temp tree, since its only inputs are WF_PROJECT_ROOT + pwd.
# The STATE_NOT_FOUND path is exercised via the shared helper (WF_SCRIPT).
#
# Invocation: bats tests/wf-orchestrate-paths.bats

load wf-orchestrate-helper

setup()    { wf_proj_init; }
teardown() { wf_proj_cleanup; }

WF_PATHS_LIB="$WF_REPO/scripts/lib/wf-paths.sh"

# Resolve the lib function from a given cwd with WF_PROJECT_ROOT unset.
# $1 = cwd to run from, $2 = need name (may be empty)
resolve_from() {
  local cwd="$1" name="${2:-}"
  bash -c "unset WF_PROJECT_ROOT; source '$WF_PATHS_LIB'; cd '$cwd'; _wf_resolve_project_root '$name'"
}

# ── (a) explicit WF_PROJECT_ROOT wins, returned verbatim ─────────────────────
@test "resolve: explicit WF_PROJECT_ROOT is returned verbatim, ignoring cwd/tree" {
  local tree="$BATS_TEST_TMPDIR/a/sub/dir"
  mkdir -p "$tree"
  run bash -c "export WF_PROJECT_ROOT='/explicit/anchor'; source '$WF_PATHS_LIB'; cd '$tree'; _wf_resolve_project_root some-need"
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$output" = "/explicit/anchor" ]
}

# ── (b) walk up to the dir holding wf/needs/<name>/.wf-state.json ─────────────
@test "resolve: walks up from a deep subdir to the root holding the need state file" {
  local root="$BATS_TEST_TMPDIR/b_proj"
  mkdir -p "$root/wf/needs/myneed"
  printf '{}\n' > "$root/wf/needs/myneed/.wf-state.json"
  local deep="$root/x/y/z/deep"
  mkdir -p "$deep"
  run resolve_from "$deep" myneed
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$output" = "$root" ]
}

# ── (c) marker .wf-config.json without the need → returns the marker root ─────
@test "resolve: falls back to the .wf-config.json marker root when the need is absent" {
  local root="$BATS_TEST_TMPDIR/c_proj"
  mkdir -p "$root/x/y"
  printf '{}\n' > "$root/.wf-config.json"
  run resolve_from "$root/x/y" absent-need
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$output" = "$root" ]
}

# ── (d) no marker anywhere up the tree → returns pwd ─────────────────────────
@test "resolve: with no marker in the tree, returns the current working dir (pwd)" {
  local bare="$BATS_TEST_TMPDIR/d_bare/empty/here"
  mkdir -p "$bare"
  run resolve_from "$bare" whatever
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  [ "$output" = "$bare" ]
}

# ── F-030: --query on an unknown need from a no-project cwd → loud error ──────
# Must NOT return a phantom BOOTSTRAP:DETERMINE_NAME at exit 0 (the OBS-009 bug).
@test "query: unknown need from a project-less cwd fails loudly with STATE_NOT_FOUND" {
  # A marker-free dir under BATS_TEST_TMPDIR (no .wf-config.json / wf/needs in
  # any ancestor, since BATS_TEST_TMPDIR lives under /tmp). WF_PROJECT_ROOT is
  # unset so the resolver falls back to the pwd walk-up and finds nothing.
  local bare="$BATS_TEST_TMPDIR/noproj/deep"
  mkdir -p "$bare"
  run bash -c "unset WF_PROJECT_ROOT; cd '$bare'; bash '$WF_SCRIPT' ghost-need --query 2>&1"
  echo "# status=$status out=$output" >&3
  [ "$status" -ne 0 ]
  echo "$output" | grep -q STATE_NOT_FOUND
  # And explicitly NOT the phantom default
  ! echo "$output" | grep -q DETERMINE_NAME
}

# ── Contrast: a genuine project root DOES emit the pre-bootstrap default ──────
# Pins the OTHER half of the F-030 branch: from inside a real project (marker
# present) an unknown need still yields BOOTSTRAP:DETERMINE_NAME at exit 0.
@test "query: unknown need from a genuine project root yields phantom DETERMINE_NAME exit 0" {
  local root="$BATS_TEST_TMPDIR/real_proj"
  mkdir -p "$root"
  printf '{}\n' > "$root/.wf-config.json"
  run bash -c "unset WF_PROJECT_ROOT; cd '$root'; bash '$WF_SCRIPT' ghost-need --query 2>&1"
  echo "# status=$status out=$output" >&3
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"step":"DETERMINE_NAME"'
  echo "$output" | grep -q '"phase":"BOOTSTRAP"'
}
