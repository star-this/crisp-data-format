defmodule Crisp.Parser do
  @moduledoc """
  Parser for CRISP documents.

  Consumes tokens from the lexer and builds a `Crisp.Document` structure.
  """

  alias Crisp.{Document, Zone, Lexer, Error}

  @type parse_option ::
          {:strict, boolean()}
          | {:validate, boolean()}
          | {:schema, String.t() | nil}

  @doc """
  Parses a CRISP document from a string.

  ## Options

  - `:strict` - If `true`, any error is fatal. Default: `true`
  - `:validate` - If `true` and schema is present, validate. Default: `true`
  - `:schema` - Override schema path for validation
  """
  @spec parse(String.t(), [parse_option()]) :: {:ok, Document.t()} | {:error, Error.t()}
  def parse(content, opts \\ []) when is_binary(content) do
    with {:ok, tokens} <- Lexer.tokenize(content) do
      parse_tokens(tokens, content, opts)
    end
  end

  defp parse_tokens(tokens, source, opts) do
    try do
      {preamble, rest} = parse_preamble(tokens)
      {zones, _rest} = parse_zones(rest, preamble, opts)

      doc = %Document{
        preamble: preamble,
        zones: zones,
        source: source
      }

      # Validate if schema present and validation enabled
      validate_opt = Keyword.get(opts, :validate, true)
      schema = Keyword.get(opts, :schema) || Map.get(preamble, "schema")

      if validate_opt && schema do
        # Schema validation would happen here
        {:ok, doc}
      else
        {:ok, doc}
      end
    rescue
      e in Error -> {:error, e}
    catch
      {:error, error} -> {:error, error}
    end
  end

  defp parse_preamble(tokens) do
    parse_preamble(tokens, %{})
  end

  defp parse_preamble([{:directive, {name, value}, _line, _col} | rest], preamble) do
    parse_preamble(rest, Map.put(preamble, name, value))
  end

  defp parse_preamble([{:comment, _text, _line, _col} | rest], preamble) do
    parse_preamble(rest, preamble)
  end

  defp parse_preamble([{:blank, _, _line, _col} | rest], preamble) do
    parse_preamble(rest, preamble)
  end

  defp parse_preamble(tokens, preamble) do
    {preamble, tokens}
  end

  defp parse_zones(tokens, preamble, opts) do
    parse_zones(tokens, preamble, opts, [], %{})
  end

  defp parse_zones([{:eof, _, _, _}], _preamble, _opts, zones, _refs) do
    {Enum.reverse(zones), []}
  end

  defp parse_zones([{:zone_marker, {type, name, hints}, line, _col} | rest], preamble, opts, zones, refs) do
    {zone, remaining} = parse_zone(type, name, hints, rest, line, refs, opts)

    # Track data zones for @ref
    new_refs =
      if type == :data do
        Map.put(refs, name, zone.content)
      else
        refs
      end

    parse_zones(remaining, preamble, opts, [zone | zones], new_refs)
  end

  defp parse_zones([{:blank, _, _, _} | rest], preamble, opts, zones, refs) do
    parse_zones(rest, preamble, opts, zones, refs)
  end

  defp parse_zones([{:comment, _, _, _} | rest], preamble, opts, zones, refs) do
    parse_zones(rest, preamble, opts, zones, refs)
  end

  # Handle implicit data zone (tokens without zone marker)
  defp parse_zones([token | _] = tokens, preamble, opts, zones, refs)
       when elem(token, 0) in [:key, :lbracket, :double_lbracket, :ref] do
    {zone, remaining} = parse_zone(:data, "default", %{}, tokens, elem(token, 2), refs, opts)
    new_refs = Map.put(refs, "default", zone.content)
    parse_zones(remaining, preamble, opts, [zone | zones], new_refs)
  end

  defp parse_zones([{:eof, _, _, _} | _], _preamble, _opts, zones, _refs) do
    {Enum.reverse(zones), []}
  end

  defp parse_zones([], _preamble, _opts, zones, _refs) do
    {Enum.reverse(zones), []}
  end

  defp parse_zones([{token_type, _, line, _} | _rest], _preamble, _opts, _zones, _refs) do
    throw({:error, Error.syntax_error("Unexpected token: #{token_type}", line: line)})
  end

  # Zone parsing by type

  defp parse_zone(:data, name, hints, tokens, start_line, refs, _opts) do
    {content, remaining, raw_content, end_line} = parse_data_zone(tokens, refs)

    zone = %Zone{
      type: :data,
      name: name,
      content: content,
      hints: hints,
      raw_content: raw_content,
      line_start: start_line,
      line_end: end_line
    }

    {zone, remaining}
  end

  defp parse_zone(:prose, name, hints, tokens, start_line, _refs, _opts) do
    {content, remaining, raw_content, end_line} = parse_prose_zone(tokens)

    zone = %Zone{
      type: :prose,
      name: name,
      content: content,
      hints: hints,
      raw_content: raw_content,
      line_start: start_line,
      line_end: end_line
    }

    {zone, remaining}
  end

  defp parse_zone(:table, name, hints, tokens, start_line, _refs, _opts) do
    {content, remaining, raw_content, end_line} = parse_table_zone(tokens, hints)

    zone = %Zone{
      type: :table,
      name: name,
      content: content,
      hints: hints,
      raw_content: raw_content,
      line_start: start_line,
      line_end: end_line
    }

    {zone, remaining}
  end

  defp parse_zone(:list, name, hints, tokens, start_line, _refs, _opts) do
    {content, remaining, raw_content, end_line} = parse_list_zone(tokens, hints)

    zone = %Zone{
      type: :list,
      name: name,
      content: content,
      hints: hints,
      raw_content: raw_content,
      line_start: start_line,
      line_end: end_line
    }

    {zone, remaining}
  end

  defp parse_zone(:raw, name, hints, tokens, start_line, _refs, _opts) do
    {content, remaining, end_line} = parse_raw_zone(tokens, hints)

    zone = %Zone{
      type: :raw,
      name: name,
      content: content,
      hints: hints,
      raw_content: content,
      line_start: start_line,
      line_end: end_line
    }

    {zone, remaining}
  end

  defp parse_zone(:seq, name, hints, tokens, start_line, _refs, _opts) do
    {content, remaining, raw_content, end_line} = parse_seq_zone(tokens)

    zone = %Zone{
      type: :seq,
      name: name,
      content: content,
      hints: hints,
      raw_content: raw_content,
      line_start: start_line,
      line_end: end_line
    }

    {zone, remaining}
  end

  # Data zone parsing

  defp parse_data_zone(tokens, refs) do
    parse_data_zone(tokens, refs, %{}, [], nil, nil)
  end

  defp parse_data_zone([{:zone_marker, _, _, _} | _] = tokens, _refs, data, raw_lines, _table_path, start_line) do
    {data, tokens, Enum.join(Enum.reverse(raw_lines), "\n"), start_line}
  end

  defp parse_data_zone([{:zone_end, _, line, _} | rest], _refs, data, raw_lines, _table_path, start_line) do
    {data, rest, Enum.join(Enum.reverse(raw_lines), "\n"), line}
  end

  defp parse_data_zone([{:eof, _, line, _} | _] = tokens, _refs, data, raw_lines, _table_path, start_line) do
    {data, tokens, Enum.join(Enum.reverse(raw_lines), "\n"), start_line || line}
  end

  defp parse_data_zone([{:ref, ref_name, line, _} | rest], refs, data, raw_lines, table_path, start_line) do
    case Map.fetch(refs, ref_name) do
      {:ok, ref_data} ->
        merged = Map.merge(ref_data, data)
        raw_line = "@ref #{ref_name}"
        parse_data_zone(rest, refs, merged, [raw_line | raw_lines], table_path, start_line || line)

      :error ->
        throw({:error, Error.reference_error("Reference to undefined zone: #{ref_name}", line: line)})
    end
  end

  defp parse_data_zone([{:lbracket, path, line, _} | rest], refs, data, raw_lines, _table_path, start_line) do
    raw_line = "[#{path}]"
    parse_data_zone(rest, refs, data, [raw_line | raw_lines], parse_key_path(path), start_line || line)
  end

  defp parse_data_zone([{:double_lbracket, path, line, _} | rest], refs, data, raw_lines, _table_path, start_line) do
    # Array of tables
    key_path = parse_key_path(path)
    data = ensure_array_of_tables(data, key_path)
    raw_line = "[[#{path}]]"
    parse_data_zone(rest, refs, data, [raw_line | raw_lines], {:array, key_path}, start_line || line)
  end

  defp parse_data_zone([{:key, key, line, _}, {:equals, _, _, _} | rest], refs, data, raw_lines, table_path, start_line) do
    {value, value_raw, remaining} = extract_value(rest)

    data = set_value(data, table_path, key, value)
    raw_line = "#{key} = #{value_raw}"
    parse_data_zone(remaining, refs, data, [raw_line | raw_lines], table_path, start_line || line)
  end

  defp parse_data_zone([{:comment, text, line, _} | rest], refs, data, raw_lines, table_path, start_line) do
    parse_data_zone(rest, refs, data, [text | raw_lines], table_path, start_line || line)
  end

  defp parse_data_zone([{:blank, _, line, _} | rest], refs, data, raw_lines, table_path, start_line) do
    parse_data_zone(rest, refs, data, ["" | raw_lines], table_path, start_line || line)
  end

  defp parse_data_zone([{:text, text, line, _} | rest], refs, data, raw_lines, table_path, start_line) do
    # Skip whitespace-only text lines
    if String.trim(text) == "" do
      parse_data_zone(rest, refs, data, ["" | raw_lines], table_path, start_line || line)
    else
      throw({:error, Error.syntax_error("Unexpected text in data zone: #{text}", line: line)})
    end
  end

  defp parse_data_zone([{token_type, _, line, _} | _], _refs, _data, _raw_lines, _table_path, _start_line) do
    throw({:error, Error.syntax_error("Unexpected token in data zone: #{token_type}", line: line)})
  end

  defp extract_value([{type, value, _line, _col} | rest])
       when type in [:string, :integer, :float, :boolean, :null, :datetime, :date, :time, :duration, :array, :inline_table] do
    {value, format_value(type, value), skip_trailing(rest)}
  end

  defp extract_value([{:comment, _, _, _} | _] = rest) do
    # No value before comment - this shouldn't happen in valid CRISP
    {nil, "~", rest}
  end

  defp extract_value([{type, _, line, _} | _]) do
    throw({:error, Error.syntax_error("Expected value, got #{type}", line: line)})
  end

  defp skip_trailing([{:comment, _, _, _} | rest]), do: rest
  defp skip_trailing([{:blank, _, _, _} | _] = rest), do: rest
  defp skip_trailing(rest), do: rest

  defp format_value(:string, value), do: inspect(value)
  defp format_value(:integer, value), do: Integer.to_string(value)
  defp format_value(:float, :infinity), do: "inf"
  defp format_value(:float, :neg_infinity), do: "-inf"
  defp format_value(:float, :nan), do: "nan"
  defp format_value(:float, value), do: Float.to_string(value)
  defp format_value(:boolean, value), do: Atom.to_string(value)
  defp format_value(:null, _), do: "~"
  defp format_value(:datetime, value), do: DateTime.to_iso8601(value)
  defp format_value(:date, value), do: Date.to_iso8601(value)
  defp format_value(:time, value), do: Time.to_iso8601(value)
  defp format_value(:duration, value), do: value
  defp format_value(:array, value), do: inspect(value)
  defp format_value(:inline_table, value), do: inspect(value)

  defp parse_key_path(path) do
    String.split(path, ".")
  end

  defp set_value(data, nil, key, value) do
    Map.put(data, key, value)
  end

  defp set_value(data, {:array, path}, key, value) do
    update_in_path(data, path, fn
      list when is_list(list) ->
        case List.last(list) do
          last when is_map(last) ->
            List.replace_at(list, -1, Map.put(last, key, value))

          _ ->
            list
        end

      nil ->
        [%{key => value}]

      other ->
        other
    end)
  end

  defp set_value(data, path, key, value) when is_list(path) do
    update_in_path(data, path, fn
      nil -> %{key => value}
      map when is_map(map) -> Map.put(map, key, value)
      other -> other
    end)
  end

  defp ensure_array_of_tables(data, path) do
    update_in_path(data, path, fn
      nil -> [%{}]
      list when is_list(list) -> list ++ [%{}]
      other -> other
    end)
  end

  defp update_in_path(data, [key], fun) do
    current = Map.get(data, key)
    Map.put(data, key, fun.(current))
  end

  defp update_in_path(data, [key | rest], fun) do
    current = Map.get(data, key, %{})
    Map.put(data, key, update_in_path(current, rest, fun))
  end

  # Prose zone parsing

  defp parse_prose_zone(tokens) do
    parse_prose_zone(tokens, [], nil)
  end

  defp parse_prose_zone([{:zone_end, _, line, _} | rest], lines, _start_line) do
    content = dedent_prose(Enum.reverse(lines))
    {content, rest, Enum.join(Enum.reverse(lines), "\n"), line}
  end

  defp parse_prose_zone([{:text, text, line, _} | rest], lines, start_line) do
    parse_prose_zone(rest, [text | lines], start_line || line)
  end

  defp parse_prose_zone([{:blank, _, line, _} | rest], lines, start_line) do
    parse_prose_zone(rest, ["" | lines], start_line || line)
  end

  defp parse_prose_zone([{:eof, _, line, _}], lines, start_line) do
    throw({:error, Error.syntax_error("Unexpected end of file in prose zone (missing @end)", line: start_line || line)})
  end

  defp parse_prose_zone([{:zone_marker, _, line, _} | _], _lines, start_line) do
    throw({:error, Error.syntax_error("Unexpected zone marker in prose zone (missing @end)", line: start_line || line)})
  end

  defp dedent_prose(lines) do
    non_blank_lines = Enum.filter(lines, &(String.trim(&1) != ""))

    min_indent =
      non_blank_lines
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

  # Table zone parsing

  defp parse_table_zone(tokens, hints) do
    columns = Map.get(hints, :columns, [])
    parse_table_zone(tokens, columns, [], [], nil)
  end

  defp parse_table_zone([{:zone_end, _, line, _} | rest], _columns, rows, raw_lines, _start_line) do
    {Enum.reverse(rows), rest, Enum.join(Enum.reverse(raw_lines), "\n"), line}
  end

  defp parse_table_zone([{:table_row, cells, line, _} | rest], columns, rows, raw_lines, start_line) do
    row = parse_table_row(cells, columns)
    raw_line = cells |> Enum.map(fn {:cell, val, _, _} -> val end) |> Enum.join("\t")
    parse_table_zone(rest, columns, [row | rows], [raw_line | raw_lines], start_line || line)
  end

  defp parse_table_zone([{:blank, _, line, _} | rest], columns, rows, raw_lines, start_line) do
    parse_table_zone(rest, columns, rows, ["" | raw_lines], start_line || line)
  end

  defp parse_table_zone([{:text, text, line, _} | rest], columns, rows, raw_lines, start_line) do
    # Parse as a table row (tab-separated)
    cells =
      text
      |> String.split("\t", trim: false)
      |> Enum.with_index(fn cell, idx -> {:cell, cell, line, idx + 1} end)

    row = parse_table_row(cells, columns)
    parse_table_zone(rest, columns, [row | rows], [text | raw_lines], start_line || line)
  end

  defp parse_table_zone([{:eof, _, line, _}], _columns, _rows, _raw_lines, start_line) do
    throw({:error, Error.syntax_error("Unexpected end of file in table zone (missing @end)", line: start_line || line)})
  end

  defp parse_table_row(cells, columns) do
    cells
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {{:cell, value, _line, _col}, idx}, row ->
      col_def = Enum.at(columns, idx, %{name: "col_#{idx}", type: "any"})
      col_name = col_def[:name] || col_def["name"] || "col_#{idx}"
      col_type = col_def[:type] || col_def["type"] || "any"
      parsed_value = parse_cell_value(String.trim(value), col_type)
      Map.put(row, col_name, parsed_value)
    end)
  end

  defp parse_cell_value("~", _type), do: nil
  defp parse_cell_value("", _type), do: ""

  defp parse_cell_value(value, "int") do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end

  defp parse_cell_value(value, "float") do
    case Float.parse(value) do
      {float, ""} -> float
      _ -> value
    end
  end

  defp parse_cell_value("true", "bool"), do: true
  defp parse_cell_value("false", "bool"), do: false
  defp parse_cell_value(value, "bool"), do: value

  defp parse_cell_value(value, "date") do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> value
    end
  end

  defp parse_cell_value(value, "datetime") do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> dt
      _ ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, dt} -> dt
          _ -> value
        end
    end
  end

  defp parse_cell_value(value, "time") do
    case Time.from_iso8601(value) do
      {:ok, time} -> time
      _ -> value
    end
  end

  defp parse_cell_value(value, "duration"), do: value
  defp parse_cell_value(value, "str"), do: unescape_table_string(value)
  defp parse_cell_value(value, "any"), do: value
  defp parse_cell_value(value, _), do: value

  defp unescape_table_string(str) do
    str
    |> String.replace("\\t", "\t")
    |> String.replace("\\n", "\n")
    |> String.replace("\\~", "~")
    |> String.replace("\\\\", "\\")
  end

  # List zone parsing

  defp parse_list_zone(tokens, hints) do
    item_type = Map.get(hints, :item_type, "any")
    parse_list_zone(tokens, item_type, [], [], nil, nil)
  end

  defp parse_list_zone([{:zone_end, _, line, _} | rest], _item_type, items, raw_lines, _current_item, _start_line) do
    {Enum.reverse(items), rest, Enum.join(Enum.reverse(raw_lines), "\n"), line}
  end

  defp parse_list_zone([{:list_item, value, line, _} | rest], item_type, items, raw_lines, _current_item, start_line) do
    parsed = parse_list_item(value, item_type)
    parse_list_zone(rest, item_type, [parsed | items], [value | raw_lines], parsed, start_line || line)
  end

  defp parse_list_zone([{:continuation, text, line, _} | rest], item_type, items, raw_lines, current_item, start_line) do
    # Append to current item
    case items do
      [head | tail] when is_binary(head) ->
        new_head = head <> "\n" <> text
        parse_list_zone(rest, item_type, [new_head | tail], ["|#{text}" | raw_lines], new_head, start_line || line)

      _ ->
        parse_list_zone(rest, item_type, [text | items], ["|#{text}" | raw_lines], current_item, start_line || line)
    end
  end

  defp parse_list_zone([{:blank, _, line, _} | rest], item_type, items, raw_lines, current_item, start_line) do
    parse_list_zone(rest, item_type, items, ["" | raw_lines], current_item, start_line || line)
  end

  defp parse_list_zone([{:text, text, line, _} | rest], item_type, items, raw_lines, current_item, start_line) do
    trimmed = String.trim(text)

    if trimmed == "" do
      parse_list_zone(rest, item_type, items, ["" | raw_lines], current_item, start_line || line)
    else
      parsed = parse_list_item(trimmed, item_type)
      parse_list_zone(rest, item_type, [parsed | items], [text | raw_lines], parsed, start_line || line)
    end
  end

  defp parse_list_zone([{:eof, _, line, _}], _item_type, _items, _raw_lines, _current_item, start_line) do
    throw({:error, Error.syntax_error("Unexpected end of file in list zone (missing @end)", line: start_line || line)})
  end

  defp parse_list_item("~", _type), do: nil

  defp parse_list_item(value, "int") do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end

  defp parse_list_item(value, "float") do
    case Float.parse(value) do
      {float, ""} -> float
      _ -> value
    end
  end

  defp parse_list_item("true", "bool"), do: true
  defp parse_list_item("false", "bool"), do: false
  defp parse_list_item(value, "bool"), do: value

  defp parse_list_item(value, "date") do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> value
    end
  end

  defp parse_list_item(value, "datetime") do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> dt
      _ -> value
    end
  end

  defp parse_list_item(value, "time") do
    case Time.from_iso8601(value) do
      {:ok, time} -> time
      _ -> value
    end
  end

  defp parse_list_item(value, _type), do: value

  # Raw zone parsing

  defp parse_raw_zone(tokens, hints) do
    custom_delim = Map.get(hints, "delim")
    parse_raw_zone(tokens, custom_delim, [], nil)
  end

  defp parse_raw_zone([{:zone_end, _, line, _} | rest], nil, lines, _start_line) do
    content = Enum.reverse(lines) |> Enum.join("\n")
    {content, rest, line}
  end

  defp parse_raw_zone([{:text, text, line, _} | rest], nil, lines, start_line) do
    parse_raw_zone(rest, nil, [text | lines], start_line || line)
  end

  defp parse_raw_zone([{:text, text, line, _} | rest], custom_delim, lines, start_line) do
    if String.trim(text) == custom_delim do
      content = Enum.reverse(lines) |> Enum.join("\n")
      {content, rest, line}
    else
      parse_raw_zone(rest, custom_delim, [text | lines], start_line || line)
    end
  end

  defp parse_raw_zone([{:blank, _, line, _} | rest], custom_delim, lines, start_line) do
    parse_raw_zone(rest, custom_delim, ["" | lines], start_line || line)
  end

  defp parse_raw_zone([{:eof, _, line, _}], _custom_delim, _lines, start_line) do
    throw({:error, Error.syntax_error("Unexpected end of file in raw zone (missing @end)", line: start_line || line)})
  end

  # Seq zone parsing

  defp parse_seq_zone(tokens) do
    parse_seq_zone(tokens, [], [], nil)
  end

  defp parse_seq_zone([{:zone_end, _, line, _} | rest], entries, raw_lines, _start_line) do
    {Enum.reverse(entries), rest, Enum.join(Enum.reverse(raw_lines), "\n"), line}
  end

  defp parse_seq_zone([{:entry_open, {name, attrs}, line, _} | rest], entries, raw_lines, start_line) do
    {content, remaining, entry_raw_lines} = parse_seq_entry_content(rest, name, [])
    entry = %{type: name, attributes: attrs, content: dedent_prose(content)}

    raw_line = format_entry_open(name, attrs)
    all_raw = [raw_line | entry_raw_lines] ++ ["[/#{name}]"]

    parse_seq_zone(remaining, [entry | entries], Enum.reverse(all_raw) ++ raw_lines, start_line || line)
  end

  defp parse_seq_zone([{:blank, _, line, _} | rest], entries, raw_lines, start_line) do
    parse_seq_zone(rest, entries, ["" | raw_lines], start_line || line)
  end

  defp parse_seq_zone([{:text, text, line, _} | rest], entries, raw_lines, start_line) do
    if String.trim(text) == "" do
      parse_seq_zone(rest, entries, ["" | raw_lines], start_line || line)
    else
      # Might be malformed - skip or error
      parse_seq_zone(rest, entries, [text | raw_lines], start_line || line)
    end
  end

  defp parse_seq_zone([{:eof, _, line, _}], _entries, _raw_lines, start_line) do
    throw({:error, Error.syntax_error("Unexpected end of file in seq zone (missing @end)", line: start_line || line)})
  end

  defp parse_seq_entry_content([{:entry_close, _name, _line, _} | rest], _expected_name, lines) do
    {Enum.reverse(lines), rest, lines}
  end

  defp parse_seq_entry_content([{:entry_open, {name, attrs}, _line, _} | rest], expected_name, lines) do
    # Nested entry
    {nested_content, remaining, _nested_raw} = parse_seq_entry_content(rest, name, [])
    nested = %{type: name, attributes: attrs, content: dedent_prose(nested_content)}

    # For simplicity, we'll represent nested entries as a special marker in content
    lines = [inspect(nested) | lines]
    parse_seq_entry_content(remaining, expected_name, lines)
  end

  defp parse_seq_entry_content([{:text, text, _line, _} | rest], expected_name, lines) do
    parse_seq_entry_content(rest, expected_name, [text | lines])
  end

  defp parse_seq_entry_content([{:blank, _, _line, _} | rest], expected_name, lines) do
    parse_seq_entry_content(rest, expected_name, ["" | lines])
  end

  defp parse_seq_entry_content([{:eof, _, line, _}], _expected_name, _lines) do
    throw({:error, Error.syntax_error("Unexpected end of file in seq entry", line: line)})
  end

  defp format_entry_open(name, attrs) when map_size(attrs) == 0 do
    "[#{name}]"
  end

  defp format_entry_open(name, attrs) do
    attrs_str =
      attrs
      |> Enum.map(fn {k, v} -> "#{k}=#{format_attr_value(v)}" end)
      |> Enum.join(" ")

    "[#{name} #{attrs_str}]"
  end

  defp format_attr_value(value) when is_binary(value) do
    if String.contains?(value, " ") do
      inspect(value)
    else
      value
    end
  end

  defp format_attr_value(value), do: inspect(value)
end
