#!/usr/bin/env bash
# wf-segments.sh — Helper for managing session_segments in .wf-state.json
# Exposes: _seg_open <state_file>  _seg_close <state_file>
# Atomic mutations via jq + tmp + mv.

_seg_open() {
  local state_file="$1"
  [[ -z "$state_file" || ! -f "$state_file" ]] && return 1

  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local tmp="${state_file}.tmp"

  # Auto-heal: if a segment is already open, close it first
  local has_open
  has_open="$(jq -r '[ .session_segments[]? | select(.end == null) ] | length' "$state_file" 2>/dev/null || echo 0)"

  if [[ "$has_open" -gt 0 ]]; then
    # Close the open segment at now
    jq --arg now "$now" '
      .session_segments = [
        .session_segments[]?
        | if .end == null then .end = $now else . end
      ]
    ' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
  fi

  # Append a new open segment
  jq --arg start "$now" '
    .session_segments = ((.session_segments // []) + [{"start": $start, "end": null}])
  ' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
}

_seg_close() {
  local state_file="$1"
  [[ -z "$state_file" || ! -f "$state_file" ]] && return 1

  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local tmp="${state_file}.tmp"

  jq --arg now "$now" '
    .session_segments = [
      .session_segments[]?
      | if .end == null then .end = $now else . end
    ]
  ' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
}
