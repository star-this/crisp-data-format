# CRISP — Clear Readable Interchange for Structured Prose

**Version 1.0.0**
**Status: Draft Specification**
**Last Updated: 2026-02-02**

---

## Abstract

CRISP is a text-based file format designed for **human-agent collaboration**, combining structured data, prose content, and tabular information in a single, coherent document. It prioritizes human readability while maintaining precise machine parseability, making it ideal for agent manifests, task specifications, configuration files, and any context where both humans and AI systems must read and write the same documents.

---

## 1. Design Philosophy

### 1.1 Core Principles

1. **Explicit over Implicit** — Every structural element is clearly marked; no magic inference
2. **Zone-Based Parsing** — Different regions have different, well-defined parsing rules
3. **Human-First, Machine-Friendly** — Readable without tooling, parseable with precision
4. **Safe by Default** — No code execution vectors, no dangerous type coercion
5. **Streaming-Compatible** — Documents can be parsed incrementally as they're generated
6. **Schema-Aware** — Optional but first-class validation support

### 1.2 Comparative Analysis

| Source Format | What CRISP Adopts | What CRISP Avoids |
|---------------|-------------------|-------------------|
| **Plain Text** | UTF-8 encoding, line-based structure, universal tooling | N/A |
| **CommonMark** | Prose formatting, code fences, familiar syntax | Ambiguous HTML interleaving, inconsistent implementations |
| **TOML** | Explicit types, readable key-value pairs, table syntax | Complex inline table nesting, datetime ambiguity |
| **Safe YAML** | Multiline strings, hierarchical data, readability | Anchors/aliases, implicit typing, code execution, Norway problem |
| **TSV** | Simple delimiters for tabular data, no quoting hell | No typing, escape character ambiguity |
| **Pickle** | Rich type preservation (conceptually) | Binary format, arbitrary code execution |
| **JSON** | — | Adopted nothing; explicitly avoided |

### 1.3 Why Not JSON?

CRISP explicitly excludes JSON and its variants (JSONL, NDJSON, JSON-LD, JSON5, JSONC) because:

1. **No Comments** — Configuration without comments is hostile to humans
2. **No Multiline Strings** — Prose becomes unreadable escape sequences
3. **Trailing Comma Prohibition** — Causes friction in version control diffs
4. **Limited Types** — No distinction between integers and floats, no dates
5. **Verbosity** — Quotes on every key, deep nesting becomes unreadable
6. **Human Hostility** — Requires tooling to read non-trivial documents

---

## 2. Document Model

### 2.1 Conceptual Structure

A CRISP document is an ordered sequence of **zones**, optionally preceded by a **preamble**:

