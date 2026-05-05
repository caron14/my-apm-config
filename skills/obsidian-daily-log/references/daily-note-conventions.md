# Daily-note conventions

Reference for date formats, section anchors, task syntax, and template fields used by the daily-log skill.

## Date format

The Obsidian Daily Notes plugin defines the date format and folder location. The most common defaults:

- Format: `YYYY-MM-DD` (e.g., `2026-05-05`)
- Folder: `Daily/` at the vault root
- Template: a note named `Daily` under `Templates/` (configurable)

The skill should never hardcode these — `scripts/resolve-daily-path.sh` defers to `obsidian daily:append` when available, which honors whatever the user has configured. The fallback form (`Daily/YYYY-MM-DD.md`) is a best-effort default and may need adjustment if the user has a non-standard layout.

## Standard section anchors

Most users structure their daily note around a small set of stable headings. The skill should use these anchors for `section=` parameters when appending to today:

| Heading | Purpose |
| :--- | :--- |
| `## Log` | Free-form timestamped entries (`- HH:MM — …`) |
| `## Tasks` | Today's todo list (`- [ ] …` / `- [x] …`) |
| `## Meetings` | Meeting captures, one `### <meeting-title>` per meeting |
| `## Notes` | Longer-form thoughts not tied to a timestamp |
| `## Followups` | Items spawned today that need future action |

If the user's template uses different headings, capture them once (read today's daily note via `obsidian read`) and adapt — do not impose these names on top of an existing template.

## Timestamped log entry format

```
- HH:MM — <content>
```

Always 24-hour time, em-dash separator, content on the same line. Multi-line content can use `\n` to embed line breaks; the CLI converts the escape into real newlines.

```bash
obsidian daily:append section="Log" content="- $(date +%H:%M) — Reviewed PR #142.\n  Left two comments on the migration." --silent
```

## Task syntax

Obsidian recognizes GFM checkbox syntax:

```
- [ ] open task
- [x] completed task
- [/] in-progress task   (some plugins only)
- [-] cancelled task     (some plugins only)
```

The CLI's `task toggle` flips between `[ ]` and `[x]` on a matched line. Other states (`[/]`, `[-]`) require explicit `prepend`/`append` rewrites; do not assume `task toggle` cycles through them.

## Meeting capture template

Recommended structure for a meeting capture inside `## Meetings`:

```markdown
### <Meeting title> — YYYY-MM-DD HH:MM

- **Attendees**: …
- **Topic**: …

#### Notes
- …

#### Decisions
- …

#### Followups
- [ ] <action> (owner: …, due: …)
- [ ] …
```

Followups as checkboxes mean they can be toggled via `task toggle` later, and are picked up by Obsidian's task-aggregation views.

## Pitfalls

- **Race on first append of the day**: if today's daily note does not yet exist and `daily:append` is unsupported, the fallback must `create` before `append`. The script handles this; bypassing the script and calling `append` directly will error if the file is absent.
- **Section heading drift**: if the user renames `## Tasks` to `## Todo`, blind appends to `section="Tasks"` will create a new (duplicate) section. Read the daily note at the start of a session to learn the actual headings.
- **Timezone for `date +%F`**: the fallback uses the system's local timezone. If the user works across timezones and expects "today" to mean their home timezone, this may diverge late at night. The `daily:append` form delegates to Obsidian, which handles timezone consistently with the user's vault settings.
- **Duplicate timestamp entries**: `daily:append` does not deduplicate. If the user re-runs the same command, both entries land. This is intentional — it preserves a true log — but worth noting.
