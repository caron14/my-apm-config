# Base query recipes

Reference for filter syntax, JSON output shape, and common query patterns when driving Obsidian Bases via the CLI.

## Output JSON shape

`base:query ... format=json` returns an array of row objects:

```json
[
  {
    "path": "Projects/A-corp Migration.md",
    "name": "A-corp Migration",
    "properties": {
      "status": "Active",
      "owner": "me",
      "priority": "High",
      "due": "2026-06-01",
      "tags": ["client", "migration"]
    }
  }
]
```

- `path` — vault-relative path. Pass directly to `obsidian read path=...` for full content.
- `name` — basename without `.md`.
- `properties` — frontmatter as parsed by Obsidian. Dates become ISO strings; numbers stay numeric; arrays stay arrays.

## Discovery: enumerate before querying

```bash
# 1. Which bases exist?
obsidian bases format=json

# 2. Which views does the Projects base have?
obsidian base:views file="Projects" format=json

# 3. Query the view called "Active"
obsidian base:query file="Projects" view="Active" format=json
```

## Common query patterns

### All active projects, grouped by owner

```bash
obsidian base:query file="Projects" view="Active" format=json
# then group rows by .properties.owner in your logic
```

### Items due this week

If the Base has a "Due this week" view, use it:

```bash
obsidian base:query file="Tasks" view="Due this week" format=json
```

If not, query the broadest view and filter by `properties.due` against today + 7 days.

### Stale records (no update in N days)

Bases do not expose `mtime` directly; rely on a frontmatter `last_updated` field if the schema has one, or fall back to `obsidian read` + filesystem mtime via a separate shell call.

## Creating records

`base:create` accepts properties as a JSON object. Single-quote the outer JSON for shell-safety, and use double quotes inside:

```bash
obsidian base:create file="Projects" properties='{
  "status": "Active",
  "owner": "me",
  "priority": "Medium",
  "due": "2026-07-15",
  "tags": ["client"]
}' name="B-corp Onboarding"
```

Notes:
- `name=` controls the new note's basename. If omitted, the CLI may derive one from a primary property.
- Enum-valued properties (`status`, `priority`) must use values that already exist on other rows — Bases does not validate, so a typo creates a new "ghost" enum value.
- Date properties accept ISO 8601 (`YYYY-MM-DD`).

## Verifying a write

```bash
# Re-query the view the new record should appear in:
obsidian base:query file="Projects" view="Active" format=json | grep "B-corp Onboarding"

# Or read the note directly:
obsidian read path="Projects/B-corp Onboarding.md"
```

## Pitfalls

- **Querying without listing views first**: views encode the schema's intent (filter + columns). Inventing a query from scratch usually replicates a view that already exists.
- **Treating Bases as schema-enforced**: it is not. A typo in `status` creates a new enum bucket that pollutes group-by output. Always copy enum values from an existing row.
- **Mixing `tags` (array) with body-level `#tags`**: a Base property called `tags` lives in frontmatter and is independent of inline `#tag` tokens in the note body. The `tags` CLI command (in obsidian-core-io) reports the union; Bases sees only the frontmatter array.
- **Path returned by `base:query` is the source of truth**: pass it verbatim to subsequent `read` / `append` calls — do not re-derive it from `name`.