```
┌─────────────────────────────────────────────────────────────┐
│  PREAMBLE (optional)                                        │
│  ├── Version declaration (required if preamble exists)      │
│  ├── Schema reference                                       │
│  └── Document metadata                                      │
├─────────────────────────────────────────────────────────────┤
│  ZONE 1                                                     │
│  ├── Zone type (data | prose | table | list | raw | seq)    │
│  ├── Zone name (unique identifier)                          │
│  ├── Type hints (optional)                                  │
│  └── Zone content                                           │
├─────────────────────────────────────────────────────────────┤
│  ZONE 2                                                     │
│  └── ...                                                    │
├─────────────────────────────────────────────────────────────┤
│  ... additional zones ...                                   │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 File Identification

| Property | Value |
|----------|-------|
| **File Extension** | `.crisp` (preferred) or `.crsp` (short form) |
| **MIME Type** | `application/crisp` |
| **Magic Bytes** | `%crisp ` (first 7 bytes, ASCII) |
| **Encoding** | UTF-8 (no BOM required or recommended) |

### 2.3 Line Endings

- Both CRLF (`\r\n`) and LF (`\n`) are accepted
- Parsers MUST normalize to LF internally
- Encoders SHOULD produce LF-only output by default

### 2.4 Character Set

- All content is UTF-8
- Control characters (U+0000–U+001F) are forbidden except:
  - TAB (U+0009) — allowed and semantically significant in tables
  - LF (U+000A) — line terminator
  - CR (U+000D) — allowed only immediately before LF

---

## 3. Preamble

The preamble contains document-level metadata using **directive lines**.

### 3.1 Syntax

```crisp
%crisp 1.0
%schema https://example.com/schemas/manifest.crisp-schema
%created 2026-02-02T10:30:00Z
%author "Alice Chen"
%tags ["agent", "manifest", "v2"]
```

### 3.2 Directive Grammar

```ebnf
preamble     = directive* ;
directive    = '%' directive-name WS directive-value? NEWLINE ;
directive-name = ALPHA (ALPHA | DIGIT | '-')* ;
directive-value = <any characters until NEWLINE> ;
```

### 3.3 Standard Directives

| Directive | Required | Description | Example |
|-----------|----------|-------------|---------|
| `%crisp` | **Yes*** | Format version (MAJOR.MINOR) | `%crisp 1.0` |
| `%schema` | No | Schema URI for validation | `%schema ./manifest.crisp-schema` |
| `%id` | No | Document identifier (URI or UUID) | `%id urn:uuid:550e8400-...` |
| `%created` | No | Creation timestamp (ISO 8601) | `%created 2026-02-02T10:30:00Z` |
| `%modified` | No | Last modification timestamp | `%modified 2026-02-02T14:00:00Z` |
| `%author` | No | Document author | `%author "Alice Chen"` |
| `%title` | No | Human-readable title | `%title "Agent Manifest"` |
| `%lang` | No | Primary human language (BCP 47) | `%lang en-US` |
| `%encoding` | No | Always `utf-8`; reserved | `%encoding utf-8` |

*Required only if a preamble is present. Documents may omit the preamble entirely.

### 3.4 Custom Directives

Applications MAY define custom directives with lowercase names:

```crisp
%crisp 1.0
%x-application myapp/2.0
%x-feature-flags ["beta", "experimental"]
```

Custom directives MUST begin with `x-` to avoid conflicts with future standard directives.

### 3.5 Preamble Termination

The preamble ends when the parser encounters:
- A blank line followed by zone content
- A zone marker (`@`)
- End of file

---

## 4. Zones

Zones are the primary structural unit of a CRISP document.

### 4.1 Zone Marker Syntax

```ebnf
zone-marker  = '@' zone-type ':' zone-name type-hints? NEWLINE ;
zone-type    = 'data' | 'prose' | 'table' | 'list' | 'raw' | 'seq' ;
zone-name    = identifier ('.' identifier)* ;
identifier   = (ALPHA | '_') (ALPHA | DIGIT | '_' | '-')* ;
type-hints   = WS '[' hint-list ']' ;
hint-list    = hint (',' WS hint)* ;
hint         = identifier '=' hint-value | identifier ;
hint-value   = string | identifier ;
```

### 4.2 Zone Names

Zone names serve as unique identifiers within a document:

- **Simple**: `config`, `readme`, `users`
- **Namespaced**: `database.primary`, `api.endpoints.auth`
- **Case-sensitive**: `Config` ≠ `config`

Namespaced names use dots to indicate logical hierarchy but do NOT imply nesting in the data model — they are simply identifiers.

### 4.3 Zone Termination

| Zone Type | Termination Rule |
|-----------|------------------|
| `data` | Next zone marker OR end of file |
| `prose` | Explicit `@end` marker |
| `table` | Explicit `@end` marker |
| `list` | Explicit `@end` marker |
| `raw` | Explicit `@end` marker |
| `seq` | Explicit `@end` marker |

The `data` zone's implicit termination allows natural document flow without ceremony for simple configurations.

### 4.4 Zone Type Reference

| Type | Purpose | Content Model |
|------|---------|---------------|
| `data` | Structured key-value data | TOML-compatible syntax |
| `prose` | Human-readable text | CommonMark Markdown |
| `table` | Tabular data | TSV with typed columns |
| `list` | Typed sequences | One item per line |
| `raw` | Pass-through content | Verbatim preservation |
| `seq` | Ordered heterogeneous sequence | Mixed typed entries |

---

## 5. Data Zones

Data zones contain structured key-value data using TOML-compatible syntax with extensions.

### 5.1 Example

```crisp
@data:config
  name = "my-application"
  version = "2.1.0"
  debug = true
  port = 8080
  timeout = 30.5

  [server]
  host = "0.0.0.0"
  workers = 4

  [server.tls]
  enabled = true
  cert = "/etc/ssl/cert.pem"

  [[routes]]
  path = "/api/users"
  handler = "users.list"
  methods = ["GET", "POST"]

  [[routes]]
  path = "/api/users/{id}"
  handler = "users.get"
  methods = ["GET"]
```

### 5.2 Scalar Types

#### 5.2.1 Strings

**Basic strings** use double quotes with escape sequences:

```crisp
basic = "Hello, World!"
escaped = "Line 1\nLine 2\tTabbed"
unicode = "Emoji: \u{1F600}"
```

| Escape | Meaning |
|--------|---------|
| `\\` | Backslash |
| `\"` | Double quote |
| `\n` | Newline (U+000A) |
| `\r` | Carriage return (U+000D) |
| `\t` | Tab (U+0009) |
| `\uXXXX` | Unicode (4 hex digits) |
| `\u{X...}` | Unicode (1–6 hex digits) |

**Literal strings** use single quotes with NO escape processing:

```crisp
literal = 'C:\Users\name'
regex = '^[a-z]+$'
```

**Multiline strings** use triple quotes:

```crisp
description = """
  This is a multiline string.
  Leading whitespace based on the closing quotes is stripped.
  The line with the closing quotes sets the baseline indent.
"""

literal_multi = '''
No \n escape processing here.
Perfect for regex or code snippets.
'''
```

