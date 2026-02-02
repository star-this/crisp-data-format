# CRISP — Clear Readable Interchange for Structured Prose

[![Hex.pm](https://img.shields.io/hexpm/v/crisp.svg)](https://hex.pm/packages/crisp)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/crisp)

CRISP is a text-based file format designed for **human-agent collaboration**, combining structured data, prose content, and tabular information in a single, coherent document.

## Why CRISP?

- **Human-First, Machine-Friendly** — Readable without tooling, parseable with precision
- **Zone-Based** — Different content types have clear, well-defined parsing rules
- **Safe by Default** — No code execution vectors, no dangerous type coercion
- **Streaming-Compatible** — Documents can be parsed incrementally as they're generated
- **Schema-Aware** — Optional but first-class validation support

## Installation

Add `crisp` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:crisp, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
# Parse a CRISP document
content = """
%crisp 1.0
%title "My Application"

@data:config
  name = "my-app"
  version = "1.0.0"
  debug = false

  [server]
  host = "localhost"
  port = 8080

@prose:readme
  # Welcome

  This is a **CRISP** document combining structured
  data with human-readable content.
@end

@table:users [id:int, name:str, active:bool]
  1	Alice	true
  2	Bob	false
@end
"""

{:ok, doc} = Crisp.decode(content)

# Access zones
config = Crisp.get_zone(doc, :data, "config")
config.content["name"]  # => "my-app"
config.content["server"]["port"]  # => 8080

readme = Crisp.get_zone(doc, :prose, "readme")
readme.content  # => "# Welcome\n\nThis is a **CRISP** document..."

users = Crisp.get_zone(doc, :table, "users")
users.content  # => [%{"id" => 1, "name" => "Alice", "active" => true}, ...]

# Encode back to string
{:ok, output} = Crisp.encode(doc)
```

## Zone Types

CRISP supports six zone types, each optimized for different content:

### Data Zones (TOML-compatible)

```crisp
@data:config
  name = "example"
  count = 42
  enabled = true
  tags = ["alpha", "beta"]

  [server]
  host = "localhost"
  port = 8080

  [[routes]]
  path = "/api"
  method = "GET"
```

### Prose Zones (Markdown)

```crisp
@prose:documentation
  # API Documentation

  This endpoint returns a list of **users**.

  ## Parameters

  - `limit`: Maximum number of results
  - `offset`: Pagination offset
@end
```

### Table Zones (Typed TSV)

```crisp
@table:inventory [id:int, sku:str, price:float, active:bool]
  1	SKU-001	9.99	true
  2	SKU-002	24.99	true
  3	SKU-003	~	false
@end
```

Column types: `str`, `int`, `float`, `bool`, `date`, `datetime`, `time`, `duration`, `any`

### List Zones

```crisp
@list:allowed-hosts [str]
  localhost
  127.0.0.1
  example.com
@end

@list:primes [int]
  2
  3
  5
  7
@end
```

### Raw Zones (Verbatim)

```crisp
@raw:template [lang=html]
<!DOCTYPE html>
<html>
  <body>{{ content }}</body>
</html>
@end
```

### Seq Zones (Ordered Entries)

```crisp
@seq:conversation
  [message role=user timestamp=2026-02-02T10:00:00Z]
    What is the capital of France?
  [/message]

  [message role=assistant]
    The capital of France is **Paris**.
  [/message]
@end
```

## Data Types

| Type | Syntax | Examples |
|------|--------|----------|
| String | `"..."` `'...'` `"""..."""` | `"hello"`, `'raw\n'` |
| Integer | decimal, 0x, 0o, 0b | `42`, `0xFF`, `0o755` |
| Float | standard, scientific | `3.14`, `1e-10`, `inf` |
| Boolean | lowercase only | `true`, `false` |
| Null | tilde | `~` |
| DateTime | ISO 8601 | `2026-02-02T10:30:00Z` |
| Array | brackets | `[1, 2, 3]` |
| Table | section header | `[section]` |

## Zone References

Data zones can inherit from other zones:

```crisp
@data:defaults
  timeout = 30
  retries = 3

@data:production
  @ref defaults
  timeout = 60  # Override
```

## Schema Validation

Create a `.crisp-schema` file:

```crisp
%crisp 1.0
%schema-version 1.0

@data:schema
  [document]
  required_zones = ["config"]

  [zones.config.fields.name]
  type = "string"
  required = true
  pattern = "^[a-z][a-z0-9-]*$"

  [zones.config.fields.version]
  type = "string"
  format = "semver"
```

Validate a document:

```elixir
{:ok, doc} = Crisp.decode_file("config.crisp")
{:ok, schema} = Crisp.decode_file("config.crisp-schema")
{:ok, errors} = Crisp.validate(doc, schema)

if errors == [] do
  IO.puts("Document is valid!")
else
  for error <- errors do
    IO.puts("#{error.path}: #{error.message}")
  end
end
```

## Building Documents Programmatically

```elixir
doc = Crisp.new(title: "My Document", author: "Alice")
|> Crisp.add_zone(:data, "config", %{
  "name" => "my-app",
  "version" => "1.0.0"
})
|> Crisp.add_zone(:prose, "readme", """
# Hello World

This is generated content.
""")
|> Crisp.add_zone(:table, "users", [
  %{"id" => 1, "name" => "Alice"},
  %{"id" => 2, "name" => "Bob"}
], columns: [
  %{name: "id", type: "int"},
  %{name: "name", type: "str"}
])

{:ok, output} = Crisp.encode(doc)
File.write!("output.crisp", output)
```

## API Reference

### Decoding

```elixir
# From string
{:ok, doc} = Crisp.decode(content)
doc = Crisp.decode!(content)  # Raises on error

# From file
{:ok, doc} = Crisp.decode_file("path/to/file.crisp")
doc = Crisp.decode_file!("path/to/file.crisp")
```

### Encoding

```elixir
# To string
{:ok, output} = Crisp.encode(doc)
output = Crisp.encode!(doc)

# To file
:ok = Crisp.encode_file(doc, "path/to/output.crisp")

# With options
{:ok, output} = Crisp.encode(doc, indent: 4, line_ending: :crlf)
```

### Zone Access

```elixir
# Get specific zone
zone = Crisp.get_zone(doc, :data, "config")

# Get all zones of a type
data_zones = Crisp.get_zones_by_type(doc, :data)

# Access zone content
zone.type     # => :data
zone.name     # => "config"
zone.content  # => %{"name" => "example", ...}
zone.hints    # => %{} or %{columns: [...]}
```

### Validation

```elixir
{:ok, errors} = Crisp.validate(doc, schema_doc)
{:ok, errors} = Crisp.validate(doc, schema_string)
```

## File Extensions

- `.crisp` — Standard CRISP document
- `.crsp` — Short form
- `.crisp-schema` — Schema definition

## Comparison with Alternatives

| Feature | CRISP | YAML | TOML | JSON |
|---------|-------|------|------|------|
| Human readable | ✅ | ✅ | ✅ | ⚠️ |
| Comments | ✅ | ✅ | ✅ | ❌ |
| Prose content | ✅ | ⚠️ | ❌ | ❌ |
| Typed tables | ✅ | ❌ | ❌ | ❌ |
| Safe parsing | ✅ | ❌ | ✅ | ✅ |
| Streaming | ✅ | ⚠️ | ⚠️ | ⚠️ |
| Schema support | ✅ | ⚠️ | ❌ | ⚠️ |
| Null values | ✅ | ✅ | ❌ | ✅ |

## Documentation

- [Full Specification](SPEC.md)
- [Quick Reference](CHEATSHEET.md)
- [Examples](examples/)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `mix test`
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.
