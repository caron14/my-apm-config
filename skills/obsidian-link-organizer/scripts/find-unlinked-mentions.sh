#!/usr/bin/env bash
# find-unlinked-mentions.sh — find places where an existing note's title
# appears as plain text but is not yet wrapped in [[…]].
#
# Usage:
#   find-unlinked-mentions.sh                    # MIN_LEN=4 default
#   find-unlinked-mentions.sh MIN_LEN=6          # raise to drop short-title noise
#
# Pipeline:
#   1. obsidian read file=INDEX.md format=json   → vault-master index of all notes.
#   2. extract each note's title (basename without .md).
#   3. for every title T (length ≥ MIN_LEN):
#      obsidian search query="\"T\" -[[T]] -file:\"T.md\"" format=json
#   4. aggregate JSON: { "<source-file>": [{title, snippet}, ...] }
#
# INDEX.md is assumed to live at the vault root and to contain all markdown
# paths (one per line, in any of: bare path, markdown-link `[T](path)`, or list
# item `- path`). The parser is tolerant — it just needs `*.md` paths to appear.
#
# Output: JSON to stdout.

set -euo pipefail

MIN_LEN=4
for arg in "$@"; do
  case "$arg" in
    MIN_LEN=*) MIN_LEN="${arg#MIN_LEN=}" ;;
    *) echo "error: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

for cmd in obsidian jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: required command not found: $cmd" >&2
    exit 127
  fi
done

# 1. Read INDEX.md.
index_json="$(obsidian read file=INDEX.md format=json 2>/dev/null || true)"
if [[ -z "$index_json" ]]; then
  echo "error: could not read INDEX.md from vault root. Run 'obsidian read file=INDEX.md' to verify it exists." >&2
  exit 1
fi

# Pull the body text out of the JSON envelope. Obsidian's read JSON typically
# carries the full text under `.content` or `.body`; we try both.
body="$(echo "$index_json" | jq -r '.content // .body // .text // empty')"
if [[ -z "$body" ]]; then
  echo "error: INDEX.md JSON envelope did not contain a known body field (content/body/text). Inspect with: obsidian read file=INDEX.md format=json" >&2
  exit 1
fi

# 2. Extract titles. Match any *.md path; take the basename, strip extension.
#    Tolerates: `path/to/Foo.md`, `[Foo](path/to/Foo.md)`, `- path/to/Foo.md`.
mapfile -t titles < <(
  echo "$body" \
    | grep -oE '[^[:space:]"()]+\.md' \
    | awk -F/ '{print $NF}' \
    | sed 's/\.md$//' \
    | awk -v min="$MIN_LEN" 'length($0) >= min' \
    | sort -u
)

if [[ ${#titles[@]} -eq 0 ]]; then
  echo "{}"
  exit 0
fi

# 3. Run a search per title and aggregate. Each per-title result is a JSON
#    array of hits; each hit has a `path` and a `text`/`snippet` field. Shapes
#    vary slightly across CLI versions, so we normalize defensively.
agg='{}'
for title in "${titles[@]}"; do
  # Escape double quotes in the title for the embedded query.
  esc_title="${title//\"/\\\"}"
  query="\"${esc_title}\" -[[${esc_title}]] -file:\"${esc_title}.md\""

  hits="$(obsidian search query="$query" format=json 2>/dev/null || echo '[]')"
  [[ -z "$hits" ]] && hits='[]'

  agg="$(jq -c \
    --arg title "$title" \
    --argjson hits "$hits" \
    '
      ($hits | if type == "array" then . else (.results // .matches // []) end) as $list
      | reduce $list[] as $h (.;
          ($h.path // $h.file // $h.source // "unknown") as $src
          | ($h.snippet // $h.text // $h.context // "") as $snip
          | .[$src] += [{title: $title, snippet: $snip}]
        )
    ' <<< "$agg")"
done

echo "$agg" | jq '.'
