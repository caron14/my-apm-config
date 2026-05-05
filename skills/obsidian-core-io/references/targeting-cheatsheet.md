# Targeting cheatsheet — `file=` vs `path=` vs active file

The Obsidian CLI accepts three ways to specify which note a command operates on. Picking the wrong one wastes calls or hits the wrong file silently.

## The three forms

### 1. `file=<name>`

Resolves the same way an Obsidian wikilink (`[[Name]]`) does:
- Matches by basename (no `.md` extension needed).
- If the basename is unique in the vault, resolves immediately.
- If the basename collides with another note, Obsidian picks the closest match using its built-in resolver — **the result is not deterministic from Claude's perspective.**

Use only when the name is known to be unique (e.g., "Inbox", "README", a UUID-style note ID).

### 2. `path=<vault-relative-path>`

Exact path from the vault root, e.g. `Clients/Company-A/2026-04 Pricing review.md`.

- Always deterministic.
- **Required** for any path that came out of `search` / `search:context` / `links` / `backlinks` JSON output — those return paths, not names.
- Preferred for any programmatic chain.

### 3. Omitted (active file)

If neither `file=` nor `path=` is given, the command operates on whatever file the user has open in the Obsidian UI.

- Useful when the user explicitly says "this note" or "the current note".
- Risky otherwise — Claude cannot see the UI state, and the active file may be something unrelated.

## Decision rule

```
Did the path come from a CLI JSON output?         → path=
Is the basename globally unique?                  → file= (acceptable)
Did the user say "this note" / "the open note"?   → omit
Otherwise                                          → search:context first, then path=
```

## Escaping rules

- Wrap any value containing spaces in double quotes: `path="Clients/Company-A/2026-04 Notes.md"`.
- Embed newlines in `content=` values as the two-character escape `\n`. The CLI converts them to real newlines.
- Embed literal double quotes inside a quoted value as `\"`.
- Single quotes do not require escaping inside double-quoted values.

## Flag matrix

| Flag | When to apply |
| :--- | :--- |
| `format=json` | ANY command whose output Claude will parse. Default for `search`, `search:context`, `tags`, `links`, `backlinks`. |
| `--silent` | Background write commands (`append`, `create`, `prepend`, `move`). Suppresses Obsidian's UI notifications so the user is not interrupted. |
| `--copy` | Only when the user explicitly asked for the result on their clipboard. Otherwise, the JSON/text output goes to stdout. |

## Common pitfalls

- **Name collision silently wrong file**: two notes named `Notes.md` in different folders — `file=Notes` may pick either. Always go through `search:context` for ambiguous names.
- **Untrimmed search query**: leading/trailing whitespace in `query=` can over-narrow results. Trim before calling.
- **Mistaking absolute paths for vault-relative**: `path=` is relative to the vault root, never an OS-level absolute path. Do not pass `/Users/...` style paths.
- **Forgetting `format=json` on `read`**: `read` defaults to plain text. If you need to feed the output back into another tool that expects structured data, request `format=json` explicitly.
