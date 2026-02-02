; CRISP Text Objects
; ==================
; For editors that support tree-sitter text objects (e.g., nvim-treesitter-textobjects)

; Zones as blocks
(data_zone) @block.outer
(prose_zone) @block.outer
(table_zone) @block.outer
(list_zone) @block.outer
(raw_zone) @block.outer
(seq_zone) @block.outer

; Zone content as inner blocks
(prose_content) @block.inner
(table_content) @block.inner
(list_content) @block.inner
(raw_content) @block.inner
(seq_content) @block.inner

; Key-value pairs as parameters/assignments
(key_value) @parameter.outer
(key_value
  value: (_) @parameter.inner)

(inline_key_value) @parameter.outer
(inline_key_value
  value: (_) @parameter.inner)

; Table rows
(table_row) @parameter.outer

; List items
(list_item) @parameter.outer

; Seq entries as functions/classes
(seq_entry) @function.outer
(entry_content) @function.inner

; Comments
(comment) @comment.outer

; Strings
(basic_string) @string.inner
(literal_string) @string.inner
(multiline_basic_string) @string.inner
(multiline_literal_string) @string.inner

; Arrays as calls
(array) @call.outer

; Table sections as classes
(table_header) @class.outer
(array_table_header) @class.outer

; Attributes in seq entries
(entry_attribute) @attribute.outer
(entry_attribute
  value: (_) @attribute.inner)
