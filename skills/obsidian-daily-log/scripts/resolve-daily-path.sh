#!/usr/bin/env bash
# resolve-daily-path.sh — print the right way to address a daily note.
#
# Usage:
#   resolve-daily-path.sh              # today
#   resolve-daily-path.sh 2026-05-04   # specific date (YYYY-MM-DD)
#
# Prints one of:
#   daily:append                       — use `obsidian daily:append ...` (no path needed)
#   path=Daily/<YYYY-MM-DD>.md         — use `obsidian append path=... ...`
#
# The first form is preferred because the Obsidian Daily Notes plugin owns
# the date format and folder; the fallback is robust to environments where
# `daily:append` is not available (older CLI versions, plugin disabled).

set -euo pipefail

DATE_ARG="${1:-}"

if [[ -n "$DATE_ARG" ]]; then
  # Caller passed an explicit date — fallback form is the only correct answer,
  # because `daily:append` always targets today.
  echo "path=Daily/${DATE_ARG}.md"
  exit 0
fi

# Probe whether `obsidian daily:append` is supported by the installed CLI.
# `obsidian help daily:append` exits 0 if the subcommand exists, non-zero otherwise.
if command -v obsidian >/dev/null 2>&1 && obsidian help daily:append >/dev/null 2>&1; then
  echo "daily:append"
else
  TODAY="$(date +%F)"
  echo "path=Daily/${TODAY}.md"
fi
