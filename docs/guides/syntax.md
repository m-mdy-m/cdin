# Syntax highlighting

The highlighter is a small pattern matcher in the runtime. The *definitions* —
one per language — are in [cdin-x](https://github.com/m-mdy-m/cdin-x), and six
ship there: `c`, `javascript`, `lua`, `markdown`, `python`, `typescript`.

This page covers the machinery, and how to write a definition. cdin-x's
[syntax guide](https://github.com/m-mdy-m/cdin-x/blob/main/docs/building/a-syntax-definition.md)
covers the same ground from the catalog's side; the format is one table and it is
the same table.

## The shape

```lua
require("core.syntax").add {
  files   = "%.zig$",                 -- Lua pattern, or a list of them
  headers = "^#!.*[ /]zig",           -- a shebang, for extensionless files
  comment = "--",                     -- used by doc:toggle-line-comments

  patterns = {
    -- order matters: first match wins
    { pattern = { '"', '"', '\\' }, type = "string" },
    { pattern = "%-%-.*",           type = "comment" },
    { pattern = "0x%x+",            type = "number" },
    { pattern = "[%a_][%w_]*",     type = "symbol" },
  },

  symbols = {                         -- a set of words
    ["fn"]    = "keyword",
    ["const"] = "keyword",
    ["true"]  = "literal",
  },
}
```

That is the entire interface. There is no `remove`, no validation, and no
manifest: `add` appends a table to a list and returns nothing.

## The fastest way

Add it from your own config, which needs no install and no directory:

```lua
-- ~/.config/cdin/user/init.lua
require("core.syntax").add {
  files = "%.zig$",
  patterns = {
    { pattern = { '"', '"', '\\' }, type = "string" },
    { pattern = "%-%-.*",           type = "comment" },
    { pattern = "[%a_][%w_]*",     type = "symbol" },
  },
  symbols = { ["fn"] = "keyword" },
}
```

**Definitions added later win**, so one in your config overrides a catalog one
for the same extension. That is what you want, and it also means a second `add`
for an extension silently replaces the first rather than adding to it.

A definition added this way lasts for the session. There is no `remove`, so
there is nothing else it could do — and that is the right trade: you added it
where you wanted it for exactly as long as the editor was open.

## `files` and `headers`

Both are **Lua patterns, or lists of them**, matched with `find` — not anchored,
not globs.

```lua
files = "%.lua$"
files = { "%.ts$", "%.d.ts$", "%.tsx$" }
```

A list is not an alternation — it is several patterns tried in order, first match
winning. It exists because most languages have more than one extension and
`%.ts$|%.tsx$` is a pattern nobody can read.

**The filename is tried before the shebang.** `syntax.get(filename, header)`
checks `files` first and only falls back to `headers`, so a `#!/usr/bin/env
python` file called `run` is Python, and one called `run.py` is Python for the
uninteresting reason.

`headers` is matched against **the first 128 bytes of line 1**, not the whole
file. That is enough for a shebang and cheap to fetch, and it is why a header
pattern cannot be used to detect a file format further in.

The dot has to be escaped and the end anchored, or `%.js` also matches
`foo.js.bak`.

**A file with no definition is plain text, and nothing warns you.** A definition
with no patterns tokenizes every line as one `normal` token. So "my language is
not highlighted" is nearly always a `files` pattern that does not match, rather
than a missing definition.

## `patterns`

A list, tried in order at each position, **first match wins**. That is why the
string rules come first in every definition: a `"` inside a comment must be a
comment, and if the comment rule were below the string rule it would be a string.

Each pattern is matched **anchored at the current position** — the walker tries
`text:find("^" .. pattern, i)` and advances past whatever it claimed. A pattern
that does not match here is skipped, and the next one is tried; if none match,
one character is consumed as `normal`.

| form | means |
| --- | --- |
| `pattern = "…"` | a Lua pattern from the current position |
| `pattern = { open, close }` | a delimited span |
| `pattern = { open, close, escape }` | a delimited span where `escape` escapes the next occurrence |

`{ '"', '"', '\\' }` is a double-quoted string where a backslash escapes. The
escape is checked by counting the backslashes immediately before a candidate
close and testing for an odd number, so `"a\\"` ends the string and `"a\""`
does not — which is right, and is the case most delimiters get wrong.

Inside a `char class`, `[` has to be written `%[`. That is why a Lua long string
is `{ "%[%[", "%]%]" }` rather than `{ "[[", "]]" }`.

`type` is one of the keys under `syntax` in a theme, plus two extras:
`special` and `comment2` are used by cdin-x's definitions and have no default
colour, so they fall back to `normal`. A `type` a theme has no key for falls
back to `normal` too, which means a typo in a definition is invisible rather
than fatal — worth knowing, because it will not tell you.

### The state is one level deep

A delimited span sets a single `state` — the index of the pattern that opened it
— and the next line starts in whatever state the previous line ended in. That is
what makes multi-line strings and block comments work at all.

It is **not a stack.** A `"` inside a block comment does not nest a string, and a
`/*` inside a string does not nest a comment. If your language needs that, the
patterns are not enough and you would need a different walker; that is the honest
limit of the design.

### Whitespace is absorbed

Tokens are merged when two are adjacent and share a type, **or when the previous
one is nothing but whitespace** — and merging overwrites the type. So the run of
spaces before a keyword is tokenized as part of the keyword.

This is a rendering optimisation with a visible consequence: you cannot colour
leading whitespace separately from what follows it, and a definition that
patterns a bare space gets its type overwritten by whatever comes next. Nothing in
the shipped definitions does that, and it is worth knowing before you write one
that does.

## `symbols`

A set of words, keyed by the word, valued by its type. It is consulted on
**the text a pattern matched**, so it can only re-type something a pattern
already claimed:

```lua
push_token(res, syntax.symbols[matched_text] or pattern.type, matched_text)
```

Two consequences:

- `"function"` in a `symbols` table colours as a keyword even though the
  identifier pattern would have matched it as a symbol. That is the point of the
  table.
- A `symbols` entry for a word **no pattern matches** does nothing. If your
  identifier pattern is `[%a_][%w_]*`, then every word is matched and every
  `symbols` entry is live; if you narrow the pattern, entries stop applying with
  no error.

`symbols` is a set rather than a list because that is what a hand-written
definition reads like, and because duplicate keys in a Lua table constructor are
a silent last-wins rather than an error.

## How it works

**`add` appends; lookup walks the list backwards.** The last definition that
claims a filename wins. There is no way to insert at a position, so "my
definition should lose to the catalog one" is not expressible — add yours from a
plugin that loads *before* the catalog, or do not add it at all.

**A definition is chosen when the document loads and cached with it.**
`Doc:reset_syntax()` fetches the first 128 bytes of line 1, asks
`syntax.get(filename, header)`, and resets the highlighter only if the answer
changed. Renaming a file on disk is not something the editor notices; reload the
document and it re-reads.

**Highlighting is incremental and runs in a thread.** Each document owns a
`Highlighter` that walks outward from what is visible — `max_wanted_line` is the
bottom of the screen, `first_invalid_line` the top of the dirty region — and
processes at most 40 lines per pass before yielding. That is why opening a very
large file is instant.

**A line is cached with the state it started in.** Each cache entry records
`init_state`, and a line is re-tokenized when either its text changed or the
state it inherited changed. Editing line 1 of a file whose line 2 opens a
multi-line string therefore re-tokenizes everything after it — which is correct,
and is also why a large paste near the top of a big file is the one edit that
costs a frame.

**Only visible lines are tokenized.** Scrolling into new territory is where a
slow pattern shows up: a pathological Lua pattern on a long line is the one
place highlighting can cost you a frame, and it is bounded by the 40-line
chunks rather than by the file.

## Writing patterns that do not lie

A pattern that matches too much is worse than no pattern, because the text it
claims is text you cannot read. Four habits:

**Anchor what must be anchored.** `"//.*"` is fine. `".*//.*"` matches every
line, and there is no warning.

**Put the catch-all last.** `{ "[%a_][%w_]*", type = "symbol" }` before anything
that wants to see an identifier means nothing after it ever runs. This is the
single most common way a definition silently stops highlighting half a language.

**Use a frontier to stop before the delimiter.**
`"[%a_][%w_]*%s*%f[(\"{]"` matches the *identifier* and stops before the paren;
without the `%f[…]` the paren comes along and you get a function name that ends
in a bracket.

**Test on a real file, not on one line.** A definition that looks right on
`local x = 1` is no evidence about a file with a URL in a comment, and the URL
is where you will find out.

## Files

| file | holds |
| --- | --- |
| [`data/core/syntax/syntax.lua`](../../data/core/syntax/syntax.lua) | `add`, `get`, the backwards lookup |
| [`data/core/syntax/tokenizer.lua`](../../data/core/syntax/tokenizer.lua) | the walker, the state machine, token merging |
| [`data/core/doc/highlighter.lua`](../../data/core/doc/highlighter.lua) | the per-document cache and its thread |
| [`data/core/utils/common.lua`](../../data/core/utils/common.lua) | `match_pattern`, shared with the project scan |
| `X/syntax/<language>.lua` | the six definitions, in cdin-x |
