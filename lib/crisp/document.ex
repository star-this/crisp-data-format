defmodule Crisp.Document do
  @moduledoc """
  Represents a parsed CRISP document.

  A document consists of:
  - A preamble with metadata (version, schema, author, etc.)
  - An ordered list of zones

  ## Structure

      %Crisp.Document{
        preamble: %{
          "version" => "1.0",
          "title" => "My Document",
          "author" => "Alice"
        },
        zones: [
          %Crisp.Zone{type: :data, name: "config", ...},
          %Crisp.Zone{type: :prose, name: "readme", ...}
        ],
        source: "original content..."
      }
  """

  @type t :: %__MODULE__{
          preamble: map(),
          zones: [Crisp.Zone.t()],
          source: String.t() | nil
        }

  defstruct preamble: %{},
            zones: [],
            source: nil

  @doc """
  Creates a new document with the given preamble and zones.
  """
  @spec new(map(), [Crisp.Zone.t()]) :: t()
  def new(preamble \\ %{}, zones \\ []) do
    %__MODULE__{
      preamble: preamble,
      zones: zones
    }
  end

  @doc """
  Gets a preamble directive value.

  ## Examples

      Document.get_directive(doc, "version")  # => "1.0"
      Document.get_directive(doc, "title")    # => "My Doc"
  """
  @spec get_directive(t(), String.t(), term()) :: term()
  def get_directive(%__MODULE__{preamble: preamble}, key, default \\ nil) do
    Map.get(preamble, key, default)
  end

  @doc """
  Gets the document version.
  """
  @spec version(t()) :: String.t() | nil
  def version(%__MODULE__{} = doc) do
    get_directive(doc, "crisp") || get_directive(doc, "version")
  end

  @doc """
  Gets the schema reference if present.
  """
  @spec schema(t()) :: String.t() | nil
  def schema(%__MODULE__{} = doc) do
    get_directive(doc, "schema")
  end

  @doc """
  Returns zone names as a list.
  """
  @spec zone_names(t()) :: [String.t()]
  def zone_names(%__MODULE__{zones: zones}) do
    Enum.map(zones, & &1.name)
  end

  @doc """
  Returns a map of zone names to zones for quick lookup.
  """
  @spec zone_map(t()) :: %{String.t() => Crisp.Zone.t()}
  def zone_map(%__MODULE__{zones: zones}) do
    Map.new(zones, fn zone -> {zone.name, zone} end)
  end

  @doc """
  Checks if the document has a preamble.
  """
  @spec has_preamble?(t()) :: boolean()
  def has_preamble?(%__MODULE__{preamble: preamble}) do
    map_size(preamble) > 0
  end

  defimpl Inspect do
    def inspect(%Crisp.Document{preamble: preamble, zones: zones}, _opts) do
      zone_summary =
        zones
        |> Enum.map(fn z -> "#{z.type}:#{z.name}" end)
        |> Enum.join(", ")

      version = Map.get(preamble, "crisp", "?")
      "#Crisp.Document<v#{version}, zones: [#{zone_summary}]>"
    end
  end
end
