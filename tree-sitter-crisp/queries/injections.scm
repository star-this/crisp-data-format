; CRISP Language Injections
; =========================
; Inject other languages into CRISP zones based on hints

; Inject markdown into prose zones
((prose_zone
  (prose_zone_marker
    (hints
      (hint
        name: (identifier) @_hint_name
        value: (identifier) @_hint_value)))
  (prose_content) @injection.content)
  (#eq? @_hint_name "format")
  (#any-of? @_hint_value "commonmark" "gfm" "markdown")
  (#set! injection.language "markdown"))

; Default prose injection (markdown)
((prose_zone
  (prose_content) @injection.content)
  (#set! injection.language "markdown")
  (#set! injection.include-children))

; Inject based on lang hint in raw zones
((raw_zone
  (raw_zone_marker
    (hints
      (hint
        name: (identifier) @_hint_name
        value: (identifier) @injection.language)))
  (raw_content) @injection.content)
  (#eq? @_hint_name "lang"))

; Common language injections for raw zones
((raw_zone
  (raw_zone_marker
    (hints
      (hint
        name: (identifier) @_hint_name
        value: (identifier) @_lang)))
  (raw_content) @injection.content)
  (#eq? @_hint_name "lang")
  (#eq? @_lang "html")
  (#set! injection.language "html"))

((raw_zone
  (raw_zone_marker
    (hints
      (hint
        name: (identifier) @_hint_name
        value: (identifier) @_lang)))
  (raw_content) @injection.content)
  (#eq? @_hint_name "lang")
  (#eq? @_lang "python")
  (#set! injection.language "python"))

((raw_zone
  (raw_zone_marker
    (hints
      (hint
        name: (identifier) @_hint_name
        value: (identifier) @_lang)))
  (raw_content) @injection.content)
  (#eq? @_hint_name "lang")
  (#eq? @_lang "javascript")
  (#set! injection.language "javascript"))

((raw_zone
  (raw_zone_marker
    (hints
      (hint
        name: (identifier) @_hint_name
        value: (identifier) @_lang)))
  (raw_content) @injection.content)
  (#eq? @_hint_name "lang")
  (#eq? @_lang "sql")
  (#set! injection.language "sql"))

((raw_zone
  (raw_zone_marker
    (hints
      (hint
        name: (identifier) @_hint_name
        value: (identifier) @_lang)))
  (raw_content) @injection.content)
  (#eq? @_hint_name "lang")
  (#eq? @_lang "json")
  (#set! injection.language "json"))

((raw_zone
  (raw_zone_marker
    (hints
      (hint
        name: (identifier) @_hint_name
        value: (identifier) @_lang)))
  (raw_content) @injection.content)
  (#eq? @_hint_name "lang")
  (#eq? @_lang "yaml")
  (#set! injection.language "yaml"))

((raw_zone
  (raw_zone_marker
    (hints
      (hint
        name: (identifier) @_hint_name
        value: (identifier) @_lang)))
  (raw_content) @injection.content)
  (#eq? @_hint_name "lang")
  (#eq? @_lang "css")
  (#set! injection.language "css"))

((raw_zone
  (raw_zone_marker
    (hints
      (hint
        name: (identifier) @_hint_name
        value: (identifier) @_lang)))
  (raw_content) @injection.content)
  (#eq? @_hint_name "lang")
  (#eq? @_lang "elixir")
  (#set! injection.language "elixir"))

((raw_zone
  (raw_zone_marker
    (hints
      (hint
        name: (identifier) @_hint_name
        value: (identifier) @_lang)))
  (raw_content) @injection.content)
  (#eq? @_hint_name "lang")
  (#eq? @_lang "rust")
  (#set! injection.language "rust"))

((raw_zone
  (raw_zone_marker
    (hints
      (hint
        name: (identifier) @_hint_name
        value: (identifier) @_lang)))
  (raw_content) @injection.content)
  (#eq? @_hint_name "lang")
  (#eq? @_lang "go")
  (#set! injection.language "go"))

((raw_zone
  (raw_zone_marker
    (hints
      (hint
        name: (identifier) @_hint_name
        value: (identifier) @_lang)))
  (raw_content) @injection.content)
  (#eq? @_hint_name "lang")
  (#eq? @_lang "typescript")
  (#set! injection.language "typescript"))

((raw_zone
  (raw_zone_marker
    (hints
      (hint
        name: (identifier) @_hint_name
        value: (identifier) @_lang)))
  (raw_content) @injection.content)
  (#eq? @_hint_name "lang")
  (#eq? @_lang "bash")
  (#set! injection.language "bash"))

((raw_zone
  (raw_zone_marker
    (hints
      (hint
        name: (identifier) @_hint_name
        value: (identifier) @_lang)))
  (raw_content) @injection.content)
  (#eq? @_hint_name "lang")
  (#eq? @_lang "sh")
  (#set! injection.language "bash"))

; Inject regex into pattern values in schemas
((key_value
  key: (key) @_key
  value: (basic_string) @injection.content)
  (#eq? @_key "pattern")
  (#set! injection.language "regex"))
