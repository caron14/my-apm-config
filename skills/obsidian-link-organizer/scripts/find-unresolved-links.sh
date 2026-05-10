#!/usr/bin/env bash
# find-unresolved-links.sh — list wikilinks that point to non-existent notes.
#
# Usage:
#   find-unresolved-links.sh
#
# Output (JSON to stdout):
#   { "<source-path>": ["<missing-target>", ...], ... }
#
# Sorted by number of broken links per source file (descending) when jq is available.
# Falls back to raw human-readable output when jq is missing or `format=json` is
# rejected by the installed Obsidian CLI version.

set -euo pipefail

if ! command -v obsidian >/dev/null 2>&1; then
  echo "error: obsidian CLI not found in PATH. Enable it under Obsidian → Settings → General → Command line interface." >&2
  exit 127
fi

raw_json=""
if raw_json="$(obsidian unresolved format=json 2>/dev/null)" && [[ -n "$raw_json" ]]; then
  if command -v jq >/dev/null 2>&1; then
    # Sort source files by descending broken-link count.
    echo "$raw_json" | jq 'to_entries
      | sort_by(.value | length) | reverse
      | from_entries'
  else
    echo "$raw_json"
  fi
  exit 0
fi

# Fallback — `format=json` not supported on this CLI version. Parse human output.
# Expected human format (one entry per line, illustrative):
#   Projects/Alpha.md → Project Beta
#   Inbox/2026-04 notes.md → Project Beta
#
# Adjust the awk delimiter if your CLI prints with a different separator.

raw_text="$(obsidian unresolved 2>/dev/null || true)"
if [[ -z "$raw_text" ]]; then
  echo "{}"
  exit 0
fi

if command -v jq >/dev/null 2>&1; then
  printf '%s\n' "$raw_text" \
    | awk -F ' → ' 'NF == 2 { printf "%s\t%s\n", $1, $2 }' \
    | jq -Rn '
        [inputs | split("\t") | {source: .[0], target: .[1]}]
        | group_by(.source)
        | map({key: .[0].source, value: (map(.target))})
        | sort_by(.value | length) | reverse
        | from_entries'
else
  # Last-ditch fallback: print raw text. The caller can grep / parse it.
  echo "$raw_text"
fi
