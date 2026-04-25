#!/usr/bin/env bash
# wf-render-html.sh — Markdown→HTML (pandoc if available, otherwise bash fallback)
# ADR-003: dual strategy with no mandatory dependency.
# Fallback: does not handle exotic markdown edge-cases (nested blockquotes, footnotes).
#
# Usage: wf-render-html.sh <input.md> <output.html>
# Exit 0: HTML written successfully.
# Exit 1: missing input or args.

set -euo pipefail

# ---------------------------------------------------------------------------
# Minimal bash fallback (sed/awk) — used if pandoc is missing
# ---------------------------------------------------------------------------
_render_fallback() {
  local src="$1"
  local dst="$2"
  local title
  title="$(basename "$src" .md)"

  # Bundled CSS: sans-serif typo, light gray code, bordered table
  cat > "$dst" <<'CSS_EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
CSS_EOF

  printf '<title>%s</title>\n' "$title" >> "$dst"

  cat >> "$dst" <<'STYLE_EOF'
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
         max-width: 900px; margin: 2rem auto; padding: 0 1rem; color: #222; line-height: 1.6; }
  h1 { font-size: 1.8rem; border-bottom: 2px solid #ddd; padding-bottom: .4rem; }
  h2 { font-size: 1.4rem; border-bottom: 1px solid #eee; padding-bottom: .2rem; margin-top: 2rem; }
  h3 { font-size: 1.15rem; margin-top: 1.5rem; }
  h4, h5, h6 { font-size: 1rem; margin-top: 1rem; }
  code { background: #f0f0f0; padding: .15em .4em; border-radius: 3px; font-size: .9em; font-family: "SFMono-Regular", Consolas, monospace; }
  pre { background: #f5f5f5; padding: 1rem; border-radius: 4px; overflow-x: auto; border: 1px solid #e0e0e0; }
  pre code { background: none; padding: 0; }
  table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
  th, td { border: 1px solid #ccc; padding: .5rem .75rem; text-align: left; }
  th { background: #f0f0f0; font-weight: 600; }
  tr:nth-child(even) td { background: #fafafa; }
  blockquote { border-left: 4px solid #ccc; margin: 1rem 0; padding: .5rem 1rem; color: #555; }
  ul, ol { padding-left: 1.5rem; }
  li { margin: .2rem 0; }
  hr { border: none; border-top: 1px solid #ddd; margin: 2rem 0; }
  a { color: #0070f3; text-decoration: none; }
  a:hover { text-decoration: underline; }
</style>
</head>
<body>
STYLE_EOF

  # Markdown → HTML conversion via awk
  # Handles: h1-h6, ul/ol lists, code blocks, inline code, GFM tables, bold, italic, links, hr
  awk '
  BEGIN {
    in_pre = 0
    in_table = 0
    in_ul = 0
    in_ol = 0
    blank_before = 1
  }

  function close_lists() {
    if (in_ul) { print "</ul>"; in_ul = 0 }
    if (in_ol) { print "</ol>"; in_ol = 0 }
  }

  function close_table() {
    if (in_table) { print "</tbody></table>"; in_table = 0 }
  }

  function escape_html(s,    r) {
    r = s
    gsub(/&/, "\\&amp;", r)
    gsub(/</, "\\&lt;", r)
    gsub(/>/, "\\&gt;", r)
    return r
  }

  function inline_format(s,    r) {
    r = escape_html(s)
    # inline code (before bold/italic to avoid conflict)
    while (match(r, /`[^`]+`/)) {
      pre = substr(r, 1, RSTART-1)
      code = substr(r, RSTART+1, RLENGTH-2)
      post = substr(r, RSTART+RLENGTH)
      r = pre "<code>" code "</code>" post
    }
    # bold **text** (no backreference in awk — manual loop)
    while (match(r, /\*\*[^*]+\*\*/)) {
      pre = substr(r, 1, RSTART-1)
      inner = substr(r, RSTART+2, RLENGTH-4)
      post = substr(r, RSTART+RLENGTH)
      r = pre "<strong>" inner "</strong>" post
    }
    while (match(r, /__[^_]+__/)) {
      pre = substr(r, 1, RSTART-1)
      inner = substr(r, RSTART+2, RLENGTH-4)
      post = substr(r, RSTART+RLENGTH)
      r = pre "<strong>" inner "</strong>" post
    }
    # italic *text*
    while (match(r, /\*[^*]+\*/)) {
      pre = substr(r, 1, RSTART-1)
      inner = substr(r, RSTART+1, RLENGTH-2)
      post = substr(r, RSTART+RLENGTH)
      r = pre "<em>" inner "</em>" post
    }
    # italic _text_ (avoid false positives in URLs/code)
    while (match(r, /_[^_]+_/)) {
      pre = substr(r, 1, RSTART-1)
      inner = substr(r, RSTART+1, RLENGTH-2)
      post = substr(r, RSTART+RLENGTH)
      r = pre "<em>" inner "</em>" post
    }
    # links [text](url)
    while (match(r, /\[[^]]+\]\([^)]+\)/)) {
      pre = substr(r, 1, RSTART-1)
      m = substr(r, RSTART, RLENGTH)
      post = substr(r, RSTART+RLENGTH)
      # extract text and url
      txt = m; sub(/\].*/, "", txt); sub(/^\[/, "", txt)
      url = m; sub(/.*\(/, "", url); sub(/\)$/, "", url)
      r = pre "<a href=\"" url "\">" txt "</a>" post
    }
    return r
  }

  # Fenced code blocks ```
  /^```/ {
    if (!in_pre) {
      close_lists()
      close_table()
      lang = $0; sub(/^```/, "", lang); gsub(/[[:space:]]/, "", lang)
      if (lang != "") print "<pre><code class=\"language-" lang "\">"
      else print "<pre><code>"
      in_pre = 1
    } else {
      print "</code></pre>"
      in_pre = 0
    }
    next
  }

  in_pre {
    # inside a code block, just HTML-escape
    print escape_html($0)
    next
  }

  # Blank line
  /^[[:space:]]*$/ {
    close_lists()
    close_table()
    blank_before = 1
    next
  }

  # Horizontal rule --- or ***
  /^(---+|\*\*\*+)[[:space:]]*$/ {
    close_lists()
    close_table()
    print "<hr>"
    blank_before = 1
    next
  }

  # Headers
  /^###### / { close_lists(); close_table(); sub(/^###### /, ""); print "<h6>" inline_format($0) "</h6>"; blank_before=0; next }
  /^##### /  { close_lists(); close_table(); sub(/^##### /,  ""); print "<h5>" inline_format($0) "</h5>"; blank_before=0; next }
  /^#### /   { close_lists(); close_table(); sub(/^#### /,   ""); print "<h4>" inline_format($0) "</h4>"; blank_before=0; next }
  /^### /    { close_lists(); close_table(); sub(/^### /,    ""); print "<h3>" inline_format($0) "</h3>"; blank_before=0; next }
  /^## /     { close_lists(); close_table(); sub(/^## /,     ""); print "<h2>" inline_format($0) "</h2>"; blank_before=0; next }
  /^# /      { close_lists(); close_table(); sub(/^# /,      ""); print "<h1>" inline_format($0) "</h1>"; blank_before=0; next }

  # Unordered lists
  /^[[:space:]]*[-*+] / {
    close_table()
    if (!in_ul) { if (in_ol) { print "</ol>"; in_ol=0 }; print "<ul>"; in_ul=1 }
    sub(/^[[:space:]]*[-*+] /, "")
    print "<li>" inline_format($0) "</li>"
    blank_before=0; next
  }

  # Ordered lists
  /^[[:space:]]*[0-9]+\. / {
    close_table()
    if (!in_ol) { if (in_ul) { print "</ul>"; in_ul=0 }; print "<ol>"; in_ol=1 }
    sub(/^[[:space:]]*[0-9]+\. /, "")
    print "<li>" inline_format($0) "</li>"
    blank_before=0; next
  }

  # GFM tables: separator row (|---|---|) ignored
  /^\|[-| :]+\|[[:space:]]*$/ {
    next
  }

  # GFM tables: data rows
  /^\|/ {
    close_lists()
    if (!in_table) {
      print "<table><thead>"
      # first row = header
      line = $0
      gsub(/^\||\|$/, "", line)
      n = split(line, cells, "|")
      printf "<tr>"
      for (i=1; i<=n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cells[i])
        printf "<th>%s</th>", inline_format(cells[i])
      }
      print "</tr></thead><tbody>"
      in_table = 1
    } else {
      line = $0
      gsub(/^\||\|$/, "", line)
      n = split(line, cells, "|")
      printf "<tr>"
      for (i=1; i<=n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cells[i])
        printf "<td>%s</td>", inline_format(cells[i])
      }
      print "</tr>"
    }
    blank_before=0; next
  }

  # Paragraph
  {
    close_table()
    if (in_ul || in_ol) {
      # list continuation? No — close
      close_lists()
    }
    print "<p>" inline_format($0) "</p>"
    blank_before=0
  }

  END {
    close_lists()
    close_table()
    if (in_pre) print "</code></pre>"
  }
  ' "$src" >> "$dst"

  cat >> "$dst" <<'FOOTER_EOF'
</body>
</html>
FOOTER_EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
INPUT="${1:-}"
OUTPUT="${2:-}"

if [[ -z "$INPUT" || -z "$OUTPUT" ]]; then
  echo "Usage: wf-render-html.sh <input.md> <output.html>" >&2
  exit 1
fi

if [[ ! -f "$INPUT" ]]; then
  echo "Error: source file not found: $INPUT" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"

if command -v pandoc >/dev/null 2>&1; then
  pandoc \
    --from=gfm \
    --to=html5 \
    --standalone \
    --toc \
    --highlight-style=tango \
    --metadata title="$(basename "$INPUT" .md)" \
    --output="$OUTPUT" \
    "$INPUT"
else
  _render_fallback "$INPUT" "$OUTPUT"
fi