Multiline string rules:
1. Opening quotes MUST be followed by a newline
2. Content begins on the next line
3. Closing quotes MUST be on their own line
4. Baseline indent = indent of closing quotes
5. Lines with less indent than baseline are an error

#### 5.2.2 Integers

```crisp
decimal = 42
negative = -17
positive = +99
hex = 0xDEAD_BEEF
octal = 0o755
binary = 0b1010_1010
with_separators = 1_000_000
```

- Underscores are visual separators, ignored in parsing
- Range: implementation-defined, but MUST support at least 64-bit signed

#### 5.2.3 Floats

```crisp
pi = 3.14159
negative = -0.001
scientific = 6.022e23
neg_exp = 1.6e-19
positive_infinity = inf
negative_infinity = -inf
not_a_number = nan
```

- MUST support IEEE 754 double precision at minimum
- Special values: `inf`, `-inf`, `nan` (case-sensitive, lowercase)

#### 5.2.4 Booleans

```crisp
enabled = true
disabled = false
```

Only lowercase `true` and `false` are valid. NO implicit boolean coercion from strings, integers, or other values.

#### 5.2.5 Null

```crisp
missing = ~
```

The tilde (`~`) represents null/nil/none. This is a departure from TOML (which has no null) but essential for data interchange.

#### 5.2.6 DateTime Types

```crisp
# Full datetime with timezone
created = 2026-02-02T10:30:00Z
updated = 2026-02-02T10:30:00-05:00

# Local datetime (no timezone)
local_time = 2026-02-02T10:30:00

# Date only
birthday = 1990-05-15

# Time only
alarm = 07:30:00
precise = 14:30:00.123456

# Duration (ISO 8601)
timeout = P1DT2H30M
short = PT30S
```

All datetime values follow ISO 8601. Implementations SHOULD preserve the original timezone offset rather than converting to UTC.

### 5.3 Compound Types

#### 5.3.1 Arrays

```crisp
# Homogeneous arrays (recommended)
integers = [1, 2, 3, 4, 5]
strings = ["alpha", "beta", "gamma"]

# Heterogeneous arrays (allowed but discouraged)
mixed = [1, "two", true, ~]

# Multiline arrays
dependencies = [
  "phoenix",
  "ecto",
  "jason",
]

# Nested arrays
matrix = [[1, 2], [3, 4], [5, 6]]
```

- Trailing commas are ALLOWED (unlike JSON)
- Newlines within brackets are ALLOWED
- Empty array: `[]`

#### 5.3.2 Tables (Nested Objects)

**Standard tables:**

```crisp
[server]
host = "localhost"
port = 8080

[server.database]
name = "myapp"
pool_size = 10
```

**Inline tables** for simple cases:

```crisp
point = { x = 10, y = 20 }
person = { name = "Alice", age = 30 }
```

Inline tables:
- MUST fit on a single line
- MUST NOT contain nested tables
- MUST NOT contain multiline values

**Array of tables:**

```crisp
[[products]]
name = "Widget"
price = 9.99

[[products]]
name = "Gadget"
price = 24.99

[[servers.endpoints]]
path = "/api"
port = 8080
```

### 5.4 Comments

```crisp
# This is a full-line comment

name = "example"  # This is an inline comment

# Comments can span
# multiple lines
# like this
```

Comments begin with `#` and extend to end of line. Comments are NOT preserved in the parsed data model (they are metadata, not data).

### 5.5 Key Names

Keys follow identifier rules OR can be quoted:

```crisp
simple_key = 1
another-key = 2
"quoted key with spaces" = 3
"key.with" = 4
```

Unquoted keys: `[A-Za-z_][A-Za-z0-9_-]*`

---

## 6. Prose Zones

Prose zones contain human-readable text using CommonMark Markdown syntax.

### 6.1 Example

```crisp
@prose:readme
  # Project Overview

  This project implements the **CRISP** file format, providing
  a clean way to mix structured data with human-readable content.

  ## Features

  - Zone-based parsing for clarity
  - Schema validation support
  - Type-safe data sections

  ```elixir
  # Code blocks are preserved exactly
  {:ok, doc} = Crisp.decode(content)
  ```

  > Blockquotes work as expected.

  See the [specification](./SPEC.md) for details.
@end
```

### 6.2 Content Rules

1. Content begins on the line after the zone marker
2. The `@end` marker MUST appear on its own line
3. **Dedentation**: Common leading whitespace is stripped based on minimum indent
4. CommonMark syntax is preserved, not rendered
5. The `#` character is content (Markdown heading), NOT a comment

### 6.3 Dedentation Algorithm

```
1. Find all non-blank lines in the content
2. Calculate the minimum leading whitespace (spaces/tabs)
3. Strip exactly that many characters from the start of each line
4. Preserve blank lines as-is
```

### 6.4 Hints

Prose zones accept optional hints:

```crisp
@prose:documentation [format=commonmark, lang=en-US]
  # English Documentation
  ...
@end

@prose:notes [format=plain]
  Just plain text, no markdown processing expected.
@end
```

