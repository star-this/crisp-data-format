; CRISP Syntax Highlighting Queries
; =================================

; ==================== COMMENTS ====================

(comment) @comment

; ==================== PREAMBLE ====================

(directive
  "%" @punctuation.special
  name: (directive_name) @keyword.directive
  value: (_) @string)

; ==================== ZONE MARKERS ====================

(data_zone_marker
  "@data:" @keyword.control
  name: (zone_name) @namespace)

(prose_zone_marker
  "@prose:" @keyword.control
  name: (zone_name) @namespace)

(table_zone_marker
  "@table:" @keyword.control
  name: (zone_name) @namespace)

(list_zone_marker
  "@list:" @keyword.control
  name: (zone_name) @namespace)

(raw_zone_marker
  "@raw:" @keyword.control
  name: (zone_name) @namespace)

(seq_zone_marker
  "@seq:" @keyword.control
  name: (zone_name) @namespace)

(zone_end
  "@end" @keyword.control)

; ==================== ZONE NAMES & HINTS ====================

(zone_name) @namespace

(hints
  "[" @punctuation.bracket
  "]" @punctuation.bracket)

(hint
  name: (identifier) @property
  "=" @operator
  value: (_) @string)

; ==================== DATA ZONE ====================

; References
(reference
  "@ref" @keyword.control
  target: (zone_name) @namespace)

; Table headers
(table_header
  "[" @punctuation.bracket
  path: (key_path) @type
  "]" @punctuation.bracket)

(array_table_header
  "[[" @punctuation.bracket
  path: (key_path) @type
  "]]" @punctuation.bracket)

; Key-value pairs
(key_value
  key: (key) @property
  "=" @operator)

(bare_key) @property

(inline_key_value
  key: (key) @property
  "=" @operator)

; ==================== TABLE ZONE ====================

(column_definitions
  "[" @punctuation.bracket
  "]" @punctuation.bracket)

(column_definition
  name: (identifier) @property
  ":" @punctuation.delimiter
  type: (column_type) @type.builtin)

(table_cell) @string

; ==================== LIST ZONE ====================

(list_type
  "[" @punctuation.bracket
  (column_type) @type.builtin
  "]" @punctuation.bracket)

(list_item) @string

(list_continuation
  "|" @punctuation.special)

; ==================== SEQ ZONE ====================

(entry_open
  "[" @punctuation.bracket
  type: (identifier) @tag
  "]" @punctuation.bracket)

(entry_close
  "[/" @punctuation.bracket
  type: (identifier) @tag
  "]" @punctuation.bracket)

(entry_attribute
  name: (identifier) @attribute
  "=" @operator)

(seq_text) @text

; ==================== VALUES ====================

; Strings
(basic_string) @string
(literal_string) @string
(multiline_basic_string) @string
(multiline_literal_string) @string

(escape_sequence) @string.escape

; Numbers
(integer) @number
(float) @number.float

; Special float values
((float) @constant.builtin
  (#any-of? @constant.builtin "inf" "-inf" "nan"))

; Booleans
(boolean) @boolean

; Null
(null) @constant.builtin

; Date/Time
(datetime) @string.special
(date) @string.special
(time) @string.special
(duration) @string.special

; ==================== ARRAYS & TABLES ====================

(array
  "[" @punctuation.bracket
  "]" @punctuation.bracket)

(inline_table
  "{" @punctuation.bracket
  "}" @punctuation.bracket)

; ==================== PUNCTUATION ====================

"," @punctuation.delimiter
"." @punctuation.delimiter
":" @punctuation.delimiter
"=" @operator

; ==================== PROSE ZONE CONTENT ====================

; In prose zones, treat content as markup/text
(prose_content
  (prose_line) @text.literal)

; ==================== RAW ZONE CONTENT ====================

; In raw zones, treat content as embedded/verbatim
(raw_content
  (raw_line) @text.literal)
