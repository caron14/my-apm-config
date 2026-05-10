---
name: obsidian-link-organizer
description: Use this skill when the user wants to audit, repair, or strengthen the internal-link graph of their Obsidian vault — broken (unresolved) wikilinks, unlinked mentions of existing notes, and orphan notes with zero backlinks. Trigger phrases include "find broken links", "fix dead links", "find unlinked mentions of X", "what notes have no backlinks", "vault link cleanup", "organize internal links", and Japanese equivalents (リンク切れ, デッドリンク, 内部リンク, 未リンク言及, 孤立ノート, リンク整理, バックリンク, リンク監査). Owns three CLI-driven workflows backed by `obsidian unresolved`, `obsidian search`, and `obsidian eval`. ALWAYS detect → propose → confirm with the user → THEN hand actual writes off to obsidian-core-io's `append` / `prepend` (or `obsidian eval` for in-place modify). NEVER auto-rewrite note bodies without explicit user approval. Do NOT use this skill for general note read/write (use obsidian-core-io) or daily-log capture (use obsidian-daily-log). Disambiguation — "find my note about X" → obsidian-core-io; "what links to X" / "is X orphaned" / "are there mentions of X I never linked" → this skill; "remove a specific link from a note" → propose here, apply via obsidian-core-io.
---

# Obsidian Link Organizer

Audits and repairs the internal-link graph of the user's Obsidian vault. Three independent workflows:

1. **Broken-link sweep** — finds wikilinks that point to non-existent notes (`[[Renamed Note]]` after the rename).
2. **Unlinked-mention discovery** — finds places where an existing note's title appears as plain text but is not yet wrapped in `[[…]]`.
3. **Orphan-note detection** — finds notes with zero backlinks, candidates to wire into a MOC / index.

All three are detection-only. Writes happen separately, after the user reviews the candidates.

## When to use

Trigger this skill when the user says (any of):

- "Find broken links" / "fix dead links" / "リンク切れ" / "デッドリンク"
- "Find unlinked mentions of `<note>`" / "未リンク言及"
- "What notes have no backlinks" / "孤立ノートを見つけて"
- "Vault link cleanup" / "リンク整理" / "内部リンクを点検して"

Trigger phrases (English + 日本語): broken link, dead link, unresolved, orphan, backlink, mention, link audit, リンク切れ, デッドリンク, 未リンク言及, 孤立ノート, リンク監査, 内部リンク.

## Disambiguation

| User said | Skill |
| :--- | :--- |
| "Find my note about X" | obsidian-core-io |
| "What links to X" / "is X orphaned" | **this skill** |
| "Remove the link to X from note Y" | propose here, apply via obsidian-core-io |
| "Log this in today's note" | obsidian-daily-log |
| "Vault link cleanup" / "リンク整理" | **this skill** |

If genuinely ambiguous, ask the user once.

## CLI argument syntax — read this before writing any command

The Obsidian CLI uses `key=value` form, **not** `--flag=value`. The only `--` flags are `--silent` and `--copy`. This trips users up because shell tools usually do the opposite.

| Wrong | Right |
| :--- | :--- |
| `obsidian unresolved --format=json` | `obsidian unresolved format=json` |
| `obsidian search "Project A"` (positional) | `obsidian search query="Project A"` |
| `obsidian outgoing-links file="X.md"` | `obsidian links file="X.md"` |
| `app.metadataCache.getBacklinks()` (vault-wide) | per-file only — call `getBacklinksForFile(file)` for each file via `obsidian eval` |

`format=json` support is per-subcommand. If a subcommand rejects it, parse the human-readable output (the scripts in this skill fall back automatically). See `references/cli-link-commands.md` for verified per-command syntax.

## Three workflows

### 1. Broken-link sweep (`obsidian unresolved`)

```bash
bash scripts/find-unresolved-links.sh
```

Output (JSON): `{ "<source-path>": ["<missing-target>", ...], ... }`, sorted by number of broken links per source file (descending).

Per source file, classify each broken link with the user:
- (a) Renamed → repoint to the new path (the agent proposes the new wikilink, user confirms).
- (b) Deleted → remove the wikilink, leaving the surrounding text.
- (c) New note → create the missing target via `obsidian-core-io` `create`.

Apply via `obsidian-core-io` (`append` / `prepend` for additive changes, `obsidian eval` + `app.vault.modify(…)` for inline edits). Never run `sed` or write the file directly.

### 2. Unlinked-mention discovery (`obsidian search`, seeded by `INDEX.md`)

