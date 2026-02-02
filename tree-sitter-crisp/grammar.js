/**
 * @file Tree-sitter grammar for CRISP (Clear Readable Interchange for Structured Prose)
 * @author Claude
 * @license MIT
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

module.exports = grammar({
  name: 'crisp',

  externals: $ => [
    $._newline,
  ],

  extras: $ => [
    /[ \t]/,
  ],

  conflicts: $ => [
    [$.key_value, $.table_header],
  ],

  rules: {
    source_file: $ => seq(
      optional($.preamble),
      repeat($.zone),
    ),

    // ==================== PREAMBLE ====================

    preamble: $ => repeat1(choice(
      $.directive,
      $.comment,
      $._blank_line,
    )),

    directive: $ => seq(
      '%',
      field('name', $.directive_name),
      optional(field('value', $.directive_value)),
      $._line_ending,
    ),

    directive_name: _ => /[a-zA-Z][a-zA-Z0-9-]*/,

    directive_value: $ => choice(
      $.string,
      $.array,
      /[^\n\r]+/,
    ),

    // ==================== ZONES ====================

    zone: $ => choice(
      $.data_zone,
      $.prose_zone,
      $.table_zone,
      $.list_zone,
      $.raw_zone,
      $.seq_zone,
    ),

    // Data Zone
    data_zone: $ => seq(
      $.data_zone_marker,
      repeat(choice(
        $.key_value,
        $.table_header,
        $.array_table_header,
        $.reference,
        $.comment,
        $._blank_line,
      )),
    ),

    data_zone_marker: $ => seq(
      '@data:',
      field('name', $.zone_name),
      optional($.hints),
      $._line_ending,
    ),

    // Prose Zone
    prose_zone: $ => seq(
      $.prose_zone_marker,
      optional($.prose_content),
      $.zone_end,
    ),

    prose_zone_marker: $ => seq(
      '@prose:',
      field('name', $.zone_name),
      optional($.hints),
      $._line_ending,
    ),

    prose_content: $ => repeat1(choice(
      $.prose_line,
      $._blank_line,
    )),

    prose_line: $ => seq(
      /[^\n\r]+/,
      $._line_ending,
    ),

    // Table Zone
    table_zone: $ => seq(
      $.table_zone_marker,
      optional($.table_content),
      $.zone_end,
    ),

    table_zone_marker: $ => seq(
      '@table:',
      field('name', $.zone_name),
      field('columns', $.column_definitions),
      optional($.hints),
      $._line_ending,
    ),

    column_definitions: $ => seq(
      '[',
      commaSep1($.column_definition),
      ']',
    ),

    column_definition: $ => seq(
      field('name', $.identifier),
      ':',
      field('type', $.column_type),
    ),

    column_type: _ => choice(
      'str', 'int', 'float', 'bool',
      'date', 'datetime', 'time', 'duration', 'any',
    ),

    table_content: $ => repeat1(choice(
      $.table_row,
      $._blank_line,
    )),

    table_row: $ => seq(
      $.table_cell,
      repeat(seq('\t', $.table_cell)),
      $._line_ending,
    ),

    table_cell: $ => choice(
      $.null,
      $.escaped_cell,
      /[^\t\n\r]*/,
    ),

    escaped_cell: _ => /([^\t\n\r\\]|\\[tn\\~])*/,

    // List Zone
    list_zone: $ => seq(
      $.list_zone_marker,
      optional($.list_content),
      $.zone_end,
    ),

    list_zone_marker: $ => seq(
      '@list:',
      field('name', $.zone_name),
      field('type', $.list_type),
      optional($.hints),
      $._line_ending,
    ),

    list_type: $ => seq('[', $.column_type, ']'),

    list_content: $ => repeat1(choice(
      $.list_item,
      $.list_continuation,
      $._blank_line,
    )),

    list_item: $ => seq(
      choice(
        $.null,
        /[^\n\r|][^\n\r]*/,
      ),
      $._line_ending,
    ),

    list_continuation: $ => seq(
      '|',
      optional(/[^\n\r]+/),
      $._line_ending,
    ),

    // Raw Zone
    raw_zone: $ => seq(
      $.raw_zone_marker,
      optional($.raw_content),
      $.zone_end,
    ),

    raw_zone_marker: $ => seq(
      '@raw:',
      field('name', $.zone_name),
      optional($.hints),
      $._line_ending,
    ),

    raw_content: $ => repeat1(choice(
      $.raw_line,
      $._blank_line,
    )),

    raw_line: $ => seq(
      /[^\n\r]+/,
      $._line_ending,
    ),

    // Seq Zone
    seq_zone: $ => seq(
      $.seq_zone_marker,
      optional($.seq_content),
      $.zone_end,
    ),

    seq_zone_marker: $ => seq(
      '@seq:',
      field('name', $.zone_name),
      optional($.hints),
      $._line_ending,
    ),

    seq_content: $ => repeat1(choice(
      $.seq_entry,
      $.seq_text,
      $._blank_line,
    )),

    seq_entry: $ => seq(
      $.entry_open,
      optional($.entry_content),
      $.entry_close,
    ),

    entry_open: $ => seq(
      '[',
      field('type', $.identifier),
      repeat($.entry_attribute),
      ']',
      $._line_ending,
    ),

    entry_close: $ => seq(
      '[/',
      field('type', $.identifier),
      ']',
      $._line_ending,
    ),

    entry_attribute: $ => seq(
      field('name', $.identifier),
      '=',
      field('value', choice(
        $.string,
        $.number,
        $.identifier,
        $.datetime,
      )),
    ),

    entry_content: $ => repeat1(choice(
      $.seq_text,
      $.seq_entry,
      $._blank_line,
    )),

    seq_text: $ => seq(
      /[^\[\n\r][^\n\r]*/,
      $._line_ending,
    ),

    // Zone End
    zone_end: $ => seq(
      '@end',
      $._line_ending,
    ),

    zone_name: _ => /[a-zA-Z_][a-zA-Z0-9_.-]*/,

    hints: $ => seq(
      '[',
      commaSep($.hint),
      ']',
    ),

    hint: $ => choice(
      seq(
        field('name', $.identifier),
        '=',
        field('value', choice($.string, $.identifier)),
      ),
      field('name', $.identifier),
    ),

    // ==================== DATA ZONE CONTENT ====================

    reference: $ => seq(
      '@ref',
      field('target', $.zone_name),
      $._line_ending,
    ),

    table_header: $ => seq(
      '[',
      field('path', $.key_path),
      ']',
      $._line_ending,
    ),

    array_table_header: $ => seq(
      '[[',
      field('path', $.key_path),
      ']]',
      $._line_ending,
    ),

    key_path: $ => sep1($.key, '.'),

    key_value: $ => seq(
      field('key', $.key),
      '=',
      field('value', $._value),
      optional($.comment),
      $._line_ending,
    ),

    key: $ => choice(
      $.bare_key,
      $.string,
    ),

    bare_key: _ => /[a-zA-Z_][a-zA-Z0-9_-]*/,

    // ==================== VALUES ====================

    _value: $ => choice(
      $.string,
      $.number,
      $.boolean,
      $.null,
      $.datetime,
      $.date,
      $.time,
      $.duration,
      $.array,
      $.inline_table,
    ),

    // Strings
    string: $ => choice(
      $.basic_string,
      $.literal_string,
      $.multiline_basic_string,
      $.multiline_literal_string,
    ),

    basic_string: _ => seq(
      '"',
      repeat(choice(
        /[^"\\\n\r]+/,
        $.escape_sequence,
      )),
      '"',
    ),

    literal_string: _ => seq(
      "'",
      /[^'\n\r]*/,
      "'",
    ),

    multiline_basic_string: $ => seq(
      '"""',
      repeat(choice(
        /[^"\\]+/,
        $.escape_sequence,
        /"[^"]/,
        /""[^"]/,
      )),
      '"""',
    ),

    multiline_literal_string: _ => seq(
      "'''",
      repeat(choice(
        /[^']+/,
        /'[^']/,
        /''[^']/,
      )),
      "'''",
    ),

    escape_sequence: _ => token(seq(
      '\\',
      choice(
        /[btnfr"\\]/,
        /u[0-9a-fA-F]{4}/,
        /u\{[0-9a-fA-F]{1,6}\}/,
      ),
    )),

    // Numbers
    number: $ => choice(
      $.integer,
      $.float,
    ),

    integer: _ => choice(
      // Decimal
      /[+-]?\d[\d_]*/,
      // Hex
      /[+-]?0x[0-9a-fA-F][0-9a-fA-F_]*/,
      // Octal
      /[+-]?0o[0-7][0-7_]*/,
      // Binary
      /[+-]?0b[01][01_]*/,
    ),

    float: _ => choice(
      // Standard float
      /[+-]?\d[\d_]*\.\d[\d_]*/,
      // Scientific notation
      /[+-]?\d[\d_]*(\.\d[\d_]*)?[eE][+-]?\d+/,
      // Special values
      'inf',
      '-inf',
      'nan',
    ),

    boolean: _ => choice('true', 'false'),

    null: _ => '~',

    // Date/Time
    datetime: _ => /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})?/,

    date: _ => /\d{4}-\d{2}-\d{2}/,

    time: _ => /\d{2}:\d{2}:\d{2}(\.\d+)?/,

    duration: _ => /P(\d+Y)?(\d+M)?(\d+D)?(T(\d+H)?(\d+M)?(\d+(\.\d+)?S)?)?/,

    // Arrays
    array: $ => seq(
      '[',
      optional(commaSep($._value)),
      optional(','),
      ']',
    ),

    // Inline Tables
    inline_table: $ => seq(
      '{',
      optional(commaSep($.inline_key_value)),
      '}',
    ),

    inline_key_value: $ => seq(
      field('key', $.key),
      '=',
      field('value', $._value),
    ),

    // ==================== COMMON ====================

    comment: _ => seq('#', /[^\n\r]*/),

    identifier: _ => /[a-zA-Z_][a-zA-Z0-9_-]*/,

    _line_ending: _ => /\r?\n/,

    _blank_line: _ => /[ \t]*\r?\n/,
  },
});

/**
 * Creates a rule to match one or more of the rules separated by a comma
 * @param {RuleOrLiteral} rule
 * @returns {SeqRule}
 */
function commaSep1(rule) {
  return seq(rule, repeat(seq(',', optional(/[ \t]+/), rule)));
}

/**
 * Creates a rule to match zero or more of the rules separated by a comma
 * @param {RuleOrLiteral} rule
 * @returns {ChoiceRule}
 */
function commaSep(rule) {
  return optional(commaSep1(rule));
}

/**
 * Creates a rule to match one or more of the rules separated by a separator
 * @param {RuleOrLiteral} rule
 * @param {RuleOrLiteral} separator
 * @returns {SeqRule}
 */
function sep1(rule, separator) {
  return seq(rule, repeat(seq(separator, rule)));
}