Standard hints:
- `format`: `commonmark` (default), `plain`, `gfm` (GitHub-flavored)
- `lang`: BCP 47 language tag

---

## 7. Table Zones

Table zones contain tabular data with typed columns using TAB-separated values.

### 7.1 Example

```crisp
@table:inventory [id:int, sku:str, name:str, quantity:int, price:float, active:bool]
  1	SKU-001	Widget	100	9.99	true
  2	SKU-002	Gadget	50	24.99	true
  3	SKU-003	Gizmo	0	14.99	false
  4	SKU-004	Thingamajig	~	~	false
@end
```

### 7.2 Column Definition Syntax

```ebnf
column-defs  = '[' column-def (',' WS column-def)* ']' ;
column-def   = column-name ':' column-type ;
column-name  = identifier ;
column-type  = 'str' | 'int' | 'float' | 'bool' | 'date' | 'datetime'
             | 'time' | 'duration' | 'any' ;
```

### 7.3 Type Reference

| Type | Description | Example Values |
|------|-------------|----------------|
| `str` | UTF-8 string | `hello`, `foo bar` |
| `int` | Integer | `42`, `-17`, `0` |
| `float` | Floating point | `3.14`, `-0.5`, `1e10` |
| `bool` | Boolean | `true`, `false` |
| `date` | ISO 8601 date | `2026-02-02` |
| `datetime` | ISO 8601 datetime | `2026-02-02T10:30:00Z` |
| `time` | ISO 8601 time | `10:30:00` |
| `duration` | ISO 8601 duration | `PT30M`, `P1D` |
| `any` | No type coercion | Preserved as string |

### 7.4 Delimiter

Columns are separated by **TAB** (`U+0009`). This choice:
- Avoids CSV quoting complexity
- Is unambiguous (tabs rarely appear in data)
- Aligns naturally in editors with tab stops

### 7.5 Null Values

The tilde (`~`) represents null in any column:

```crisp
@table:users [id:int, name:str, email:str]
  1	Alice	alice@example.com
  2	Bob	~
  3	~	charlie@example.com
@end
```

### 7.6 Escaping

When literal TAB, newline, backslash, or tilde are needed in string data:

| Sequence | Meaning |
|----------|---------|
| `\t` | Literal TAB |
| `\n` | Literal newline |
| `\\` | Literal backslash |
| `\~` | Literal tilde (not null) |

### 7.7 Empty vs. Null

- Empty string: (nothing between delimiters)
- Null: `~`

```crisp
@table:example [a:str, b:str, c:str]
  	~	value
@end
# a = "", b = null, c = "value"
```

---

## 8. List Zones

List zones contain typed sequences with one item per line.

### 8.1 Example

```crisp
@list:allowed-hosts [str]
  localhost
  127.0.0.1
  example.com
  *.internal.net
@end

@list:fibonacci [int]
  1
  1
  2
  3
  5
  8
  13
@end

@list:feature-flags [bool]
  true
  false
  true
  true
@end
```

### 8.2 Type Annotation

```ebnf
list-type = '[' type-name ']' ;
type-name = 'str' | 'int' | 'float' | 'bool' | 'date' | 'datetime'
          | 'time' | 'duration' | 'any' ;
```

### 8.3 Multiline Items

For items containing newlines, use continuation markers:

```crisp
@list:commands [str]
  simple-command
  |multi-line command
  |that spans several
  |lines of text
  another-simple-command
@end
```

The `|` prefix indicates continuation of the previous item. The `|` and any single following space are stripped.

### 8.4 Null Items

```crisp
@list:optional-values [int]
  42
  ~
  17
  ~
  99
@end
```

---

## 9. Raw Zones

Raw zones pass content through verbatim with no processing.

### 9.1 Example

```crisp
@raw:email-template [lang=html, encoding=utf-8]
  <!DOCTYPE html>
  <html>
    <body>
      <h1>Hello, {{ name }}!</h1>
      <p>Your order #{{ order_id }} has shipped.</p>
      @end  <!-- This is content, not a marker -->
    </body>
  </html>
@end
```

### 9.2 Content Rules

1. Everything between the zone marker and `@end` is preserved exactly
2. NO dedentation is applied
3. NO escape processing occurs
4. The literal string `@end` on its own line terminates the zone

### 9.3 Escaping @end

If content must contain `@end` on its own line, use the extended delimiter syntax:

```crisp
@raw:tricky [delim=@@@]
  Some content here
  @end
  More content
  @end is fine here too
@@@
```

The `delim` hint specifies an alternative end marker.

### 9.4 Common Hints

- `lang`: Content language/format (`html`, `sql`, `python`, etc.)
- `encoding`: Always `utf-8`; reserved for future use
- `delim`: Alternative end delimiter

---

## 10. Seq Zones (Ordered Heterogeneous Sequences)

Seq zones contain ordered sequences of typed entries, useful for event logs, conversation histories, or any ordered heterogeneous data.

### 10.1 Example

