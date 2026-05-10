#!/usr/bin/env bash
# resolve-daily-path.sh — print the right way to address a daily note.
#
# Usage:
#   resolve-daily-path.sh              # today
#   resolve-daily-path.sh 2026-05-04   # specific date (YYYY-MM-DD)
#
# Prints:
#   path=Daily/YYYYMMDD.md
#
# This script is locked to the vault's directory structure (Daily).

set -euo pipefail

DATE_ARG="${1:-}"

if [[ -n "$DATE_ARG" ]]; then
  # YYYY-MM-DD → YYYYMMDD
  COMPACT_DATE="${DATE_ARG//-/}"
  echo "path=Daily/${COMPACT_DATE}.md"
  exit 0
fi

TODAY="$(date +%Y%m%d)"
echo "path=Daily/${TODAY}.md"

