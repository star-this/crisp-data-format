# CRISP Quick Reference

## Document Structure

```crisp
%crisp 1.0                    # Required if preamble exists
%schema ./schema.crisp-schema # Optional schema reference
%author "Name"                # Optional metadata

@data:zone-name               # Structured data (TOML-like)
  key = "value"

@prose:zone-name              # Human text (Markdown)
  Content here...
@end

@table:zone-name [col:type, ...] # Tabular data
  val1	val2	val3
@end

@list:zone-name [type]        # Typed sequences
  item1
  item2
@end

@raw:zone-name                # Verbatim content
  Anything goes here
@end

@seq:zone-name                # Ordered entries
  [entry attr=value]
    Content
  [/entry]
@end
```

## Data Zone Types

| Type | Syntax | Examples |
|------|--------|----------|
| String | `"..."` `'...'` `"""..."""` | `"hello"`, `'raw\n'` |
| Integer | decimal, 0x, 0o, 0b | `42`, `0xFF`, `0o755` |
| Float | standard, scientific | `3.14`, `1e-10`, `inf` |
| Boolean | lowercase only | `true`, `false` |
| Null | tilde | `~` |
| Date/Time | ISO 8601 | `2026-02-02T10:30:00Z` |
| Array | brackets | `[1, 2, 3]` |
| Table | section header | `[section]` |

## Table Column Types

`str` `int` `float` `bool` `date` `datetime` `time` `duration` `any`

## String Escapes (double-quoted only)

`\\` `\"` `\n` `\r` `\t` `\uXXXX` `\u{X...}`

## Key Rules

- Zone names: `[a-zA-Z_][a-zA-Z0-9_-]*`
- Dot notation allowed: `@data:config.database`
- Comments: `#` (not in prose/raw/table/list content)
- Null in tables: `~`
- Trailing commas: allowed in arrays

## Zone Termination

| Zone | Ends With |
|------|-----------|
| data | Next `@` or EOF |
| prose | `@end` |
| table | `@end` |
| list | `@end` |
| raw | `@end` |
| seq | `@end` |

## Inline Tables & Arrays

```crisp
point = { x = 10, y = 20 }
tags = ["alpha", "beta", "gamma",]  # trailing comma OK
```

## Nested Tables

```crisp
[server]
host = "localhost"

[server.database]
name = "mydb"

[[routes]]           # Array of tables
path = "/api"
```

## Zone References (data zones only)

```crisp
@data:defaults
  timeout = 30

@data:production
  @ref defaults      # Must be first, inherits from defaults
  timeout = 60       # Override
```

## Multiline Strings

```crisp
description = """
  Baseline indent set by closing quotes.
  This line has no extra indent.
    This line has 2 spaces indent.
"""

literal = '''
No escape processing.
\n is literal backslash-n.
'''
```

## List Continuation

```crisp
@list:items [str]
  simple item
  |multi-line item
  |continues here
  another simple item
@end
```

## Table Escapes

| Escape | Meaning |
|--------|---------|
| `\t` | Literal TAB |
| `\n` | Literal newline |
| `\\` | Literal backslash |
| `\~` | Literal tilde (not null) |

## Seq Zone Entries

```crisp
@seq:chat
  [message role=user timestamp=2026-02-02T10:00:00Z]
    Hello!
  [/message]

  [message role=assistant]
    Hi there! How can I help?
  [/message]
@end
```

## Raw Zone with Custom Delimiter

```crisp
@raw:content [delim=@@@]
  Content with @end on its own line is fine
  @end
  Still going...
@@@
```

## Standard Preamble Directives

| Directive | Description |
|-----------|-------------|
| `%crisp` | Version (required if preamble exists) |
| `%schema` | Schema URI |
| `%id` | Document identifier |
| `%created` | Creation timestamp |
| `%modified` | Last modified timestamp |
| `%author` | Author name |
| `%title` | Document title |
| `%lang` | Language (BCP 47) |
| `%x-*` | Custom directives |

## File Extensions

- `.crisp` (preferred)
- `.crsp` (short form)
- `.crisp-schema` (schema files)