```crisp
@seq:conversation
  [message role=user timestamp=2026-02-02T10:30:00Z]
    What is the capital of France?
  [/message]

  [message role=assistant timestamp=2026-02-02T10:30:02Z]
    The capital of France is **Paris**. It's the largest city in France
    and serves as the country's political, economic, and cultural center.
  [/message]

  [message role=user timestamp=2026-02-02T10:30:15Z]
    What about Germany?
  [/message]

  [message role=assistant timestamp=2026-02-02T10:30:17Z]
    The capital of Germany is **Berlin**.
  [/message]
@end
```

### 10.2 Entry Syntax

```ebnf
seq-entry    = entry-open NEWLINE entry-content entry-close NEWLINE ;
entry-open   = '[' entry-type (WS attribute)* ']' ;
entry-close  = '[/' entry-type ']' ;
entry-type   = identifier ;
attribute    = attr-name '=' attr-value ;
attr-name    = identifier ;
attr-value   = string | identifier | number ;
```

### 10.3 Nested Entries

Entries can nest:

```crisp
@seq:document
  [section id=intro]
    [heading level=1]
      Introduction
    [/heading]
    [paragraph]
      This is the first paragraph.
    [/paragraph]
  [/section]
@end
```

### 10.4 Schema Integration

Seq zones are particularly powerful with schemas that define valid entry types and their attributes.

---

## 11. Comments

### 11.1 Syntax

```crisp
# Full-line comment

key = "value"  # Inline comment (data zones only)
```

### 11.2 Context-Dependent Behavior

| Zone Type | `#` Behavior |
|-----------|--------------|
| Preamble | Comment (ignored) |
| Data | Comment (ignored) |
| Prose | Content (Markdown heading) |
| Table | Content (column data) |
| List | Content (list item) |
| Raw | Content (verbatim) |
| Seq | Content (entry content) |

### 11.3 Comment Preservation

Comments are NOT part of the data model. Implementations MAY provide options to preserve comments for round-tripping, but this is not required.

---

## 12. Zone References and Inheritance

### 12.1 References

Zones can reference other zones using `@ref`:

```crisp
@data:defaults
  timeout = 30
  retries = 3
  log_level = "info"

@data:production
  @ref defaults
  host = "prod.example.com"
  timeout = 60
  log_level = "warn"
```

### 12.2 Resolution Rules

1. `@ref` MUST appear at the start of a data zone
2. Only references within the same document are valid
3. Forward references are NOT allowed (referenced zone must appear earlier)
4. Reference cycles are forbidden
5. Merge is shallow — only top-level keys are copied
6. Later keys override referenced keys

### 12.3 Multiple References

```crisp
@data:combined
  @ref base
  @ref overrides
  specific_key = "value"
```

References are applied in order, with later references overriding earlier ones.

---

## 13. Schema Language

CRISP schemas are CRISP documents with the extension `.crisp-schema`.

### 13.1 Schema Example

```crisp
%crisp 1.0
%schema-version 1.0

@data:schema
  # Document-level constraints
  [document]
  required_zones = ["config", "readme"]

  # Zone definitions
  [zones.config]
  type = "data"
  required = true

  [zones.config.fields.name]
  type = "string"
  required = true
  pattern = "^[a-z][a-z0-9-]*$"
  min_length = 1
  max_length = 64

  [zones.config.fields.version]
  type = "string"
  required = true
  pattern = "^\\d+\\.\\d+\\.\\d+$"

  [zones.config.fields.port]
  type = "integer"
  required = false
  default = 8080
  min = 1
  max = 65535

  [zones.config.fields.debug]
  type = "boolean"
  default = false

  [zones.readme]
  type = "prose"
  required = true
  min_length = 100  # Minimum character count

  [zones.inventory]
  type = "table"
  required = false

  [[zones.inventory.columns]]
  name = "id"
  type = "integer"
  unique = true
  nullable = false

  [[zones.inventory.columns]]
  name = "sku"
  type = "string"
  pattern = "^SKU-\\d{3,}$"

  [[zones.inventory.columns]]
  name = "quantity"
  type = "integer"
  min = 0
```

### 13.2 Constraint Reference

| Constraint | Applies To | Description |
|------------|------------|-------------|
| `required` | Zone, Field, Column | Must be present |
| `type` | Field, Column | Expected type name |
| `default` | Field | Default value if absent |
| `nullable` | Field, Column | Whether `~` is allowed |
| `pattern` | String | ECMAScript regex pattern |
| `min` / `max` | Number | Value bounds (inclusive) |
| `min_length` / `max_length` | String, Array, Prose | Length bounds |
| `enum` | Any scalar | List of allowed values |
| `unique` | Column | No duplicate values in table |
| `format` | String | Semantic format (`email`, `uri`, `uuid`, etc.) |

### 13.3 Standard Formats

