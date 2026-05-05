---
name: obsidian-bases
description: Use this skill when the user works with Obsidian Bases — `.base` files that turn notes into structured database records (introduced in Obsidian 1.12). Trigger phrases include Base, .base, dashboard, project status, structured query, "show me all projects where…", "list tasks across notes", and Japanese equivalents (Bases, データベース, ダッシュボード, プロジェクト一覧, ステータス別, 担当者別). Owns four CLI commands - `bases`, `base:views`, `base:query`, `base:create`. Standard flow - list bases → list views on a base → query a view with `format=json` → optionally `base:create` a new record. Use this for project status dashboards, CRM-style tracking, and any query that filters or groups across many notes by frontmatter properties (status, owner, due date, tags). Do NOT use for free-text search inside note bodies (use obsidian-core-io `search:context`) or for daily-note appends (use obsidian-daily-log). If the user wants "all notes tagged X", prefer Core I/O's `tags` command first; only escalate to Bases when the question involves structured properties or a pre-defined `.base` view.
---

# Obsidian Bases

Drives Obsidian's Bases feature (`.base` files) through the CLI, treating notes as rows in a virtual table indexed by their frontmatter properties. Use this skill whenever the user wants to query or create *structured* records — anything where the answer depends on a property like `status`, `owner`, `due`, or `priority`, not on the prose body of a note.

## When to use

Trigger this skill when the user asks for:

- A project status dashboard or rollup ("show me active projects", "what's in 'In Review'?")
- CRM-style queries over people/companies notes ("which contacts haven't been touched in 30 days?")
- Cross-note filtering by frontmatter property ("notes where `priority: high` AND `due` this week")
- Creating a new record that conforms to a Base's schema

Trigger phrases (English + 日本語): Base, .base, dashboard, status, query, filter, records, ダッシュボード, データベース, プロジェクト一覧, 進捗, ステータス, 担当.

**Bases vs. alternatives — pick correctly:**

| Question shape | Right tool |
| :--- | :--- |
| "Find notes mentioning the phrase X in their body." | `search:context` (obsidian-core-io) |
| "List all notes with tag #X." | `tags` (obsidian-core-io) — escalate to Bases only if you also need to filter by other properties. |
| "Show all projects where status=Active and owner=me." | **Bases** (this skill). |
| "Append today's update to my project journal." | obsidian-daily-log. |

## Discovery flow

Always go in this order. Skipping ahead leads to malformed queries.

1. **List bases**: `obsidian bases format=json` — returns every `.base` file in the vault. Pick the one matching the user's domain (Projects, Contacts, etc.).
2. **List views on that base**: `obsidian base:views file=<base-name> format=json` — each Base defines one or more views (filters + grouping + columns). Pick the view that already matches the user's intent if possible; defining a query from scratch is more error-prone.
3. **Query the view**: `obsidian base:query file=<base-name> view=<view-name> format=json` — returns the rows. If the user's filter does not match an existing view, see "Ad-hoc filtering" below.
4. **(Optional) Create a record**: `obsidian base:create file=<base-name> properties='{"status":"Active","owner":"me",...}'` — see "Creating records" below.

## Ad-hoc filtering

When no existing view fits, query the broadest matching view and filter the JSON output in your own logic, OR pass an inline filter parameter if the CLI version supports it. Prefer the former when the filter is one-off; prefer the latter when the user will reuse it.

For exact filter / group syntax and JSON shape examples, see `references/base-query-recipes.md`.

## Creating records

`base:create` writes a new note under the Base's configured folder with the given frontmatter properties. Before calling:

1. Run `base:views` and inspect at least one row to learn the property schema (which keys exist, which are required, which are enums vs. free text). The Base does not enforce a strict schema, but writing records that do not match existing fields will produce an inconsistent table.
2. Confirm enum values (e.g., `status` is one of `Backlog | Active | In Review | Done`) by sampling existing rows.
3. Pass properties as JSON via `properties='{...}'`. Quote carefully — see `references/base-query-recipes.md` for shell-escaping examples.

After creation, run `base:query` (or `read` on the new note's path) to verify the record landed correctly.

## JSON output handling

Always pass `format=json` for any Base command whose output you will parse. The plain-text output is a human-readable table and unstable to parse.

Typical row shape:

```json
{
  "path": "Projects/A-corp Migration.md",
  "name": "A-corp Migration",
  "properties": {
    "status": "Active",
    "owner": "me",
    "due": "2026-06-01"
  }
}
```

Group the rows in your own logic for summaries — Bases returns rows, not aggregates.

## Hand-off

- Free-text search inside the body of a note → **obsidian-core-io** (`search:context`).
- Reading a specific record's full prose content (after a query gives you the path) → **obsidian-core-io** (`read path=...`).
- Logging a daily project update → **obsidian-daily-log**.

A common multi-skill flow:

```
1. base:query  → identify the project's note path           (this skill)
2. read        → fetch its prose history                    (obsidian-core-io)
3. append/log  → write today's update                       (obsidian-daily-log)
```
