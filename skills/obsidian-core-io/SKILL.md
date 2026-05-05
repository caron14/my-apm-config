---
name: obsidian-core-io
description: Use this skill when the user wants to read, search, append, or create notes in their Obsidian vault via the Obsidian CLI. Trigger phrases include "find my note about X", "what did I write on Y", "add a paragraph to Z note", "create a new note titled …", "search the vault", and Japanese equivalents (ノート, 保管庫, 検索, 追記, ノートを開く, ノートに追記). Owns four CLI commands - `search:context`, `read`, `create`, `append` - plus `prepend` for metadata-adjacent additions. ALWAYS run `search:context` first to locate a target before any `read` or `append`; never guess a path. For existing notes use `append` (or `prepend`); NEVER overwrite an existing path with `create`. Use `format=json` for any output Claude must parse. Do NOT use this skill for Bases / structured records (use obsidian-bases) or for today's daily note / task toggling (use obsidian-daily-log). Disambiguation - when the user says "log this" with no target file, defer to obsidian-daily-log; when they say "add this to my <named> note", that's this skill.
---

# Obsidian Core I/O

Reads, searches, appends, and creates notes in the user's Obsidian vault through the official Obsidian CLI. The CLI talks to a running Obsidian instance over its internal API, so wikilinks, indexes, and frontmatter stay consistent automatically — never manipulate vault files with `cat`, `sed`, or direct filesystem writes.

## When to use

Trigger this skill when the user asks to:

- Find a note by topic ("find my note about X", "search for Y in the vault")
- Read a specific note's contents
- Append content to an existing note
- Create a new (non-daily) note

Trigger phrases (English + 日本語): note, vault, search, append, create note, ノート, 保管庫, 検索, 追記, 新規ノート.

**Hand-offs — do NOT do these here:**
- Querying Bases / `.base` files / structured records → use **obsidian-bases**.
- Logging into today's daily note, toggling tasks, capturing meeting notes → use **obsidian-daily-log**.

**Disambiguation rules:**
- "log this" with no explicit target → obsidian-daily-log.
- "add this to my <named> note" → this skill (`append`).
- "all notes tagged X" → start with `tags` (this skill); escalate to obsidian-bases only if structured properties are needed.

## Mandatory procedure: `search:context` → `read`

Do not skip steps. Hallucinated paths are the most common failure mode for this skill.

1. Run `obsidian search:context query="<terms>" format=json` to find candidate notes with surrounding context. The `context` variant returns excerpts so you can disambiguate without a second round-trip.
2. From the JSON result, pick the path that best matches the user's intent. If zero or multiple plausible candidates exist, ask the user — do not guess.
3. Only now run `obsidian read path="<resolved-path>"` (or `file=<name>` if the name is unique) to fetch the full note.
4. For any append, re-run `read` after the write to verify the structure landed as intended.

**Failure mode (do not do this):**
```
User: "What did I say about A-corp's pricing?"
WRONG: obsidian read file=A-corp                   # guesses a name; may not exist or may collide
RIGHT: obsidian search:context query="A-corp pricing" format=json
       → pick path from results
       → obsidian read path="Clients/A-corp/2026-04 Pricing review.md"
```

## Targeting: `file=` vs `path=` vs active file

| Form | When to use |
| :--- | :--- |
| `file=<name>` | Name is globally unique in the vault. Resolves via wikilink rules. |
| `path=<vault-relative>` | Path came from `search` / `search:context` JSON output. **Preferred for any programmatic use.** |
| (omitted) | Operates on whatever file the user currently has active in the Obsidian UI. Use sparingly — Claude cannot see the UI state. |

For escape rules (spaces, newlines, quotes), see `references/targeting-cheatsheet.md`.

## Append vs prepend vs create

| Action | Use when | Forbidden when |
| :--- | :--- | :--- |
| `append` | Adding content to the **end** of an existing note. Default choice for adding to existing notes. | — |
| `prepend` | Adding content **after frontmatter / properties** but before the body. Use for top-of-note summaries or new sections that should appear first. | — |
| `create` | Creating a **brand new** note at a path that does not already exist. May use `template=<name>` to apply a template. | The path already exists. **Never** overwrite with `create`. If unsure, run `read` first — a successful read means the file exists and you must `append` instead. |

For destructive intent (rename/move), use `move` — it auto-updates all wikilinks across the vault. Do not use shell `mv`.

## Output handling

- Pass `format=json` for any command whose output Claude needs to parse (`search`, `search:context`, `tags`, `links`, `backlinks`, `read` when scripted).
- Pass `--silent` for write-side commands when working in the background, so the user's UI is not interrupted with "note created" notifications.
- Pass `--copy` only if the user explicitly asked for the result on their clipboard.

## Verification

After any `append`, `prepend`, or `create`, immediately run `read` on the same path and confirm:
1. The new content is present.
2. Frontmatter is intact (no accidental clobber).
3. No duplicate sections (e.g., two `## Notes` headings if you intended one).

If verification fails, fix forward — do not silently retry the write.

## Hand-off

For tasks that fall outside this skill's scope, defer to:
- **obsidian-bases** — `.base` files, structured queries, project dashboards, CRM-style records.
- **obsidian-daily-log** — today's daily note, task toggling, meeting capture.

If the user's request spans multiple skills (e.g., "search past notes about A-corp, then log a prep summary"), do the search/read part here and explicitly hand control to the next skill for the logging step.
