; CRISP Indentation Rules
; =======================

; Indent after zone markers
(data_zone_marker) @indent.begin
(prose_zone_marker) @indent.begin
(table_zone_marker) @indent.begin
(list_zone_marker) @indent.begin
(raw_zone_marker) @indent.begin
(seq_zone_marker) @indent.begin

; Dedent at zone end
(zone_end) @indent.dedent @indent.branch

; Indent inside seq entries
(entry_open) @indent.begin
(entry_close) @indent.dedent @indent.branch

; Indent after table headers
(table_header) @indent.begin
(array_table_header) @indent.begin

; Indent inside arrays
(array
  "[" @indent.begin
  "]" @indent.end)

; Indent inside inline tables
(inline_table
  "{" @indent.begin
  "}" @indent.end)

; Indent inside multiline strings
(multiline_basic_string) @indent.begin @indent.end
(multiline_literal_string) @indent.begin @indent.end
