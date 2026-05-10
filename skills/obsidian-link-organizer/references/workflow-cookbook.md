# Workflow cookbook

Step-by-step recipes for the three link-hygiene workflows. Each recipe is detect → review → apply. The detection step is automated; the review and application steps belong to the agent + the user.

## Recipe 1 — Broken-link cleanup

### Detect

```bash
bash scripts/find-unresolved-links.sh
```

Output:

```json
{
  "Projects/Alpha.md": ["Project Beta", "Old Vendor List"],
  "Inbox/2026-04 notes.md": ["Project Beta"]
}
```

The same target appearing in multiple sources usually means a single rename or deletion that was never fixed up.

### Review (Agent)

For each broken target, classify it:

| Class | Signal | Action |
| :--- | :--- | :--- |
| Renamed | A note with a similar title now exists | Repoint: `[[Old Name]]` → `[[New Name]]` |
| Deleted | No comparable note exists, target genuinely gone | Strip the wikilink, keep surrounding text |
| Never created | The target was always aspirational / placeholder | Create the missing note via `obsidian create`, or strip if no longer relevant |

To check whether a similar note exists, use:

```bash
obsidian search query="\"Project Beta\"" format=json
```

If the search hits a single likely candidate, propose a repoint. If it hits multiple, ask the user.

### Apply

Per affected source file, prepare a concrete plan:

```text
Projects/Alpha.md
  - "[[Project Beta]]" appears 3 times (lines 12, 47, 89)
    → repoint to [[Project Beta v2]]   (matched via search)
  - "[[Old Vendor List]]" appears 1 time (line 31)
    → strip (target genuinely deleted, decided 2026-02)
```

After user approval, route writes through obsidian-core-io. For inline replacement (no `replace` subcommand exists), use `obsidian eval`:

```bash
# Inline repoint (run via obsidian-core-io)
obsidian eval code="
  const f = app.vault.getAbstractFileByPath('Projects/Alpha.md');
  const src = await app.vault.read(f);
  const out = src.replace(/\[\[Project Beta\]\]/g, '[[Project Beta v2]]');
  await app.vault.modify(f, out);
"
```

For a stripped link, replace `[[Old Vendor List]]` with the bare text `Old Vendor List` (or empty, depending on what reads naturally — review the surrounding sentence).

Re-run `find-unresolved-links.sh` to verify the fixed entries are gone.

## Recipe 2 — Unlinked-mention pass

### Detect

```bash
bash scripts/find-unlinked-mentions.sh             # MIN_LEN=4 default
bash scripts/find-unlinked-mentions.sh MIN_LEN=6   # less noise; long titles only
```

Output:

```json
{
  "Inbox/2026-05 brain dump.md": [
    {"title": "Project Beta v2", "snippet": "...mentioned Project Beta v2 in passing..."},
    {"title": "<Person Name>",    "snippet": "...met with <Person Name> yesterday..."}
  ],
  "Daily/20260501.md": [
    {"title": "Project Beta v2", "snippet": "...status update on Project Beta v2..."}
  ]
}
```

### Review (Agent)

The unlinked-mention pass is noisy by design. Filter aggressively before proposing edits:

| Filter | Why |
| :--- | :--- |
| Skip mentions inside fenced code blocks | Code rarely benefits from wikilink wrapping |
| Skip mentions inside H1/H2 of the source note | Headings already act as titles; wrapping makes them ugly |
| Skip self-mentions | The note titled `Project Beta v2.md` mentioning "Project Beta v2" is just its own title |
| Skip ambiguous matches | Titles that are common English words (e.g., "Notes", "Index", "Today") will false-positive everywhere |

For each surviving candidate, decide between two application modes:

**(a) Inline wrap (preferred when the mention is in body prose):**

```js
// Wrap "Project Beta v2" → "[[Project Beta v2]]" in one source file
const f = app.vault.getAbstractFileByPath('Inbox/2026-05 brain dump.md');
const src = await app.vault.read(f);
const re = /(?<!\[\[)Project Beta v2(?!\]\])/g;
const out = src.replace(re, '[[Project Beta v2]]');
await app.vault.modify(f, out);
```

The lookbehind/lookahead is critical — it prevents double-wrapping `[[[[Project Beta v2]]]]` on re-runs.

**(b) Conservative footer (preferred when unsure):**

Append a `## Related` section to the source file via obsidian-core-io:

```bash
obsidian append path="Inbox/2026-05 brain dump.md" \
  section="Related" \
  content="- [[Project Beta v2]]
- [[<Person Name>]]" --silent
```

The footer is non-destructive and visible in the source note's outgoing links / Obsidian graph view, even though the body prose is unchanged.

### Apply

Group proposals by source file and present to the user as a checklist. After approval, run the chosen mode (inline `eval` or `append`).

Re-run `obsidian search query="\"<title>\" -[[<title>]] -file:\"<title>.md\"" format=json` to verify the candidate is gone.

## Recipe 3 — Orphan reconnection

### Detect

```bash
bash scripts/find-orphan-notes.sh
```

Output (JSON array):

```json
[
  "Inbox/2025-11 idea.md",
  "Research/Stale topic_g.md",
  "_Archive/Old project.md"
]
```

### Review (Agent)

Orphans fall into three buckets:

| Bucket | Disposition |
| :--- | :--- |
| Genuine inbox / draft | Wire into the relevant MOC; if no MOC fits, skip |
| Archived / obsolete | Already in `_Archive/` or similar — usually fine to remain orphan |
| Should-be-active but forgotten | Wire into a MOC and consider promoting (move out of Inbox) |

For each orphan to wire in, find its closest MOC:

1. Read the orphan's frontmatter tags via `obsidian read path="<orphan>" format=json`.
2. Cross-reference against `INDEX.md` (vault root, contains all paths + 1-line summaries) and look for `_Index_*.md` or MOC-style notes that already reference similar tags / topics.
3. Propose: "wire `Inbox/2025-11 idea.md` into `_Index_Work.md` under section `### Ideas`".

### Apply

```bash
# Add the orphan to its MOC
obsidian append path="_Index_Work.md" \
  section="Ideas" \
  content="- [[Inbox/2025-11 idea.md|2025-11 idea]] — short summary line" --silent
```

The pipe form `[[path|alias]]` lets the link display a clean title even when the source path is ugly (`Inbox/2025-11 idea.md` → "2025-11 idea").

If the orphan should be relocated entirely (e.g., move out of `Inbox/`), use `obsidian move` instead — it auto-rewrites all wikilinks across the vault and a `move` plus a single `append` gives the orphan both a home folder and a MOC anchor in one shot.

Re-verify with `obsidian backlinks file="<orphan>" format=json` — should be ≥ 1 entry now.

## Combined audit run

A periodic full audit of the vault:

```bash
# Step 1 — broken links
bash scripts/find-unresolved-links.sh > /tmp/broken.json

# Step 2 — unlinked mentions, less noisy threshold
bash scripts/find-unlinked-mentions.sh MIN_LEN=5 > /tmp/mentions.json

# Step 3 — orphans
bash scripts/find-orphan-notes.sh > /tmp/orphans.json
```

Then have the agent read the three JSON blobs, present a triaged plan, and execute the approved subset.

A nice side-effect: the JSON files themselves can be saved into the vault as a dated audit log via obsidian-core-io's `create`, e.g. `Reviews/2026-05-10 link-audit.md`.
