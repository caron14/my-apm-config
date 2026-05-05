# Daily-note conventions

Reference for date formats, section anchors, task syntax, and template fields used by the daily-log skill.

## Date format

Configured in `.obsidian/daily-notes.json`:

- Format: `YYYYMMDD` (e.g., `20260505`) — **no hyphens**
- Folder: `Daily/` at the vault root
- Template: `Template_Daily_Memo` under `_Template/`

The skill must never hardcode these. `scripts/resolve-daily-path.sh` defers to `obsidian daily:append` when available, which honors the plugin config. The fallback generates `path=Daily/YYYYMMDD.md`.

When passing a date argument to the script, use either `YYYY-MM-DD` or `YYYYMMDD` — the script normalises it.

## Standard section anchors

The daily memo template (`_Template/Template_Daily_Memo.md`) defines two sections:

| Heading | Purpose |
| :--- | :--- |
| `### New Task` | Today's tasks with priority tags |
| `### Meeting Minutes` | One meeting block per meeting (see structure below) |

**There is no `## Log` section.** Do not append to a section that does not exist in the template — it creates a duplicate heading.

If you need to add a free-form note that does not fit either section, append it to the end of the file without a `section=` parameter.

## Task format

Tasks live under `### New Task` and must carry a priority tag. The Dataview query in `TaskManagement.md` filters by `contains(text, "#priority/")` — tasks without this tag are invisible to the aggregation view.

```
- [ ] <task description> #priority/high
- [ ] <task description> #priority/medium
- [ ] <task description> #priority/low
```

Category tags (`#project`, `#meeting`) are added on the `Tags:` line below the section heading, not inline on each task:

```
### New Task

Tags: #project #meeting

- [ ] Review PR #42 #priority/high
- [ ] Update README #priority/low
```

When appending a new task via the CLI, target the section explicitly:

```bash
obsidian daily:append section="New Task" content="- [ ] <task> #priority/high" --silent
```

## Task toggling

`obsidian task toggle` matches by the task's visible text (excluding the checkbox prefix). Include enough of the text to be unique:

```bash
obsidian task toggle file="20260505" match="Review PR #42"
```

After toggling, optionally log the completion at the bottom of the file:

```bash
obsidian daily:append content="- Closed: Review PR #42" --silent
```

## Meeting capture structure

Each meeting occupies one block under `### Meeting Minutes`, separated by `---`:

```markdown
---
Meeting: <meeting title>
Attendee: <names>
Tags: <relevant tags>

Next Action
- [ ] <action item> #priority/high
- <action item>

Note:
- <observation>
- <decision>
```

When appending a new meeting block via the CLI:

```bash
obsidian daily:append section="Meeting Minutes" content="---\nMeeting: Company-A sync\nAttendee: User, Colleague\nTags: #project\n\nNext Action\n- [ ] Send revised estimate #priority/high\n\nNote:\n- Agreed on June delivery" --silent
```

## Pitfalls

- **Wrong date format**: the vault uses `YYYYMMDD`, not `YYYY-MM-DD`. `path=Daily/2026-05-05.md` does not exist.
- **Appending to non-existent section**: `section="Log"` or `section="Tasks"` creates a new heading that duplicates the template structure. Use `section="New Task"` or `section="Meeting Minutes"` only.
- **Tasks without priority tag**: `- [ ] task` with no `#priority/` tag is ignored by the Dataview aggregation in `TaskManagement.md`.
- **Race on first append of the day**: if today's daily note does not yet exist and `daily:append` is unsupported, the fallback must `create` before `append`. The script handles this; bypassing the script and calling `append` directly will error if the file is absent.
- **Duplicate meeting blocks**: `daily:append` does not deduplicate. Check the note has no existing block for the same meeting before appending.
