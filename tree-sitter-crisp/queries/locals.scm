; CRISP Local Scopes
; ==================

; Zones create scopes
(data_zone) @local.scope
(prose_zone) @local.scope
(table_zone) @local.scope
(list_zone) @local.scope
(raw_zone) @local.scope
(seq_zone) @local.scope

; Seq entries create nested scopes
(seq_entry) @local.scope

; Zone names are definitions
(data_zone_marker
  name: (zone_name) @local.definition)

(prose_zone_marker
  name: (zone_name) @local.definition)

(table_zone_marker
  name: (zone_name) @local.definition)

(list_zone_marker
  name: (zone_name) @local.definition)

(raw_zone_marker
  name: (zone_name) @local.definition)

(seq_zone_marker
  name: (zone_name) @local.definition)

; Key definitions
(key_value
  key: (key) @local.definition)

; Table header definitions
(table_header
  path: (key_path) @local.definition)

(array_table_header
  path: (key_path) @local.definition)

; Column definitions
(column_definition
  name: (identifier) @local.definition)

; References to zones
(reference
  target: (zone_name) @local.reference)
