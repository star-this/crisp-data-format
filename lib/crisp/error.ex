defmodule Crisp.Error do
  @moduledoc """
  Error types for CRISP parsing, encoding, and validation.

  ## Error Categories

  - `:syntax` - Malformed structure
  - `:type` - Value doesn't match declared type
  - `:constraint` - Schema validation failure
  - `:reference` - Invalid zone reference
  - `:encoding` - Invalid UTF-8 or character encoding
  - `:file` - File system errors
  """

  @type category :: :syntax | :type | :constraint | :reference | :encoding | :file

  @type t :: %__MODULE__{
          category: category(),
          message: String.t(),
          line: non_neg_integer() | nil,
          column: non_neg_integer() | nil,
          zone: String.t() | nil,
          field: String.t() | nil,
          expected: term(),
          actual: term(),
          context: map()
        }

  defexception [
    :category,
    :message,
    :line,
    :column,
    :zone,
    :field,
    :expected,
    :actual,
    :context
  ]

  @impl true
  def message(%__MODULE__{} = error) do
    parts = [error.message]

    parts =
      if error.line do
        parts ++ ["at line #{error.line}#{column_str(error.column)}"]
      else
        parts
      end

    parts =
      if error.zone do
        parts ++ ["in zone '#{error.zone}'"]
      else
        parts
      end

    parts =
      if error.field do
        parts ++ ["field '#{error.field}'"]
      else
        parts
      end

    parts =
      if error.expected && error.actual do
        parts ++ ["expected #{inspect(error.expected)}, got #{inspect(error.actual)}"]
      else
        parts
      end

    Enum.join(parts, " ")
  end

  defp column_str(nil), do: ""
  defp column_str(col), do: ":#{col}"

  @doc """
  Creates a syntax error.
  """
  @spec syntax_error(String.t(), keyword()) :: t()
  def syntax_error(message, opts \\ []) do
    %__MODULE__{
      category: :syntax,
      message: message,
      line: opts[:line],
      column: opts[:column],
      zone: opts[:zone],
      field: opts[:field],
      expected: opts[:expected],
      actual: opts[:actual],
      context: opts[:context] || %{}
    }
  end

  @doc """
  Creates a type error.
  """
  @spec type_error(String.t(), keyword()) :: t()
  def type_error(message, opts \\ []) do
    %__MODULE__{
      category: :type,
      message: message,
      line: opts[:line],
      column: opts[:column],
      zone: opts[:zone],
      field: opts[:field],
      expected: opts[:expected],
      actual: opts[:actual],
      context: opts[:context] || %{}
    }
  end

  @doc """
  Creates a reference error.
  """
  @spec reference_error(String.t(), keyword()) :: t()
  def reference_error(message, opts \\ []) do
    %__MODULE__{
      category: :reference,
      message: message,
      line: opts[:line],
      zone: opts[:zone],
      context: opts[:context] || %{}
    }
  end

  @doc """
  Creates a file error.
  """
  @spec file_error(Path.t(), atom()) :: t()
  def file_error(path, reason) do
    %__MODULE__{
      category: :file,
      message: "Failed to access file '#{path}': #{inspect(reason)}",
      context: %{path: path, reason: reason}
    }
  end

  @doc """
  Creates a constraint/validation error.
  """
  @spec constraint_error(String.t(), keyword()) :: t()
  def constraint_error(message, opts \\ []) do
    %__MODULE__{
      category: :constraint,
      message: message,
      zone: opts[:zone],
      field: opts[:field],
      expected: opts[:expected],
      actual: opts[:actual],
      context: opts[:context] || %{}
    }
  end
end
