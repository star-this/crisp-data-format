defmodule Crisp do
  @moduledoc """
  CRISP (Clear Readable Interchange for Structured Prose) parser and encoder.

  CRISP is a text-based file format designed for human-agent collaboration,
  combining structured data, prose content, and tabular information in a
  single, coherent document.

  ## Quick Start

      # Decode a CRISP document
      {:ok, doc} = Crisp.decode(content)

      # Access zones
      config = Crisp.get_zone(doc, :data, "config")
      readme = Crisp.get_zone(doc, :prose, "readme")

      # Encode back to string
      {:ok, output} = Crisp.encode(doc)

  ## Zone Types

  - `:data` - Structured key-value data (TOML-compatible)
  - `:prose` - Human-readable Markdown text
  - `:table` - Typed tabular data (TSV-based)
  - `:list` - Simple typed sequences
  - `:raw` - Verbatim content preservation
  - `:seq` - Ordered heterogeneous entries

  ## Example

      content = \"\"\"
      %crisp 1.0
      %title "My Document"

      @data:config
        name = "example"
        version = "1.0.0"

      @prose:readme
        # Hello World

        This is a CRISP document.
      @end
      \"\"\"

      {:ok, doc} = Crisp.decode(content)
      doc.preamble["title"]  # => "My Document"
  """

  alias Crisp.{Document, Parser, Encoder, Schema}

  @type decode_option ::
          {:strict, boolean()}
          | {:validate, boolean()}
          | {:schema, String.t() | nil}

  @type encode_option ::
          {:indent, non_neg_integer()}
          | {:line_ending, :lf | :crlf}

  @doc """
  Decodes a CRISP document from a string.

  ## Options

  - `:strict` - If `true`, any error is fatal. Default: `true`
  - `:validate` - If `true` and schema is present, validate. Default: `true`
  - `:schema` - Override schema path for validation

  ## Examples

      iex> Crisp.decode("%crisp 1.0\\n@data:config\\n  key = \\"value\\"")
      {:ok, %Crisp.Document{...}}

      iex> Crisp.decode("invalid content")
      {:error, %Crisp.Error{...}}
  """
  @spec decode(String.t(), [decode_option()]) :: {:ok, Document.t()} | {:error, Crisp.Error.t()}
  def decode(content, opts \\ []) when is_binary(content) do
    Parser.parse(content, opts)
  end

  @doc """
  Decodes a CRISP document, raising on error.

  See `decode/2` for options.
  """
  @spec decode!(String.t(), [decode_option()]) :: Document.t()
  def decode!(content, opts \\ []) when is_binary(content) do
    case decode(content, opts) do
      {:ok, doc} -> doc
      {:error, error} -> raise error
    end
  end

  @doc """
  Decodes a CRISP document from a file.

  ## Examples

      {:ok, doc} = Crisp.decode_file("config.crisp")
  """
  @spec decode_file(Path.t(), [decode_option()]) :: {:ok, Document.t()} | {:error, Crisp.Error.t()}
  def decode_file(path, opts \\ []) do
    case File.read(path) do
      {:ok, content} -> decode(content, opts)
      {:error, reason} -> {:error, Crisp.Error.file_error(path, reason)}
    end
  end

  @doc """
  Decodes a CRISP document from a file, raising on error.
  """
  @spec decode_file!(Path.t(), [decode_option()]) :: Document.t()
  def decode_file!(path, opts \\ []) do
    case decode_file(path, opts) do
      {:ok, doc} -> doc
      {:error, error} -> raise error
    end
  end

  @doc """
  Encodes a CRISP document to a string.

  ## Options

  - `:indent` - Number of spaces for indentation. Default: `2`
  - `:line_ending` - Line ending style (`:lf` or `:crlf`). Default: `:lf`

  ## Examples

      iex> Crisp.encode(doc)
      {:ok, "%crisp 1.0\\n..."}
  """
  @spec encode(Document.t(), [encode_option()]) :: {:ok, String.t()} | {:error, Crisp.Error.t()}
  def encode(%Document{} = doc, opts \\ []) do
    Encoder.encode(doc, opts)
  end

  @doc """
  Encodes a CRISP document to a string, raising on error.
  """
  @spec encode!(Document.t(), [encode_option()]) :: String.t()
  def encode!(%Document{} = doc, opts \\ []) do
    case encode(doc, opts) do
      {:ok, output} -> output
      {:error, error} -> raise error
    end
  end

  @doc """
  Encodes a CRISP document to a file.
  """
  @spec encode_file(Document.t(), Path.t(), [encode_option()]) ::
          :ok | {:error, Crisp.Error.t()}
  def encode_file(%Document{} = doc, path, opts \\ []) do
    case encode(doc, opts) do
      {:ok, content} ->
        case File.write(path, content) do
          :ok -> :ok
          {:error, reason} -> {:error, Crisp.Error.file_error(path, reason)}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Gets a zone by type and name from a document.

  ## Examples

      config = Crisp.get_zone(doc, :data, "config")
      readme = Crisp.get_zone(doc, :prose, "readme")
  """
  @spec get_zone(Document.t(), atom(), String.t()) :: Crisp.Zone.t() | nil
  def get_zone(%Document{zones: zones}, type, name) do
    Enum.find(zones, fn zone ->
      zone.type == type && zone.name == name
    end)
  end

  @doc """
  Gets all zones of a specific type from a document.

  ## Examples

      data_zones = Crisp.get_zones_by_type(doc, :data)
  """
  @spec get_zones_by_type(Document.t(), atom()) :: [Crisp.Zone.t()]
  def get_zones_by_type(%Document{zones: zones}, type) do
    Enum.filter(zones, &(&1.type == type))
  end

  @doc """
  Validates a document against a schema.

  ## Examples

      {:ok, []} = Crisp.validate(doc, schema)
      {:ok, errors} = Crisp.validate(doc, schema)
  """
  @spec validate(Document.t(), Document.t() | String.t()) ::
          {:ok, [Schema.ValidationError.t()]} | {:error, Crisp.Error.t()}
  def validate(%Document{} = doc, schema) when is_binary(schema) do
    case decode(schema) do
      {:ok, schema_doc} -> validate(doc, schema_doc)
      {:error, _} = error -> error
    end
  end

  def validate(%Document{} = doc, %Document{} = schema_doc) do
    Schema.validate(doc, schema_doc)
  end

  @doc """
  Creates a new empty document.

  ## Examples

      doc = Crisp.new()
      doc = Crisp.new(version: "1.0", title: "My Doc")
  """
  @spec new(keyword()) :: Document.t()
  def new(opts \\ []) do
    preamble =
      opts
      |> Keyword.take([:version, :schema, :id, :created, :modified, :author, :title, :lang])
      |> Enum.into(%{})
      |> Map.put_new(:version, "1.0")

    %Document{preamble: preamble, zones: []}
  end

  @doc """
  Adds a zone to a document.

  ## Examples

      doc = Crisp.add_zone(doc, :data, "config", %{name: "example"})
      doc = Crisp.add_zone(doc, :prose, "readme", "# Hello World")
  """
  @spec add_zone(Document.t(), atom(), String.t(), term(), keyword()) :: Document.t()
  def add_zone(%Document{} = doc, type, name, content, hints \\ []) do
    zone = Crisp.Zone.new(type, name, content, hints)
    %{doc | zones: doc.zones ++ [zone]}
  end
end