| Format | Description | Example |
|--------|-------------|---------|
| `email` | Email address | `user@example.com` |
| `uri` | URI/URL | `https://example.com/path` |
| `uuid` | UUID | `550e8400-e29b-41d4-a716-446655440000` |
| `hostname` | DNS hostname | `api.example.com` |
| `ipv4` | IPv4 address | `192.168.1.1` |
| `ipv6` | IPv6 address | `::1` |
| `semver` | Semantic version | `1.2.3` |

### 13.4 Validation Behavior

1. If `%schema` is declared, validation SHOULD occur
2. Validation errors MUST include: path, constraint, message
3. Unknown zones/fields MAY be allowed (configurable)
4. Default values are applied during decode when absent

---

## 14. Streaming and Incremental Parsing

CRISP is designed to support streaming/incremental parsing, essential for LLM output.

### 14.1 Streaming Guarantees

1. **Zone Independence**: Each zone can be parsed independently once its boundaries are known
2. **Early Termination**: A parser can stop after reading specific zones
3. **Line-Based Progress**: Progress can be reported per-line
4. **Partial Results**: Incomplete zones can be partially parsed

### 14.2 Streaming-Friendly Patterns

```crisp
# Good: Zone boundary is clear early
@data:config
  key = "value"

# Good: Prose zone content streams naturally
@prose:response
  The answer to your question is...
  [content streams here]
@end

# Acceptable: Table rows stream individually
@table:results [id:int, value:str]
  1	First result
  2	Second result
  ...more rows stream in...
@end
```

### 14.3 Incremental Parsing API

Implementations SHOULD provide:

```
Parser.new() -> parser
Parser.feed(parser, chunk) -> {:continue, parser} | {:zone, zone, parser} | {:error, reason}
Parser.finalize(parser) -> {:ok, document} | {:error, reason}
```

---

## 15. Embedding and Interoperability

### 15.1 Embedding CRISP in Other Formats

CRISP can be embedded in other text formats:

**In Markdown:**

````markdown
Here is the configuration:

```crisp
@data:config
  name = "example"
```

And the documentation follows...
````

**In Comments:**

```python
"""
@crisp:config
@data:settings
  max_retries = 3
  timeout = 30.0
@crisp:end
"""
```

### 15.2 Extracting from Source Files

The markers `@crisp:config` and `@crisp:end` (or similar application-defined markers) allow CRISP content to be extracted from source files, documentation, or other contexts.

### 15.3 Relationship to Other Formats

| Conversion | Direction | Notes |
|------------|-----------|-------|
| TOML | Bidirectional | Data zones are TOML-compatible |
| Markdown | One-way | Prose zones contain Markdown |
| CSV/TSV | Bidirectional | Table zones with type annotations |
| YAML | Import only | Safe subset only; no anchors |

---

## 16. Security Considerations

### 16.1 Safe by Design

CRISP incorporates security lessons from YAML:

1. **No Code Execution** — No constructor tags, no eval, no imports
2. **No Anchors/Aliases** — Prevents billion laughs attack, reference cycles
3. **No Type Tags** — Types are explicit, not inferred from tags
4. **Bounded Parsing** — Implementations SHOULD limit:
   - Maximum document size
   - Maximum nesting depth (recommended: 64)
   - Maximum key/value length
   - Maximum number of zones

### 16.2 External References

- Schema URIs are advisory; parsers MAY ignore them
- No automatic fetching of external resources
- Applications MUST validate external schema sources

### 16.3 String Coercion Safety

CRISP has NO implicit string-to-boolean coercion:

```crisp
# These are all STRINGS, not booleans
norway = "no"
yaml_trap = "yes"
also_string = "true"  # This is a string

# These are BOOLEANS
actual_bool = true
another_bool = false
```

### 16.4 Numeric Safety

- Integer overflow behavior is implementation-defined
- Implementations MUST support at least 64-bit signed integers
- Implementations MUST support IEEE 754 double-precision floats
- Loss of precision SHOULD be reported or prevented

---

## 17. Error Handling

### 17.1 Error Categories

| Category | Description | Recovery |
|----------|-------------|----------|
| **Syntax** | Malformed structure | Cannot proceed |
| **Type** | Value doesn't match declared type | Skip or fail |
| **Constraint** | Schema validation failure | Report and continue |
| **Reference** | Invalid zone reference | Fail |
| **Encoding** | Invalid UTF-8 | Fail |

### 17.2 Error Reporting

Errors MUST include:
- Line number (1-indexed)
- Column number (1-indexed, for syntax errors)
- Human-readable message

Errors SHOULD include:
- Zone name (if applicable)
- Field/key name (if applicable)
- Expected vs. actual value

### 17.3 Recovery Strategies

Implementations MAY provide options for:
- Strict mode: Any error is fatal
- Lenient mode: Collect all errors, return partial results
- Streaming mode: Emit valid zones, report errors inline

---

## 18. Implementation Requirements

### 18.1 Conformance Levels

**Level 1 — Core:**
- Preamble parsing
- Data zones (all scalar types, tables, arrays)
- Prose zones
- Comments

