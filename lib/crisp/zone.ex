defmodule Crisp.Zone do
  @moduledoc """
  Represents a zone in a CRISP document.

  ## Zone Types

  - `:data` - Structured key-value data (TOML-compatible)
  - `:prose` - Human-readable Markdown text
  - `:table` - Typed tabular data (TSV-based)
  - `:list` - Simple typed sequences
  - `:raw` - Verbatim content preservation
  - `:seq` - Ordered heterogeneous entries

  ## Structure

      %Crisp.Zone{
        type: :data,
        name: "config",
        content: %{"name" => "example", "version" => "1.0.0"},
        hints: %{},
        raw_content: "name = \\"example\\"\\nversion = \\"1.0.0\\""
      }
  """

  @type zone_type :: :data | :prose | :table | :list | :raw | :seq

  @type t :: %__MODULE__{
          type: zone_type(),
          name: String.t(),
          content: term(),
          hints: map(),
          raw_content: String.t() | nil,
          line_start: non_neg_integer() | nil,
          line_end: non_neg_integer() | nil
        }

  defstruct type: :data,
            name: "",
            content: nil,
            hints: %{},
            raw_content: nil,
            line_start: nil,
            line_end: nil

  @zone_types [:data, :prose, :table, :list, :raw, :seq]

  @doc """
  Creates a new zone.

  ## Examples

      Zone.new(:data, "config", %{key: "value"})
      Zone.new(:prose, "readme", "# Hello", format: "commonmark")
  """
  @spec new(zone_type(), String.t(), term(), keyword() | map()) :: t()
  def new(type, name, content, hints \\ %{})

  def new(type, name, content, hints) when type in @zone_types and is_binary(name) do
    hints_map = if is_list(hints), do: Map.new(hints), else: hints

    %__MODULE__{
      type: type,
      name: name,
      content: content,
      hints: hints_map
    }
  end

  @doc """
  Returns the list of valid zone types.
  """
  @spec types() :: [zone_type()]
  def types, do: @zone_types

  @doc """
  Checks if a zone type is valid.
  """
  @spec valid_type?(atom()) :: boolean()
  def valid_type?(type), do: type in @zone_types

  @doc """
  Checks if the zone requires explicit @end termination.
  """
  @spec requires_end?(t() | zone_type()) :: boolean()
  def requires_end?(%__MODULE__{type: type}), do: requires_end?(type)
  def requires_end?(:data), do: false
  def requires_end?(_), do: true

  @doc """
  Gets a hint value from the zone.
  """
  @spec get_hint(t(), String.t(), term()) :: term()
  def get_hint(%__MODULE__{hints: hints}, key, default \\ nil) do
    Map.get(hints, key, default)
  end

  @doc """
  Returns the content as a specific type based on zone type.
  """
  @spec content_type(zone_type()) :: atom()
  def content_type(:data), do: :map
  def content_type(:prose), do: :string
  def content_type(:table), do: :list_of_maps
  def content_type(:list), do: :list
  def content_type(:raw), do: :string
  def content_type(:seq), do: :list_of_entries

  defimpl Inspect do
    def inspect(%Crisp.Zone{type: type, name: name, content: content}, _opts) do
      content_preview = preview_content(type, content)
      "#Crisp.Zone<#{type}:#{name}#{content_preview}>"
    end

    defp preview_content(:data, content) when is_map(content) do
      keys = Map.keys(content) |> Enum.take(3) |> Enum.join(", ")
      suffix = if map_size(content) > 3, do: ", ...", else: ""
      ", keys: [#{keys}#{suffix}]"
    end

    defp preview_content(:prose, content) when is_binary(content) do
      len = String.length(content)
      ", #{len} chars"
    end

    defp preview_content(:table, content) when is_list(content) do
      ", #{length(content)} rows"
    end

    defp preview_content(:list, content) when is_list(content) do
      ", #{length(content)} items"
    end

    defp preview_content(:seq, content) when is_list(content) do
      ", #{length(content)} entries"
    end

    defp preview_content(:raw, content) when is_binary(content) do
      len = String.length(content)
      ", #{len} chars"
    end

    defp preview_content(_, _), do: ""
  end
end
