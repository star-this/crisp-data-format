defmodule Crisp.Encoder do
  @moduledoc """
  Encoder for CRISP documents.

  Converts a `Crisp.Document` structure back to CRISP format string.
  """

  alias Crisp.{Document, Zone, Error}

  @type encode_option ::
          {:indent, non_neg_integer()}
          | {:line_ending, :lf | :crlf}

  @default_indent 2

  @doc """
  Encodes a CRISP document to a string.

  ## Options

  - `:indent` - Number of spaces for indentation. Default: `2`
  - `:line_ending` - Line ending style (`:lf` or `:crlf`). Default: `:lf`
  """
  @spec encode(Document.t(), [encode_option()]) :: {:ok, String.t()} | {:error, Error.t()}
  def encode(%Document{} = doc, opts \\ []) do
    indent = Keyword.get(opts, :indent, @default_indent)
    line_ending = Keyword.get(opts, :line_ending, :lf)

    try do
      parts = []

      # Encode preamble
      parts =
        if Document.has_preamble?(doc) do
          parts ++ [encode_preamble(doc.preamble)]
        else
          parts
        end

      # Encode zones
      zone_strings = Enum.map(doc.zones, &encode_zone(&1, indent))
      parts = parts ++ zone_strings

      output = Enum.join(parts, "\n\n")
      output = apply_line_ending(output, line_ending)

      {:ok, output}
    rescue
      e in Error -> {:error, e}
    catch
      {:error, error} -> {:error, error}
    end
  end

  defp apply_line_ending(str, :lf), do: str
  defp apply_line_ending(str, :crlf), do: String.replace(str, "\n", "\r\n")

  # Preamble encoding

  defp encode_preamble(preamble) do
    # Ensure crisp version is first
    lines = []

    lines =
      if Map.has_key?(preamble, "crisp") do
        ["%crisp #{preamble["crisp"]}" | lines]
      else
        ["%crisp 1.0" | lines]
      end

    # Standard directives in order
    standard_order = ["schema", "id", "created", "modified", "author", "title", "lang", "encoding"]

    lines =
      Enum.reduce(standard_order, lines, fn key, acc ->
        case Map.get(preamble, key) do
          nil -> acc
          value -> ["%#{key} #{encode_directive_value(value)}" | acc]
        end
      end)

    # Custom directives (x-prefixed)
    custom =
      preamble
      |> Map.drop(["crisp" | standard_order])
      |> Enum.filter(fn {k, _} -> String.starts_with?(k, "x-") end)
      |> Enum.map(fn {k, v} -> "%#{k} #{encode_directive_value(v)}" end)

    lines = custom ++ lines

    Enum.reverse(lines) |> Enum.join("\n")
  end

  defp encode_directive_value(value) when is_binary(value) do
    if needs_quoting?(value) do
      inspect(value)
    else
      value
    end
  end

  defp encode_directive_value(value) when is_list(value) do
    "[" <> Enum.map_join(value, ", ", &encode_directive_value/1) <> "]"
  end

  defp encode_directive_value(value), do: inspect(value)

  defp needs_quoting?(str) do
    String.contains?(str, " ") or String.contains?(str, "\"") or String.contains?(str, "\n")
  end

  # Zone encoding

  defp encode_zone(%Zone{type: :data} = zone, indent) do
    header = "@data:#{zone.name}#{encode_hints(zone.hints, :data)}"
    content = encode_data_content(zone.content, indent)
    "#{header}\n#{content}"
  end

  defp encode_zone(%Zone{type: :prose} = zone, indent) do
    header = "@prose:#{zone.name}#{encode_hints(zone.hints, :prose)}"
    content = indent_content(zone.content, indent)
    "#{header}\n#{content}\n@end"
  end

  defp encode_zone(%Zone{type: :table} = zone, indent) do
    columns = Map.get(zone.hints, :columns, [])
    header = "@table:#{zone.name} #{encode_table_columns(columns)}"
    content = encode_table_content(zone.content, columns, indent)
    "#{header}\n#{content}\n@end"
  end

  defp encode_zone(%Zone{type: :list} = zone, indent) do
    item_type = Map.get(zone.hints, :item_type, "any")
    header = "@list:#{zone.name} [#{item_type}]"
    content = encode_list_content(zone.content, indent)
    "#{header}\n#{content}\n@end"
  end

  defp encode_zone(%Zone{type: :raw} = zone, _indent) do
    hints = encode_hints(zone.hints, :raw)
    header = "@raw:#{zone.name}#{hints}"
    # Raw content is not indented
    "#{header}\n#{zone.content}\n@end"
  end

  defp encode_zone(%Zone{type: :seq} = zone, indent) do
    header = "@seq:#{zone.name}#{encode_hints(zone.hints, :seq)}"
    content = encode_seq_content(zone.content, indent)
    "#{header}\n#{content}\n@end"
  end

  defp encode_hints(hints, _type) when map_size(hints) == 0, do: ""

  defp encode_hints(hints, :table) do
    # Table hints are column definitions, handled separately
    other_hints = Map.drop(hints, [:columns])

    if map_size(other_hints) == 0 do
      ""
    else
      " [" <> encode_generic_hints(other_hints) <> "]"
    end
  end

  defp encode_hints(hints, :list) do
    # List hints include item_type, handled separately
    other_hints = Map.drop(hints, [:item_type])

    if map_size(other_hints) == 0 do
      ""
    else
      " [" <> encode_generic_hints(other_hints) <> "]"
    end
  end

  defp encode_hints(hints, _type) do
    if map_size(hints) == 0 do
      ""
    else
      " [" <> encode_generic_hints(hints) <> "]"
    end
  end

  defp encode_generic_hints(hints) do
    hints
    |> Enum.map(fn
      {k, true} -> to_string(k)
      {k, v} when is_binary(v) -> "#{k}=#{encode_hint_value(v)}"
      {k, v} -> "#{k}=#{v}"
    end)
    |> Enum.join(", ")
  end

  defp encode_hint_value(value) when is_binary(value) do
    if String.contains?(value, " ") or String.contains?(value, ",") do
      inspect(value)
    else
      value
    end
  end

  defp encode_hint_value(value), do: inspect(value)

  defp encode_table_columns(columns) do
    col_strs =
      Enum.map(columns, fn col ->
        name = col[:name] || col["name"]
        type = col[:type] || col["type"] || "any"
        "#{name}:#{type}"
      end)

    "[" <> Enum.join(col_strs, ", ") <> "]"
  end

  # Data content encoding

  defp encode_data_content(data, indent) when is_map(data) do
    indent_str = String.duplicate(" ", indent)

    # Separate top-level scalars/arrays from nested tables
    {scalars, tables} =
      Enum.split_with(data, fn {_k, v} ->
        not is_map(v) or is_inline_table?(v)
      end)

    # Separate regular tables from array-of-tables
    {regular_tables, array_tables} =
      Enum.split_with(tables, fn {_k, v} ->
        not is_list(v) or not Enum.all?(v, &is_map/1)
      end)

    parts = []

    # Encode top-level key-value pairs
    scalar_lines =
      Enum.map(scalars, fn {k, v} ->
        "#{indent_str}#{encode_key(k)} = #{encode_value(v)}"
      end)

    parts = if scalar_lines != [], do: parts ++ [Enum.join(scalar_lines, "\n")], else: parts

    # Encode nested tables
    table_parts =
      Enum.map(regular_tables, fn {k, v} ->
        encode_nested_table(k, v, indent)
      end)

    parts = parts ++ table_parts

    # Encode array of tables
    array_parts =
      Enum.flat_map(array_tables, fn {k, items} ->
        Enum.map(items, fn item ->
          encode_array_table(k, item, indent)
        end)
      end)

    parts = parts ++ array_parts

    Enum.join(parts, "\n\n")
  end

  defp is_inline_table?(map) when is_map(map) do
    # Inline tables should be small and contain only scalar values
    map_size(map) <= 3 and Enum.all?(map, fn {_k, v} -> is_scalar?(v) end)
  end

  defp is_inline_table?(_), do: false

  defp is_scalar?(v) when is_binary(v), do: not String.contains?(v, "\n")
  defp is_scalar?(v) when is_number(v), do: true
  defp is_scalar?(v) when is_boolean(v), do: true
  defp is_scalar?(v) when is_nil(v), do: true
  defp is_scalar?(%DateTime{}), do: true
  defp is_scalar?(%NaiveDateTime{}), do: true
  defp is_scalar?(%Date{}), do: true
  defp is_scalar?(%Time{}), do: true
  defp is_scalar?(v) when is_atom(v), do: true
  defp is_scalar?(v) when is_list(v), do: length(v) <= 5 and Enum.all?(v, &is_scalar?/1)
  defp is_scalar?(_), do: false

  defp encode_nested_table(path, data, indent) when is_binary(path) do
    encode_nested_table([path], data, indent)
  end

  defp encode_nested_table(path, data, indent) when is_list(path) and is_map(data) do
    indent_str = String.duplicate(" ", indent)
    path_str = Enum.join(path, ".")

    # Get scalars for this level
    {scalars, nested} =
      Enum.split_with(data, fn {_k, v} ->
        not is_map(v) or is_inline_table?(v)
      end)

    header = "#{indent_str}[#{path_str}]"

    scalar_lines =
      Enum.map(scalars, fn {k, v} ->
        "#{indent_str}#{encode_key(k)} = #{encode_value(v)}"
      end)

    content =
      if scalar_lines != [] do
        header <> "\n" <> Enum.join(scalar_lines, "\n")
      else
        header
      end

    # Recurse into nested tables
    nested_parts =
      Enum.map(nested, fn {k, v} ->
        encode_nested_table(path ++ [k], v, indent)
      end)

    if nested_parts != [] do
      content <> "\n\n" <> Enum.join(nested_parts, "\n\n")
    else
      content
    end
  end

  defp encode_array_table(path, data, indent) when is_binary(path) do
    encode_array_table([path], data, indent)
  end

  defp encode_array_table(path, data, indent) when is_list(path) and is_map(data) do
    indent_str = String.duplicate(" ", indent)
    path_str = Enum.join(path, ".")

    header = "#{indent_str}[[#{path_str}]]"

    scalar_lines =
      data
      |> Enum.filter(fn {_k, v} -> not is_map(v) or is_inline_table?(v) end)
      |> Enum.map(fn {k, v} ->
        "#{indent_str}#{encode_key(k)} = #{encode_value(v)}"
      end)

    if scalar_lines != [] do
      header <> "\n" <> Enum.join(scalar_lines, "\n")
    else
      header
    end
  end

  defp encode_key(key) when is_binary(key) do
    if Regex.match?(~r/^[a-zA-Z_][a-zA-Z0-9_-]*$/, key) do
      key
    else
      inspect(key)
    end
  end

  defp encode_key(key), do: inspect(key)

  defp encode_value(nil), do: "~"
  defp encode_value(true), do: "true"
  defp encode_value(false), do: "false"
  defp encode_value(:infinity), do: "inf"
  defp encode_value(:neg_infinity), do: "-inf"
  defp encode_value(:nan), do: "nan"

  defp encode_value(value) when is_integer(value) do
    Integer.to_string(value)
  end

  defp encode_value(value) when is_float(value) do
    :erlang.float_to_binary(value, [:compact, decimals: 15])
  end

  defp encode_value(value) when is_binary(value) do
    if String.contains?(value, "\n") do
      encode_multiline_string(value)
    else
      inspect(value)
    end
  end

  defp encode_value(%DateTime{} = dt) do
    DateTime.to_iso8601(dt)
  end

  defp encode_value(%NaiveDateTime{} = dt) do
    NaiveDateTime.to_iso8601(dt)
  end

  defp encode_value(%Date{} = date) do
    Date.to_iso8601(date)
  end

  defp encode_value(%Time{} = time) do
    Time.to_iso8601(time)
  end

  defp encode_value(value) when is_list(value) do
    if length(value) > 3 or Enum.any?(value, &(is_list(&1) or is_map(&1))) do
      encode_multiline_array(value)
    else
      "[" <> Enum.map_join(value, ", ", &encode_value/1) <> "]"
    end
  end

  defp encode_value(value) when is_map(value) do
    if is_inline_table?(value) do
      pairs = Enum.map_join(value, ", ", fn {k, v} -> "#{encode_key(k)} = #{encode_value(v)}" end)
      "{ #{pairs} }"
    else
      # This shouldn't happen for properly structured data
      inspect(value)
    end
  end

  defp encode_value(value) when is_atom(value) do
    Atom.to_string(value)
  end

  defp encode_multiline_string(value) do
    ~s("""\n#{value}\n""")
  end

  defp encode_multiline_array(items) do
    inner = Enum.map_join(items, ",\n  ", &encode_value/1)
    "[\n  #{inner},\n]"
  end

  # Table content encoding

  defp encode_table_content(rows, columns, indent) do
    indent_str = String.duplicate(" ", indent)

    rows
    |> Enum.map(fn row ->
      cells =
        Enum.map(columns, fn col ->
          name = col[:name] || col["name"]
          value = Map.get(row, name)
          encode_cell_value(value)
        end)

      indent_str <> Enum.join(cells, "\t")
    end)
    |> Enum.join("\n")
  end

  defp encode_cell_value(nil), do: "~"
  defp encode_cell_value(true), do: "true"
  defp encode_cell_value(false), do: "false"

  defp encode_cell_value(value) when is_binary(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("\t", "\\t")
    |> String.replace("\n", "\\n")
    |> String.replace("~", "\\~")
  end

  defp encode_cell_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp encode_cell_value(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp encode_cell_value(%Date{} = date), do: Date.to_iso8601(date)
  defp encode_cell_value(%Time{} = time), do: Time.to_iso8601(time)
  defp encode_cell_value(value) when is_integer(value), do: Integer.to_string(value)
  defp encode_cell_value(value) when is_float(value), do: Float.to_string(value)
  defp encode_cell_value(value), do: to_string(value)

  # List content encoding

  defp encode_list_content(items, indent) do
    indent_str = String.duplicate(" ", indent)

    items
    |> Enum.map(fn item ->
      if is_binary(item) and String.contains?(item, "\n") do
        # Multiline item with continuation
        lines = String.split(item, "\n")
        first = List.first(lines)
        rest = Enum.drop(lines, 1) |> Enum.map(&("#{indent_str}|#{&1}"))
        [indent_str <> first | rest] |> Enum.join("\n")
      else
        indent_str <> encode_list_item(item)
      end
    end)
    |> Enum.join("\n")
  end

  defp encode_list_item(nil), do: "~"
  defp encode_list_item(true), do: "true"
  defp encode_list_item(false), do: "false"
  defp encode_list_item(value) when is_integer(value), do: Integer.to_string(value)
  defp encode_list_item(value) when is_float(value), do: Float.to_string(value)
  defp encode_list_item(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp encode_list_item(%Date{} = date), do: Date.to_iso8601(date)
  defp encode_list_item(%Time{} = time), do: Time.to_iso8601(time)
  defp encode_list_item(value), do: to_string(value)

  # Seq content encoding

  defp encode_seq_content(entries, indent) do
    entries
    |> Enum.map(&encode_seq_entry(&1, indent))
    |> Enum.join("\n\n")
  end

  defp encode_seq_entry(%{type: type, attributes: attrs, content: content}, indent) do
    indent_str = String.duplicate(" ", indent)
    entry_indent = String.duplicate(" ", indent * 2)

    # Format opening tag
    open_tag =
      if map_size(attrs) == 0 do
        "#{indent_str}[#{type}]"
      else
        attrs_str =
          attrs
          |> Enum.map(fn {k, v} -> "#{k}=#{encode_attr_value(v)}" end)
          |> Enum.join(" ")

        "#{indent_str}[#{type} #{attrs_str}]"
      end

    # Format content with proper indentation
    content_lines =
      content
      |> String.split("\n")
      |> Enum.map(fn line ->
        if String.trim(line) == "" do
          ""
        else
          entry_indent <> line
        end
      end)
      |> Enum.join("\n")

    close_tag = "#{indent_str}[/#{type}]"

    "#{open_tag}\n#{content_lines}\n#{close_tag}"
  end

  defp encode_attr_value(value) when is_binary(value) do
    if String.contains?(value, " ") or String.contains?(value, "\"") do
      inspect(value)
    else
      value
    end
  end

  defp encode_attr_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp encode_attr_value(value) when is_integer(value), do: Integer.to_string(value)
  defp encode_attr_value(value) when is_float(value), do: Float.to_string(value)
  defp encode_attr_value(value) when is_boolean(value), do: Atom.to_string(value)
  defp encode_attr_value(value), do: inspect(value)

  defp indent_content(content, indent) do
    indent_str = String.duplicate(" ", indent)

    content
    |> String.split("\n")
    |> Enum.map(fn line ->
      if String.trim(line) == "" do
        ""
      else
        indent_str <> line
      end
    end)
    |> Enum.join("\n")
  end
end
