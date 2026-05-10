#!/usr/bin/env bash
# find-orphan-notes.sh — list vault notes with zero backlinks.
#
# Usage:
#   find-orphan-notes.sh
#
# Output (JSON array to stdout):
#   ["Inbox/foo.md", "Research/bar_g.md", ...]
#
# Implementation: one obsidian eval call. The Obsidian CLI has no vault-wide
# backlinks subcommand, so we walk the vault inside JS and filter on
# metadataCache.getBacklinksForFile(file).data being empty.
#
# Caveat: Obsidian must be running and its metadata cache must be warm. If
# Obsidian was just launched or just finished re-indexing, results may be
# stale. Re-run after a few seconds if the count looks off.

set -euo pipefail

if ! command -v obsidian >/dev/null 2>&1; then
  echo "error: obsidian CLI not found in PATH." >&2
  exit 127
fi

obsidian eval code='JSON.stringify(
  app.vault.getMarkdownFiles()
    .filter(f => Object.keys(app.metadataCache.getBacklinksForFile(f).data).length === 0)
    .map(f => f.path)
)'
