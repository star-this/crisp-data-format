defmodule Crisp.Lexer do
  @moduledoc """
  Lexer/Tokenizer for CRISP documents.

  Breaks down CRISP content into tokens that the parser can consume.
  The lexer is context-aware - different zones have different lexing rules.
  """

  @type token_type ::
          :directive
          | :zone_marker
          | :zone_end
          | :comment
          | :newline
          | :blank
          | :key
          | :equals
          | :string
          | :integer
          | :float
          | :boolean
          | :null
          | :datetime
          | :date
          | :time
          | :duration
          | :lbracket
          | :rbracket
          | :lbrace
          | :rbrace
          | :double_lbracket
          | :double_rbracket
          | :comma
          | :dot
          | :tab
          | :text
          | :pipe
          | :entry_open
          | :entry_close
          | :ref
          | :eof

  @type token :: {token_type(), term(), non_neg_integer(), non_neg_integer()}

  @type context :: :preamble | :data | :prose | :table | :list | :raw | :seq

  @doc """
  Tokenizes a CRISP document string.

  Returns a list of tokens or an error.
  """
  @spec tokenize(String.t()) :: {:ok, [token()]} | {:error, Crisp.Error.t()}
  def tokenize(input) when is_binary(input) do
    # Normalize line endings
    input = String.replace(input, "\r\n", "\n")

    lines = String.split(input, "\n", trim: false)

    try do
      {tokens, _context} = tokenize_lines(lines, 1, :preamble, [])
      {:ok, Enum.reverse([{:eof, nil, length(lines) + 1, 1} | tokens])}
    rescue
      e in Crisp.Error -> {:error, e}
    catch
      {:error, error} -> {:error, error}
    end
  end

  defp tokenize_lines([], _line_num, _context, tokens), do: {tokens, :eof}

  defp tokenize_lines([line | rest], line_num, context, tokens) do
    {line_tokens, new_context} = tokenize_line(line, line_num, context)
    new_tokens = Enum.reverse(line_tokens) ++ tokens
    tokenize_lines(rest, line_num + 1, new_context, new_tokens)
  end

  defp tokenize_line(line, line_num, context) do
    cond do
      # Empty line
      String.trim(line) == "" ->
        {[{:blank, "", line_num, 1}], context}

      # Directive line (preamble)
      String.starts_with?(line, "%") ->
        tokenize_directive(line, line_num, context)

      # Zone marker
      String.match?(line, ~r/^\s*@(data|prose|table|list|raw|seq):/) ->
        tokenize_zone_marker(line, line_num)

      # Zone end
      String.match?(line, ~r/^\s*@end\s*$/) ->
        {[{:zone_end, nil, line_num, 1}], :preamble}

      # Context-specific tokenization
      true ->
        tokenize_in_context(line, line_num, context)
    end
  end

  defp tokenize_directive(line, line_num, context) do
    case Regex.run(~r/^%([a-zA-Z][a-zA-Z0-9-]*)\s*(.*)$/, line) do
      [_, name, value] ->
        parsed_value = parse_directive_value(String.trim(value))
        {[{:directive, {name, parsed_value}, line_num, 1}], context}

      nil ->
        throw({:error, Crisp.Error.syntax_error("Invalid directive", line: line_num)})
    end
  end

  defp parse_directive_value(""), do: nil
  defp parse_directive_value("\"" <> _ = str), do: parse_basic_string(str)
  defp parse_directive_value("[" <> _ = str), do: parse_inline_array(str)
  defp parse_directive_value(value), do: value

  defp tokenize_zone_marker(line, line_num) do
    # Parse: @type:name [hints]
    pattern = ~r/^\s*@(data|prose|table|list|raw|seq):([a-zA-Z_][a-zA-Z0-9_.-]*)\s*(\[.*\])?\s*$/

    case Regex.run(pattern, line) do
      [_, type, name, hints] ->
        zone_type = String.to_atom(type)
        parsed_hints = parse_hints(hints, zone_type)
        {[{:zone_marker, {zone_type, name, parsed_hints}, line_num, 1}], zone_type}

      [_, type, name] ->
        zone_type = String.to_atom(type)
        {[{:zone_marker, {zone_type, name, %{}}, line_num, 1}], zone_type}

      nil ->
        throw({:error, Crisp.Error.syntax_error("Invalid zone marker", line: line_num)})
    end
  end

  defp parse_hints(nil, _), do: %{}
  defp parse_hints("", _), do: %{}

  defp parse_hints(hints_str, zone_type) when zone_type in [:table, :list] do
    # For table: [col:type, col:type, ...]
    # For list: [type]
    inner = String.slice(hints_str, 1..-2//1) |> String.trim()
    parse_type_hints(inner, zone_type)
  end

  defp parse_hints(hints_str, _zone_type) do
    # Generic hints: [key=value, key=value, ...]
    inner = String.slice(hints_str, 1..-2//1) |> String.trim()
    parse_generic_hints(inner)
  end

  defp parse_type_hints(inner, :table) do
    columns =
      inner
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(fn col_def ->
        case String.split(col_def, ":", parts: 2) do
          [name, type] -> %{name: String.trim(name), type: String.trim(type)}
          [name] -> %{name: String.trim(name), type: "any"}
        end
      end)

    %{columns: columns}
  end

  defp parse_type_hints(inner, :list) do
    %{item_type: String.trim(inner)}
  end

  defp parse_generic_hints(""), do: %{}

  defp parse_generic_hints(inner) do
    inner
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reduce(%{}, fn hint, acc ->
      case String.split(hint, "=", parts: 2) do
        [key, value] ->
          Map.put(acc, String.trim(key), parse_hint_value(String.trim(value)))

        [key] ->
          Map.put(acc, String.trim(key), true)
      end
    end)
  end

  defp parse_hint_value("\"" <> _ = str), do: parse_basic_string(str)
  defp parse_hint_value(value), do: value

  defp tokenize_in_context(line, line_num, :preamble) do
    # In preamble, treat non-directive lines as transitioning to implicit data
    if String.starts_with?(String.trim(line), "#") do
      {[{:comment, String.trim(line), line_num, 1}], :preamble}
    else
      tokenize_in_context(line, line_num, :data)
    end
  end

  defp tokenize_in_context(line, line_num, :data) do
    tokenize_data_line(line, line_num)
  end

  defp tokenize_in_context(line, line_num, :prose) do
    # Prose content is passed through as text
    {[{:text, line, line_num, 1}], :prose}
  end

  defp tokenize_in_context(line, line_num, :table) do
    # Table rows are tab-separated
    tokenize_table_line(line, line_num)
  end

  defp tokenize_in_context(line, line_num, :list) do
    tokenize_list_line(line, line_num)
  end

  defp tokenize_in_context(line, line_num, :raw) do
    # Raw content is passed through verbatim
    {[{:text, line, line_num, 1}], :raw}
  end

  defp tokenize_in_context(line, line_num, :seq) do
    tokenize_seq_line(line, line_num)
  end

  defp tokenize_data_line(line, line_num) do
    trimmed = String.trim(line)

    cond do
      # Comment
      String.starts_with?(trimmed, "#") ->
        {[{:comment, trimmed, line_num, 1}], :data}

      # Reference
      String.starts_with?(trimmed, "@ref ") ->
        ref_name = String.trim(String.slice(trimmed, 5..-1//1))
        {[{:ref, ref_name, line_num, 1}], :data}

      # Array of tables header [[name]]
      String.match?(trimmed, ~r/^\[\[.+\]\]$/) ->
        name = String.slice(trimmed, 2..-3//1)
        {[{:double_lbracket, name, line_num, 1}], :data}

      # Table header [name]
      String.match?(trimmed, ~r/^\[.+\]$/) ->
        name = String.slice(trimmed, 1..-2//1)
        {[{:lbracket, name, line_num, 1}], :data}

      # Key-value pair
      String.contains?(trimmed, "=") ->
        tokenize_key_value(trimmed, line_num)

      true ->
        {[{:text, line, line_num, 1}], :data}
    end
  end

  defp tokenize_key_value(line, line_num) do
    case String.split(line, "=", parts: 2) do
      [key_part, value_part] ->
        key = String.trim(key_part)
        value_str = String.trim(value_part)

        # Handle inline comment
        {value_str, comment} = extract_inline_comment(value_str)

        value_token = tokenize_value(value_str, line_num)

        tokens = [{:key, key, line_num, 1}, {:equals, nil, line_num, String.length(key_part) + 1}]
        tokens = tokens ++ [value_token]
        tokens = if comment, do: tokens ++ [{:comment, comment, line_num, 1}], else: tokens

        {tokens, :data}

      _ ->
        throw({:error, Crisp.Error.syntax_error("Invalid key-value pair", line: line_num)})
    end
  end

  defp extract_inline_comment(value_str) do
    # Don't extract comments from inside strings
    if String.starts_with?(value_str, "\"") or String.starts_with?(value_str, "'") or
         String.starts_with?(value_str, "[") or String.starts_with?(value_str, "{") do
      {value_str, nil}
    else
      case String.split(value_str, "#", parts: 2) do
        [value, comment] -> {String.trim(value), "#" <> comment}
        [value] -> {value, nil}
      end
    end
  end

  defp tokenize_value(str, line_num) do
    cond do
      # Multiline basic string
      String.starts_with?(str, ~s(""")) ->
        {:string, parse_multiline_basic_string(str), line_num, 1}

      # Multiline literal string
      String.starts_with?(str, "'''") ->
        {:string, parse_multiline_literal_string(str), line_num, 1}

      # Basic string
      String.starts_with?(str, "\"") ->
        {:string, parse_basic_string(str), line_num, 1}

      # Literal string
      String.starts_with?(str, "'") ->
        {:string, parse_literal_string(str), line_num, 1}

      # Array
      String.starts_with?(str, "[") ->
        {:array, parse_inline_array(str), line_num, 1}

      # Inline table
      String.starts_with?(str, "{") ->
        {:inline_table, parse_inline_table(str), line_num, 1}

      # Boolean
      str == "true" ->
        {:boolean, true, line_num, 1}

      str == "false" ->
        {:boolean, false, line_num, 1}

      # Null
      str == "~" ->
        {:null, nil, line_num, 1}

      # Special floats
      str == "inf" ->
        {:float, :infinity, line_num, 1}

      str == "-inf" ->
        {:float, :neg_infinity, line_num, 1}

      str == "nan" ->
        {:float, :nan, line_num, 1}

      # Duration (ISO 8601)
      String.match?(str, ~r/^P(\d+Y)?(\d+M)?(\d+D)?(T(\d+H)?(\d+M)?(\d+(\.\d+)?S)?)?$/) ->
        {:duration, str, line_num, 1}

      # DateTime with timezone
      String.match?(str, ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/) ->
        {:datetime, parse_datetime(str), line_num, 1}

      # Local datetime
      String.match?(str, ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?$/) ->
        {:datetime, parse_naive_datetime(str), line_num, 1}

      # Date only
      String.match?(str, ~r/^\d{4}-\d{2}-\d{2}$/) ->
        {:date, parse_date(str), line_num, 1}

      # Time only
      String.match?(str, ~r/^\d{2}:\d{2}:\d{2}(\.\d+)?$/) ->
        {:time, parse_time(str), line_num, 1}

      # Hex integer
      String.match?(str, ~r/^[+-]?0x[0-9a-fA-F_]+$/) ->
        {:integer, parse_hex_integer(str), line_num, 1}

      # Octal integer
      String.match?(str, ~r/^[+-]?0o[0-7_]+$/) ->
        {:integer, parse_octal_integer(str), line_num, 1}

      # Binary integer
      String.match?(str, ~r/^[+-]?0b[01_]+$/) ->
        {:integer, parse_binary_integer(str), line_num, 1}

      # Float (including scientific notation)
      String.match?(str, ~r/^[+-]?\d[\d_]*(\.\d[\d_]*)?([eE][+-]?\d+)?$/) and
          (String.contains?(str, ".") or String.contains?(str, "e") or
             String.contains?(str, "E")) ->
        {:float, parse_float(str), line_num, 1}

      # Decimal integer
      String.match?(str, ~r/^[+-]?\d[\d_]*$/) ->
        {:integer, parse_integer(str), line_num, 1}

      true ->
        # Unquoted string or identifier
        {:string, str, line_num, 1}
    end
  end

  defp tokenize_table_line(line, line_num) do
    # Split by tabs, preserving empty cells
    cells = String.split(line, "\t", trim: false)
    tokens = Enum.with_index(cells, fn cell, idx -> {:cell, cell, line_num, idx + 1} end)
    {[{:table_row, tokens, line_num, 1}], :table}
  end

  defp tokenize_list_line(line, line_num) do
    trimmed = String.trim(line)

    cond do
      String.starts_with?(trimmed, "|") ->
        # Continuation line
        content = String.slice(trimmed, 1..-1//1)
        content = if String.starts_with?(content, " "), do: String.slice(content, 1..-1//1), else: content
        {[{:continuation, content, line_num, 1}], :list}

      trimmed == "" ->
        {[{:blank, "", line_num, 1}], :list}

      true ->
        {[{:list_item, trimmed, line_num, 1}], :list}
    end
  end

  defp tokenize_seq_line(line, line_num) do
    trimmed = String.trim(line)

    cond do
      # Entry close tag
      String.match?(trimmed, ~r/^\[\/[a-zA-Z_][a-zA-Z0-9_-]*\]$/) ->
        name = Regex.run(~r/^\[\/([a-zA-Z_][a-zA-Z0-9_-]*)\]$/, trimmed) |> Enum.at(1)
        {[{:entry_close, name, line_num, 1}], :seq}

      # Entry open tag with attributes
      String.match?(trimmed, ~r/^\[[a-zA-Z_][a-zA-Z0-9_-]*(\s+.*)?\]$/) ->
        {name, attrs} = parse_entry_open(trimmed)
        {[{:entry_open, {name, attrs}, line_num, 1}], :seq}

      trimmed == "" ->
        {[{:blank, "", line_num, 1}], :seq}

      true ->
        {[{:text, line, line_num, 1}], :seq}
    end
  end

  defp parse_entry_open(str) do
    # Remove brackets
    inner = String.slice(str, 1..-2//1) |> String.trim()

    case String.split(inner, ~r/\s+/, parts: 2) do
      [name] ->
        {name, %{}}

      [name, attrs_str] ->
        attrs = parse_entry_attributes(attrs_str)
        {name, attrs}
    end
  end

  defp parse_entry_attributes(str) do
    # Parse: key=value key="value" key=123
    regex = ~r/([a-zA-Z_][a-zA-Z0-9_-]*)=("[^"]*"|'[^']*'|[^\s]+)/

    Regex.scan(regex, str)
    |> Enum.reduce(%{}, fn [_, key, value], acc ->
      parsed_value =
        cond do
          String.starts_with?(value, "\"") -> parse_basic_string(value)
          String.starts_with?(value, "'") -> parse_literal_string(value)
          true -> auto_parse_value(value)
        end

      Map.put(acc, key, parsed_value)
    end)
  end

  defp auto_parse_value(str) do
    cond do
      str == "true" -> true
      str == "false" -> false
      str == "~" -> nil
      String.match?(str, ~r/^\d+$/) -> String.to_integer(str)
      String.match?(str, ~r/^\d+\.\d+$/) -> String.to_float(str)
      true -> str
    end
  end

  # String parsing helpers

  defp parse_basic_string(str) do
    # Remove surrounding quotes and process escapes
    inner = String.slice(str, 1..-2//1)
    process_escapes(inner)
  end

  defp parse_literal_string(str) do
    # Remove surrounding quotes, no escape processing
    String.slice(str, 1..-2//1)
  end

  defp parse_multiline_basic_string(str) do
    # Remove surrounding triple quotes
    inner = String.slice(str, 3..-4//1)
    # Strip leading newline if present
    inner = if String.starts_with?(inner, "\n"), do: String.slice(inner, 1..-1//1), else: inner
    dedent(inner) |> process_escapes()
  end

  defp parse_multiline_literal_string(str) do
    # Remove surrounding triple quotes
    inner = String.slice(str, 3..-4//1)
    # Strip leading newline if present
    inner = if String.starts_with?(inner, "\n"), do: String.slice(inner, 1..-1//1), else: inner
    dedent(inner)
  end

  defp process_escapes(str) do
    str
    |> String.replace("\\\\", "\x00BACKSLASH\x00")
    |> String.replace("\\\"", "\"")
    |> String.replace("\\n", "\n")
    |> String.replace("\\r", "\r")
    |> String.replace("\\t", "\t")
    |> process_unicode_escapes()
    |> String.replace("\x00BACKSLASH\x00", "\\")
  end

  defp process_unicode_escapes(str) do
    # Handle \u{XXXX} format
    str = Regex.replace(~r/\\u\{([0-9a-fA-F]{1,6})\}/, str, fn _, hex ->
      <<String.to_integer(hex, 16)::utf8>>
    end)

    # Handle \uXXXX format
    Regex.replace(~r/\\u([0-9a-fA-F]{4})/, str, fn _, hex ->
      <<String.to_integer(hex, 16)::utf8>>
    end)
  end

  defp dedent(str) do
    lines = String.split(str, "\n")

    min_indent =
      lines
      |> Enum.filter(&(String.trim(&1) != ""))
      |> Enum.map(&count_leading_whitespace/1)
      |> Enum.min(fn -> 0 end)

    lines
    |> Enum.map(fn line ->
      if String.trim(line) == "" do
        ""
      else
        String.slice(line, min_indent..-1//1)
      end
    end)
    |> Enum.join("\n")
  end

  defp count_leading_whitespace(str) do
    str
    |> String.graphemes()
    |> Enum.take_while(&(&1 in [" ", "\t"]))
    |> length()
  end

  # Array parsing

  defp parse_inline_array(str) do
    inner = String.slice(str, 1..-2//1) |> String.trim()

    if inner == "" do
      []
    else
      parse_array_elements(inner)
    end
  end

  defp parse_array_elements(str) do
    # Simple split by comma, handling nested structures
    {elements, _} =
      str
      |> String.graphemes()
      |> Enum.reduce({[], "", 0, 0, false, nil}, fn char, {elements, current, bracket_depth, brace_depth, in_string, string_char} ->
        cond do
          # Handle string entry/exit
          char in ["\"", "'"] and not in_string ->
            {elements, current <> char, bracket_depth, brace_depth, true, char}

          char == string_char and in_string ->
            {elements, current <> char, bracket_depth, brace_depth, false, nil}

          in_string ->
            {elements, current <> char, bracket_depth, brace_depth, in_string, string_char}

          char == "[" ->
            {elements, current <> char, bracket_depth + 1, brace_depth, in_string, string_char}

          char == "]" ->
            {elements, current <> char, bracket_depth - 1, brace_depth, in_string, string_char}

          char == "{" ->
            {elements, current <> char, bracket_depth, brace_depth + 1, in_string, string_char}

          char == "}" ->
            {elements, current <> char, bracket_depth, brace_depth - 1, in_string, string_char}

          char == "," and bracket_depth == 0 and brace_depth == 0 ->
            trimmed = String.trim(current)

            if trimmed != "" do
              {[parse_array_value(trimmed) | elements], "", bracket_depth, brace_depth, in_string, string_char}
            else
              {elements, "", bracket_depth, brace_depth, in_string, string_char}
            end

          true ->
            {elements, current <> char, bracket_depth, brace_depth, in_string, string_char}
        end
      end)

    # Don't forget the last element
    elements =
      case String.trim(str |> String.split(",") |> List.last() || "") do
        "" -> elements
        _ ->
          {final_elements, last, _, _, _, _} =
            str
            |> String.graphemes()
            |> Enum.reduce({[], "", 0, 0, false, nil}, fn char, {elements, current, bracket_depth, brace_depth, in_string, string_char} ->
              cond do
                char in ["\"", "'"] and not in_string ->
                  {elements, current <> char, bracket_depth, brace_depth, true, char}

                char == string_char and in_string ->
                  {elements, current <> char, bracket_depth, brace_depth, false, nil}

                in_string ->
                  {elements, current <> char, bracket_depth, brace_depth, in_string, string_char}

                char == "[" ->
                  {elements, current <> char, bracket_depth + 1, brace_depth, in_string, string_char}

                char == "]" ->
                  {elements, current <> char, bracket_depth - 1, brace_depth, in_string, string_char}

                char == "{" ->
                  {elements, current <> char, bracket_depth, brace_depth + 1, in_string, string_char}

                char == "}" ->
                  {elements, current <> char, bracket_depth, brace_depth - 1, in_string, string_char}

                char == "," and bracket_depth == 0 and brace_depth == 0 ->
                  trimmed = String.trim(current)

                  if trimmed != "" do
                    {[parse_array_value(trimmed) | elements], "", bracket_depth, brace_depth, in_string, string_char}
                  else
                    {elements, "", bracket_depth, brace_depth, in_string, string_char}
                  end

                true ->
                  {elements, current <> char, bracket_depth, brace_depth, in_string, string_char}
              end
            end)

          last_trimmed = String.trim(last)

          if last_trimmed != "" do
            [parse_array_value(last_trimmed) | final_elements]
          else
            final_elements
          end
      end

    Enum.reverse(elements)
  end

  defp parse_array_value(str) do
    {_type, value, _, _} = tokenize_value(str, 0)
    value
  end

  # Inline table parsing

  defp parse_inline_table(str) do
    inner = String.slice(str, 1..-2//1) |> String.trim()

    if inner == "" do
      %{}
    else
      inner
      |> String.split(",")
      |> Enum.reduce(%{}, fn pair, acc ->
        case String.split(String.trim(pair), "=", parts: 2) do
          [key, value] ->
            key = String.trim(key)
            value = String.trim(value)
            {_type, parsed_value, _, _} = tokenize_value(value, 0)
            Map.put(acc, key, parsed_value)

          _ ->
            acc
        end
      end)
    end
  end

  # Numeric parsing

  defp parse_integer(str) do
    str |> String.replace("_", "") |> String.to_integer()
  end

  defp parse_hex_integer(str) do
    str
    |> String.replace("_", "")
    |> String.replace(~r/^[+-]?0x/i, "")
    |> String.to_integer(16)
    |> maybe_negate(str)
  end

  defp parse_octal_integer(str) do
    str
    |> String.replace("_", "")
    |> String.replace(~r/^[+-]?0o/i, "")
    |> String.to_integer(8)
    |> maybe_negate(str)
  end

  defp parse_binary_integer(str) do
    str
    |> String.replace("_", "")
    |> String.replace(~r/^[+-]?0b/i, "")
    |> String.to_integer(2)
    |> maybe_negate(str)
  end

  defp maybe_negate(num, str) do
    if String.starts_with?(str, "-"), do: -num, else: num
  end

  defp parse_float(str) do
    str |> String.replace("_", "") |> String.to_float()
  end

  # DateTime parsing

  defp parse_datetime(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> dt
      {:error, _} -> str
    end
  end

  defp parse_naive_datetime(str) do
    case NaiveDateTime.from_iso8601(str) do
      {:ok, dt} -> dt
      {:error, _} -> str
    end
  end

  defp parse_date(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      {:error, _} -> str
    end
  end

  defp parse_time(str) do
    case Time.from_iso8601(str) do
      {:ok, time} -> time
      {:error, _} -> str
    end
  end
end