```bash
bash scripts/find-unlinked-mentions.sh             # MIN_LEN=4 default
bash scripts/find-unlinked-mentions.sh MIN_LEN=6   # less noise
```

Reads `INDEX.md` from the vault root (the user's master index of all notes' paths and 1-line summaries), extracts each registered note's title, then for every title `T` runs:

```text
obsidian search query="\"T\" -[[T]] -file:\"T.md\"" format=json
```

The Obsidian search query syntax means: contains literal `T`, but is not already a wikilink to `T`, and is not the file `T.md` itself.

Output (JSON): `{ "<source-file>": [{title, snippet}, ...] }`.

**Expected noise.** Filter the candidates with the user before applying:
- skip mentions inside code blocks (`` ``` `` fences) — they are usually intentional non-links;
- skip mentions inside H1 / H2 (the title of the source note itself);
- skip self-mentions (the script already does this via the `-file:` filter, but double-check after edits);
- short titles (≤ 3 chars) collide with English words — increase `MIN_LEN` or hand-pick.

Once approved, two application modes (the agent picks per case):
- **Inline wrap** — most accurate, but requires `obsidian eval app.vault.modify(file, newContent)` because no `replace` subcommand exists.
- **Conservative footer** — append a `## Related` section listing `[[T]]` references via `obsidian-core-io` `append`. Less invasive when the user is unsure.

### 3. Orphan-note detection (`obsidian eval`)

```bash
bash scripts/find-orphan-notes.sh
```

Output (JSON array): vault-relative paths of notes with zero backlinks.

Per orphan, propose the closest MOC / index note (by inspecting `INDEX.md` and adjacent folder structure). After the user picks a target MOC, append a `[[orphan-note]]` reference to it via `obsidian-core-io` `append`.

For a deeper-level reorganization (move the orphan to a different folder, rename it), use `obsidian move` from `obsidian-core-io` — it auto-rewrites all wikilinks across the vault.

## Detect → propose → apply (responsibility boundary)

This skill stops at "here are the candidates". The actual write is always:
1. The agent summarizes the candidates and recommends specific edits.
2. User confirms (or selects a subset).
3. The agent routes the write through `obsidian-core-io` (`append`, `prepend`, `create`, `move`) or `obsidian eval` (for `app.vault.modify`).

**Never** run `sed`, `cat >`, `>>`, or any direct filesystem write against vault files. The CLI keeps Obsidian's metadata cache, wikilink resolution, and index plugins consistent; bypassing it desynchronizes the graph.

## Output handling

- Pass `format=json` to detection commands (`unresolved`, `search`, `links`, `backlinks`) so the agent can parse the result.
- Pass `--silent` on the eventual write commands (`append`, `prepend`, `create`, `move`) to suppress UI notifications during bulk fixes.
- Pass `--copy` only if the user asked for the result on their clipboard.

## Verification

After any batch of fixes:

1. Re-run the relevant detector. The fixed entries must be gone:
   - Broken-link fix → `find-unresolved-links.sh` no longer lists that target.
   - Unlinked-mention fix → `obsidian search query="\"T\" -[[T]]"` returns one fewer result for `T`.
   - Orphan reconnection → `obsidian backlinks file="<orphan>"` returns ≥ 1 backlink.
2. Spot-check one edited file via `obsidian read path="<edited-path>"` (use obsidian-core-io). Confirm:
   - The new wikilink rendered correctly (`[[X]]`).
   - The surrounding paragraph is intact (no orphan punctuation, no doubled words).
   - Frontmatter untouched.

If verification fails, fix forward — do not silently retry the write.

## Hand-off

- Reading or writing the prose body of a single note → **obsidian-core-io** (`read`, `append`, `prepend`, `create`, `move`).
- Logging the audit summary into today's daily note → **obsidian-daily-log** (`daily:append`).
- Running the actual `app.vault.modify` JS for inline rewrites → **obsidian-core-io** owns the `obsidian eval` invocation; this skill only proposes the JS payload.

A common multi-skill flow ("clean up the vault's link graph this week"):

```
1. find-unresolved-links.sh                  → broken-link list  (this skill)
2. find-unlinked-mentions.sh MIN_LEN=5       → mention candidates (this skill)
3. find-orphan-notes.sh                      → orphan list       (this skill)
4. propose grouped fixes per source file     → Agent
5. user approves a subset                    → user
6. apply via append / prepend / move / eval  → obsidian-core-io
7. log audit summary                         → obsidian-daily-log
```
