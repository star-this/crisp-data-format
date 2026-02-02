# tree-sitter-crisp

Tree-sitter grammar for [CRISP](../SPEC.md) (Clear Readable Interchange for Structured Prose).

## Features

- Full syntax highlighting for all CRISP zone types
- Language injection support (Markdown in prose zones, custom languages in raw zones)
- Code folding for zones and nested structures
- Text objects for editor integrations
- Auto-indentation rules

## Installation

### npm

```bash
npm install tree-sitter-crisp
```

### Build from source

```bash
npm install
npm run generate
npm run build
```

### WebAssembly

```bash
npm run build-wasm
```

## Editor Integration

### Neovim (nvim-treesitter)

Add to your nvim-treesitter configuration:

```lua
local parser_config = require("nvim-treesitter.parsers").get_parser_configs()

parser_config.crisp = {
  install_info = {
    url = "https://github.com/star-this/crisp-data-format",
    files = { "tree-sitter-crisp/src/parser.c" },
    location = "tree-sitter-crisp",
    branch = "main",
  },
  filetype = "crisp",
}

vim.filetype.add({
  extension = {
    crisp = "crisp",
    crsp = "crisp",
    ["crisp-schema"] = "crisp",
  },
})
```

Then copy the query files to your Neovim configuration:

```bash
mkdir -p ~/.config/nvim/queries/crisp
cp queries/*.scm ~/.config/nvim/queries/crisp/
```

### Helix

Add to `~/.config/helix/languages.toml`:

```toml
[[language]]
name = "crisp"
scope = "source.crisp"
file-types = ["crisp", "crsp", "crisp-schema"]
comment-token = "#"
indent = { tab-width = 2, unit = "  " }

[[grammar]]
name = "crisp"
source = { git = "https://github.com/star-this/crisp-data-format", subpath = "tree-sitter-crisp", rev = "main" }
```

Then copy query files:

```bash
mkdir -p ~/.config/helix/runtime/queries/crisp
cp queries/*.scm ~/.config/helix/runtime/queries/crisp/
```

### Zed

Create `~/.config/zed/languages/crisp/`:

```
crisp/
├── config.toml
├── highlights.scm
├── injections.scm
└── indents.scm
```

`config.toml`:
```toml
name = "CRISP"
grammar = "crisp"
path_suffixes = ["crisp", "crsp", "crisp-schema"]
line_comments = ["# "]
```

### VS Code

Use the TextMate grammar in `../editors/vscode/` or create a tree-sitter extension.

### Emacs (tree-sitter)

```elisp
(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(crisp "https://github.com/star-this/crisp-data-format" "main" "tree-sitter-crisp/src")))

(define-derived-mode crisp-ts-mode prog-mode "CRISP"
  "Major mode for CRISP files using tree-sitter."
  (when (treesit-ready-p 'crisp)
    (treesit-parser-create 'crisp)
    (setq-local treesit-font-lock-settings
                (treesit-font-lock-rules
                 :language 'crisp
                 :feature 'comment
                 '((comment) @font-lock-comment-face)
                 :feature 'keyword
                 '((directive_name) @font-lock-keyword-face
                   "@data:" @font-lock-keyword-face
                   "@prose:" @font-lock-keyword-face
                   "@table:" @font-lock-keyword-face
                   "@list:" @font-lock-keyword-face
                   "@raw:" @font-lock-keyword-face
                   "@seq:" @font-lock-keyword-face
                   "@end" @font-lock-keyword-face
                   "@ref" @font-lock-keyword-face)
                 :feature 'string
                 '((basic_string) @font-lock-string-face
                   (literal_string) @font-lock-string-face)
                 :feature 'number
                 '((integer) @font-lock-number-face
                   (float) @font-lock-number-face)
                 :feature 'constant
                 '((boolean) @font-lock-constant-face
                   (null) @font-lock-constant-face)))))

(add-to-list 'auto-mode-alist '("\\.crisp\\'" . crisp-ts-mode))
(add-to-list 'auto-mode-alist '("\\.crsp\\'" . crisp-ts-mode))
(add-to-list 'auto-mode-alist '("\\.crisp-schema\\'" . crisp-ts-mode))
```

## Query Files

| File | Purpose |
|------|---------|
| `highlights.scm` | Syntax highlighting |
| `injections.scm` | Language injection (Markdown, HTML, etc.) |
| `locals.scm` | Local scope tracking |
| `indents.scm` | Auto-indentation |
| `folds.scm` | Code folding |
| `textobjects.scm` | Text object selection |

## Language Injection

The grammar supports automatic language injection based on zone hints:

```crisp
@prose:readme [format=commonmark]
  # This is highlighted as Markdown
@end

@raw:script [lang=python]
  # This is highlighted as Python
  def hello():
      print("Hello, World!")
@end
```

Supported `lang` values for raw zones:
- `html`, `python`, `javascript`, `typescript`, `sql`, `json`, `yaml`, `css`, `elixir`, `rust`, `go`, `bash`, `sh`

## Testing

```bash
npm test
```

## License

MIT