**Level 2 — Extended:**
- Table zones with typed columns
- List zones
- Raw zones
- Zone references

**Level 3 — Full:**
- Seq zones
- Schema validation
- Streaming API

### 18.2 Round-Trip Fidelity

Implementations SHOULD preserve:
- Zone order
- Key order within data zones
- Whitespace in prose/raw zones
- Original numeric representation (hex vs. decimal)

Implementations MAY NOT preserve:
- Comments (unless specifically supported)
- Trailing commas
- Whitespace in data zones (outside strings)

### 18.3 Required APIs

Every implementation MUST provide:

```
decode(string) -> Result<Document, Error>
encode(Document) -> Result<string, Error>
```

Implementations SHOULD provide:

```
decode_file(path) -> Result<Document, Error>
encode_file(Document, path) -> Result<(), Error>
validate(Document, Schema) -> Result<(), List<ValidationError>>
get_zone(Document, type, name) -> Option<Zone>
```

---

## 19. Grammar Summary (EBNF)

```ebnf
(* Document structure *)
document     = preamble? zone* ;
preamble     = directive+ ;
directive    = '%' name WS value? NEWLINE ;

(* Zones *)
zone         = data-zone | prose-zone | table-zone | list-zone | raw-zone | seq-zone ;
zone-marker  = '@' zone-type ':' zone-name hints? NEWLINE ;
zone-end     = '@end' NEWLINE ;
hints        = '[' hint (',' hint)* ']' ;
hint         = name ('=' value)? ;

(* Data zone *)
data-zone    = '@data:' name hints? NEWLINE data-content ;
data-content = (key-value | table-header | array-table | comment | BLANK)* ;
key-value    = WS* key WS* '=' WS* value comment? NEWLINE ;
table-header = WS* '[' key-path ']' NEWLINE ;
array-table  = WS* '[[' key-path ']]' NEWLINE ;
key-path     = key ('.' key)* ;

(* Prose zone *)
prose-zone   = '@prose:' name hints? NEWLINE prose-content zone-end ;
prose-content = line* ;

(* Table zone *)
table-zone   = '@table:' name column-defs hints? NEWLINE table-rows zone-end ;
column-defs  = '[' column-def (',' column-def)* ']' ;
column-def   = name ':' type-name ;
table-rows   = table-row* ;
table-row    = cell (TAB cell)* NEWLINE ;

(* List zone *)
list-zone    = '@list:' name '[' type-name ']' hints? NEWLINE list-items zone-end ;
list-items   = list-item* ;
list-item    = value NEWLINE | continuation+ ;
continuation = '|' text NEWLINE ;

(* Raw zone *)
raw-zone     = '@raw:' name hints? NEWLINE raw-content zone-end ;
raw-content  = <any content until zone-end> ;

(* Seq zone *)
seq-zone     = '@seq:' name hints? NEWLINE seq-content zone-end ;
seq-content  = seq-entry* ;
seq-entry    = entry-open entry-content entry-close ;
entry-open   = '[' name attribute* ']' NEWLINE ;
entry-close  = '[/' name ']' NEWLINE ;
attribute    = name '=' attr-value ;

(* Values *)
value        = string | number | boolean | null | datetime | array | inline-table ;
string       = basic-string | literal-string | multiline-basic | multiline-literal ;
number       = integer | float ;
boolean      = 'true' | 'false' ;
null         = '~' ;
array        = '[' (value (',' value)*)? ','? ']' ;
inline-table = '{' (key-value-inline (',' key-value-inline)*)? '}' ;

(* Terminals *)
name         = (ALPHA | '_') (ALPHA | DIGIT | '_' | '-')* ;
type-name    = 'str' | 'int' | 'float' | 'bool' | 'date' | 'datetime' | 'time' | 'duration' | 'any' ;
comment      = '#' <any char except NEWLINE>* ;
WS           = (' ' | '\t')+ ;
NEWLINE      = '\n' | '\r\n' ;
TAB          = '\t' ;
BLANK        = WS? NEWLINE ;
```

---

## 20. Complete Example

