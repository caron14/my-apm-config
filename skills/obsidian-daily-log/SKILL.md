---
name: obsidian-daily-log
description: Use this skill when the user wants to log something into today's (or a specific date's) daily note, toggle a task's checkbox, or capture meeting notes and follow-ups timestamped into the daily log. Trigger phrases include "log this", "add to today", daily note, jot, capture, "remember that I…", "mark task done", check off, todo toggle, meeting notes, and Japanese equivalents (デイリーノート, 日報, 今日, タスク, チェック, 議事録, 会議メモ). Owns timestamped appends to today's daily note and task-state toggling. The skill resolves "today" dynamically via `scripts/resolve-daily-path.sh` — never hardcode a date. Do NOT use for appending to an arbitrary user-named note (that's obsidian-core-io `append`) or for structured project queries (use obsidian-core-io to read `TaskManagement.md`). DISAMBIGUATION - if the user says "log this" with no explicit target → daily log; if they say "add this to my <Project> note" → obsidian-core-io. If they say "mark task X done" and X lives in a project note, still use this skill — task toggling lives here regardless of host file.
---

# Obsidian Daily Log

Captures timestamped entries into today's daily note and toggles task checkboxes. Designed for the rapid "I just did X" / "remember Y" / "mark Z done" interactions that happen many times a day.

## When to use

Trigger this skill when the user says (any of):

- "Log that …", "jot down …", "remember I …"
- "Add to today", "put this in my daily note"
- "Mark <task> done", "check off …", "uncheck …"
- "Capture meeting notes for …", "write up the meeting"
- "What did I do today?" (read-side: read today's daily note)

Trigger phrases (English + 日本語): log, jot, capture, daily note, today, todo, task done, check off, デイリー, 日報, 今日, タスク完了, チェック, 議事録.

## Disambiguation

Decide between this skill and obsidian-core-io carefully:

| User said | Skill |
| :--- | :--- |
| "Log this" / "remember I did X" (no target) | **daily-log** |
| "Add this to my Company-A note" | obsidian-core-io |
| "Mark the prep task done" — task is in a project note | **daily-log** (task toggling lives here regardless of host file) |
| "Append the meeting summary to the project log" | obsidian-core-io (named non-daily target) |

If genuinely ambiguous, ask the user once.

## Resolving today's daily note

**Always invoke `scripts/resolve-daily-path.sh` to determine the daily-note target. Never hand-construct the date or path.**

The script returns the correct path for this vault: `path=Daily/YYYYMMDD.md`.

Usage from inside the skill:

```bash
# Get the resolved invocation form. The script prints:
#   path=Daily/20260505.md
TARGET=$(bash scripts/resolve-daily-path.sh)
```

For a different day ("yesterday's note", "last Friday's note"), pass the date as `YYYY-MM-DD`:

```bash
TARGET=$(bash scripts/resolve-daily-path.sh 2026-05-04)
```

## Appending tasks

Tasks must carry a `#priority/` tag — the Dataview aggregation in `TaskManagement.md` filters by this tag. Missing it makes the task invisible in the task dashboard. All tasks MUST be appended under the `### New Task` heading.

```bash
TARGET=$(bash scripts/resolve-daily-path.sh)
obsidian append "$TARGET" section="### New Task" content="- [ ] <task> #priority/high" --silent
```

Always pass `--silent` for appends so Obsidian's UI does not pop notifications on every write.

## Task toggling

The CLI exposes task state changes for Obsidian's checkbox syntax (`- [ ] task` / `- [x] task`). Tasks may live in *any* file, including project notes — toggling stays in this skill regardless of the host file.

```bash
# Toggle a task by its visible text
obsidian task toggle file="<host-file>" match="prep deck for Company-A"
```

If the match is ambiguous (multiple tasks on the same file containing the substring), narrow with a longer `match=` string or pass a line number if the CLI version supports it. If still ambiguous, list candidates with `search:context` first and confirm with the user.

After toggling, optionally append a confirmation entry into the daily log:

```bash
obsidian daily:append content="- $(date +%H:%M) — ✅ Closed: prep deck for Company-A." --silent
```

## Meeting capture pattern

Meeting notes go under the `### Meeting Minutes` section. Each meeting is a block separated by `---`:

```bash
obsidian daily:append section="Meeting Minutes" content="---\nMeeting: Company-A sync\nAttendee: User, Colleague\nTags: #project\n\nNext Action\n- [ ] Send revised pricing #priority/high\n- [ ] Book follow-up for next week #priority/medium\n\nNote:\n- Agreed on June delivery" --silent
```

`Next Action` items written as `- [ ]` checkboxes are togglable later via `task toggle`.

For section anchor conventions, date format details, and template field names, see `references/daily-note-conventions.md`.

## Hand-off

- Appending to a non-daily, named note → **obsidian-core-io** (`append`).
- Querying structured project status (which projects are active, who owns them) → **obsidian-core-io** (`read TaskManagement.md` or relevant index notes).
- Reading the prose body of a note that came up during meeting prep → **obsidian-core-io** (`read`).

A common multi-skill flow ("prep for the Company-A meeting"):

```
1. search:context + read   → past Company-A notes        (obsidian-core-io)
2. read TaskManagement.md  → Company-A project status    (obsidian-core-io)
3. daily:append + task add → prep summary + followups (this skill)
```
