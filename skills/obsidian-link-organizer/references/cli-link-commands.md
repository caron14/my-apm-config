# CLI link-command reference

Verified syntax for the Obsidian CLI commands this skill drives. The Obsidian CLI uses **`key=value`** for parameters; only `--silent` and `--copy` use `--`. Many third-party guides get this wrong — trust this file over StackOverflow.

## Argument convention

| Form | Use for | Examples |
| :--- | :--- | :--- |
| `key=value` | All command parameters | `query="..."`, `file="..."`, `path="..."`, `format=json`, `code="..."` |
| `--silent` | Write commands only | `append`, `prepend`, `create`, `move` |
| `--copy` | Send the result to clipboard instead of stdout | Any read-side command |

Anti-patterns:

```text
WRONG: obsidian unresolved --format=json     # -- prefix
WRONG: obsidian search "Project A"           # positional, no key
WRONG: obsidian search query "Project A"     # missing =
WRONG: obsidian eval --code="..."            # -- prefix
RIGHT: obsidian unresolved format=json
RIGHT: obsidian search query="Project A" format=json
RIGHT: obsidian eval code="..."
```

## `obsidian unresolved`

Lists wikilinks that point to non-existent notes.

```bash
obsidian unresolved              # human-readable
obsidian unresolved format=json  # structured (preferred)
```

JSON shape (typical):

```json
{
  "Notes/Foo.md": ["Renamed Bar", "Deleted Baz"],
  "Inbox/Quick.md": ["Old Project"]
}
```

If `format=json` is rejected by your CLI version, parse the human output line-by-line: each line is a `source → missing-target` pair. The `find-unresolved-links.sh` script handles both modes.

## `obsidian search`

Full-text vault search using Obsidian's native query syntax.

```bash
obsidian search query="\"Project A\"" format=json
obsidian search query="\"Project A\" -[[Project A]] -file:\"Project A.md\"" format=json
```

Native query operators useful for unlinked-mention discovery:

| Operator | Meaning |
| :--- | :--- |
| `"text"` | exact phrase |
| `-[[text]]` | exclude where `text` is already a wikilink |
| `-file:"name.md"` | exclude this file from the result set |
| `path:"folder/"` | restrict to a folder |
| `tag:#x` | restrict to notes with tag `#x` |

Quoting:
- The outer shell layer needs double quotes around the whole `query=` value.
- Phrases inside the query also need double quotes — escape them with `\"`.
- Single quotes inside double-quoted values do not need escaping.

## `obsidian links` (outgoing) and `obsidian backlinks` (incoming)

Both are **per-file**. There is no vault-wide sister command — see `obsidian eval` below for the bulk case.

```bash
obsidian links     file="Notes/Foo.md" format=json   # links Foo.md points to
obsidian backlinks file="Notes/Foo.md" format=json   # links pointing to Foo.md
```

Common mistakes:

```text
WRONG: obsidian outgoing-links file="..."         # subcommand name is `links`
WRONG: obsidian backlinks                         # missing required file=
```

If the file has no incoming/outgoing links, the result is an empty array. Use `Object.keys(...).length === 0` (in JS) or `length == 0` (in jq) to count.

## `obsidian eval`

Runs arbitrary JavaScript inside the Obsidian app context. Lets you reach `app.vault`, `app.metadataCache`, plugin APIs, etc. Use it when no dedicated subcommand exists.

```bash
obsidian eval code="JSON.stringify(app.vault.getMarkdownFiles().length)"
```

**Always wrap the return value in `JSON.stringify(...)`.** Otherwise the CLI may print `[object Object]` or truncate complex types.

Useful payloads for this skill:

```js
// All markdown files (vault-relative paths)
app.vault.getMarkdownFiles().map(f => f.path)

// Backlinks for one file (object: { sourcePath: [linkRef, ...] })
app.metadataCache.getBacklinksForFile(app.vault.getAbstractFileByPath("Notes/Foo.md")).data

// Orphan notes (zero backlinks)
app.vault.getMarkdownFiles()
  .filter(f => Object.keys(app.metadataCache.getBacklinksForFile(f).data).length === 0)
  .map(f => f.path)

// Inline rewrite — replace mentions of "Project A" with [[Project A]] in Foo.md
const f = app.vault.getAbstractFileByPath("Notes/Foo.md");
const src = await app.vault.read(f);
const out = src.replace(/(?<!\[\[)Project A(?!\]\])/g, "[[Project A]]");
await app.vault.modify(f, out);
```

The last payload is the only safe way to do an in-place edit — there is no `obsidian replace` subcommand. Run it through `obsidian-core-io` after the user approves the exact pattern.

**eval gotchas:**

- The metadata cache must be warm. If Obsidian was just launched or just finished re-indexing, `getBacklinksForFile` may return stale data. Wait until the cache is settled, or trigger `app.metadataCache.trigger("resolved")` first.
- `await` works at top level inside `eval` but the surrounding shell command does not stream — the result is one batch print.
- Errors inside the eval payload surface as a non-zero exit and a JS stack trace on stderr.

## Flag matrix

| Flag | When to apply |
| :--- | :--- |
| `format=json` | All read-side commands whose output the agent must parse (`unresolved`, `search`, `links`, `backlinks`, `read`, `tags`). |
| `--silent` | Bulk write commands (`append`, `prepend`, `create`, `move`) so Obsidian's UI does not pop a notification per call. |
| `--copy` | Only when the user asked for the result on their clipboard. |

## Pitfalls

- **Forgetting key=value form**: `obsidian foo --bar=baz` silently fails or treats `--bar=baz` as a positional argument depending on the subcommand. Always `bar=baz`.
- **`format=json` is not universal**: it's supported on most read commands but not guaranteed on every one. The detection scripts in this skill probe-then-fall-back rather than assuming.
- **Vault-wide backlinks via the CLI**: there is no such subcommand. The only path is `obsidian eval` + `metadataCache.getBacklinksForFile` per file. Looping in shell is fine for small vaults; for thousands of files, do the loop inside the JS payload.
- **Stale metadata cache after a rename**: `move` updates wikilinks, but `unresolved` may briefly still report the old target. Wait a moment or re-run.
- **Single-quoting the JS payload**: when `code='...'` contains single quotes (e.g., `f.path`), escape carefully. Prefer double-quoted `code="..."` and escape inner double quotes with `\"`. Multiline JS works — bash strings span newlines fine.