```crisp
%crisp 1.0
%schema https://example.com/schemas/agent-manifest-v2.crisp-schema
%id urn:uuid:550e8400-e29b-41d4-a716-446655440000
%created 2026-02-02T10:30:00Z
%author "Alice Chen"
%title "Research Assistant Agent Manifest"

# This manifest defines a research assistant agent

@data:agent
  name = "research-assistant"
  version = "2.1.0"
  description = "An AI agent specialized in research and analysis"

  [capabilities]
  search = true
  summarize = true
  cite_sources = true
  generate_reports = true

  [limits]
  max_tokens = 100000
  timeout = 300
  concurrent_tasks = 5

  [[tools]]
  name = "web_search"
  endpoint = "https://api.example.com/search"
  rate_limit = 100

  [[tools]]
  name = "document_reader"
  endpoint = "https://api.example.com/read"
  supported_formats = ["pdf", "docx", "html", "txt"]

@prose:system-prompt
  You are a research assistant with expertise in academic research,
  fact-checking, and synthesizing information from multiple sources.

  ## Core Behaviors

  1. **Accuracy First**: Always verify claims against multiple sources
  2. **Citation Required**: Provide sources for all factual statements
  3. **Balanced Analysis**: Present multiple perspectives when relevant

  ## Response Format

  Structure your responses with:
  - Executive summary (2-3 sentences)
  - Detailed findings
  - Sources and references
@end

@table:supported-domains [id:int, domain:str, confidence:float, notes:str]
  1	computer-science	0.95	Primary specialty
  2	biology	0.80	Strong foundation
  3	physics	0.75	Good understanding
  4	history	0.70	Requires more verification
  5	law	0.50	Should defer to experts
@end

@list:keywords [str]
  research
  analysis
  academic
  citations
  synthesis
  fact-checking
@end

@seq:example-conversation
  [message role=user timestamp=2026-02-01T14:00:00Z]
    What are the latest developments in quantum computing?
  [/message]

  [message role=assistant timestamp=2026-02-01T14:00:05Z]
    ## Executive Summary

    Recent developments in quantum computing include IBM's 1000+ qubit
    processor and Google's advances in error correction...

    ## Sources

    1. IBM Research Blog (2026-01-15)
    2. Nature Physics, Vol 22, Issue 3
  [/message]
@end

@raw:template.response [lang=markdown]
  ## Research Report: {{ topic }}

  **Generated**: {{ timestamp }}
  **Confidence**: {{ confidence_score }}%

  ### Summary

  {{ summary }}

  ### Detailed Findings

  {{ findings }}

  ### Sources

  {{ sources }}
@end
```

---

## 21. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-02 | Initial specification |

---

## Appendix A: Reserved Zone Types

The following zone types are reserved for future specification:

- `@binary` — Base64-encoded binary data with type hints
- `@graph` — Node/edge graph structures
- `@temporal` — Time-series data with timestamps
- `@spatial` — Geospatial data (GeoJSON-compatible)
- `@semantic` — RDF-like triple structures

---

## Appendix B: Comparison with Alternatives

### B.1 vs. YAML

| Aspect | CRISP | YAML |
|--------|-------|------|
| Safety | No code execution possible | Arbitrary code via constructors |
| Typing | Explicit everywhere | Implicit with surprises |
| Learning curve | Low (zone-based) | High (many edge cases) |
| Streaming | Designed for it | Possible but awkward |
| Prose support | First-class | Multiline strings only |

### B.2 vs. TOML

| Aspect | CRISP | TOML |
|--------|-------|------|
| Prose content | Native support | Not supported |
| Tabular data | Native support | Arrays of tables |
| Null values | Supported (~) | Not supported |
| Streaming | Supported | Not designed for it |
| Data syntax | Compatible | — |

### B.3 vs. Markdown + Frontmatter

| Aspect | CRISP | MD + Frontmatter |
|--------|-------|------------------|
| Multiple data sections | Native | Requires fencing |
| Typed tables | Native | Not possible |
| Schema validation | Built-in | External tools |
| Machine generation | Easy | Awkward |

---

## Appendix C: Media Type Registration

```
Type name: application
Subtype name: crisp
Required parameters: none
Optional parameters:
  - charset: always "utf-8"
  - schema: URI reference to schema document
Encoding considerations: 8bit (UTF-8)
Security considerations: See Section 16
Interoperability considerations: See this specification
Published specification: This document
Applications:
  - Configuration files
  - Agent manifests
  - LLM prompt templates
  - Mixed content documents
Fragment identifier considerations:
  - Zone names may be used as fragments: document.crisp#config
Additional information:
  - Magic number: "%crisp " (bytes 0x25 0x63 0x72 0x69 0x73 0x70 0x20)
  - File extension: .crisp, .crsp
  - Macintosh file type code: TEXT
Person & email address to contact for further information: [TBD]
Intended usage: COMMON
```

---

## Appendix D: Design Rationale

### D.1 Why Zones?

The fundamental insight is that different kinds of content need different parsing rules. Trying to unify everything (like YAML) leads to complexity and ambiguity. Zones make the parsing mode explicit.

### D.2 Why TAB for Tables?

- Commas appear in data too often (CSV pain)
- Fixed-width is too fragile
- Tabs are unambiguous delimiters
- Modern editors handle tabs well
- TSV is a well-understood format

### D.3 Why Explicit @end?

- Enables streaming (parser knows when zone ends)
- Avoids whitespace sensitivity issues
- Makes copy-paste safer
- Clear visual boundary

### D.4 Why No JSON?

JSON is optimized for machines, not humans. It has no comments, no multiline strings, strict comma rules, and requires quoting every key. For human-agent collaboration, these are unacceptable constraints.

### D.5 Why Tilde for Null?

- Single character (minimal)
- Not used for anything else in common formats
- Visually distinct
- Same as YAML (familiar to some)
- Not confusable with "null" string

---

*End of Specification*
