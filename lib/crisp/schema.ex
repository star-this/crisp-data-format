defmodule Crisp.Schema do
  @moduledoc """
  Schema validation for CRISP documents.

  Validates documents against CRISP schema definitions (.crisp-schema files).

  ## Schema Structure

  A CRISP schema is itself a CRISP document with a `@data:schema` zone defining:
  - Document-level constraints
  - Zone definitions
  - Field constraints
  - Column definitions for tables

  ## Example Schema

      %crisp 1.0
      %schema-version 1.0

      @data:schema
        [document]
        required_zones = ["config"]

        [zones.config]
        type = "data"
        required = true

        [zones.config.fields.name]
        type = "string"
        required = true
        pattern = "^[a-z][a-z0-9-]*$"
  """

  alias Crisp.{Document, Zone, Error}

  defmodule ValidationError do
    @moduledoc """
    Represents a schema validation error.
    """
    @type t :: %__MODULE__{
            path: String.t(),
            constraint: String.t(),
            message: String.t(),
            expected: term(),
            actual: term()
          }

    defstruct [:path, :constraint, :message, :expected, :actual]
  end

  @doc """
  Validates a document against a schema.

  Returns `{:ok, []}` if valid, or `{:ok, errors}` with a list of validation errors.
  """
  @spec validate(Document.t(), Document.t()) :: {:ok, [ValidationError.t()]} | {:error, Error.t()}
  def validate(%Document{} = doc, %Document{} = schema_doc) do
    schema_zone = Crisp.get_zone(schema_doc, :data, "schema")

    if schema_zone == nil do
      {:error, Error.syntax_error("Schema document missing @data:schema zone")}
    else
      errors = validate_document(doc, schema_zone.content)
      {:ok, errors}
    end
  end

  defp validate_document(doc, schema) do
    errors = []

    # Validate document-level constraints
    errors = errors ++ validate_document_constraints(doc, schema)

    # Validate zones
    zones_schema = Map.get(schema, "zones", %{})
    errors = errors ++ validate_zones(doc, zones_schema)

    errors
  end

  defp validate_document_constraints(doc, schema) do
    doc_constraints = Map.get(schema, "document", %{})
    errors = []

    # Check required zones
    required_zones = Map.get(doc_constraints, "required_zones", [])

    errors =
      Enum.reduce(required_zones, errors, fn zone_name, acc ->
        if zone_exists?(doc, zone_name) do
          acc
        else
          [
            %ValidationError{
              path: "document",
              constraint: "required_zones",
              message: "Required zone '#{zone_name}' is missing",
              expected: zone_name,
              actual: nil
            }
            | acc
          ]
        end
      end)

    errors
  end

  defp zone_exists?(doc, zone_name) do
    Enum.any?(doc.zones, fn zone -> zone.name == zone_name end)
  end

  defp validate_zones(doc, zones_schema) do
    Enum.flat_map(doc.zones, fn zone ->
      zone_schema = Map.get(zones_schema, zone.name, %{})
      validate_zone(zone, zone_schema)
    end)
  end

  defp validate_zone(%Zone{type: :data} = zone, schema) do
    errors = []

    # Validate zone type matches
    expected_type = Map.get(schema, "type")

    errors =
      if expected_type && expected_type != "data" do
        [
          %ValidationError{
            path: "zone.#{zone.name}",
            constraint: "type",
            message: "Zone type mismatch",
            expected: expected_type,
            actual: "data"
          }
          | errors
        ]
      else
        errors
      end

    # Validate fields
    fields_schema = Map.get(schema, "fields", %{})
    errors = errors ++ validate_data_fields(zone.content, fields_schema, "zone.#{zone.name}")

    errors
  end

  defp validate_zone(%Zone{type: :prose} = zone, schema) do
    errors = []

    # Check min_length
    min_length = Map.get(schema, "min_length")

    errors =
      if min_length && String.length(zone.content) < min_length do
        [
          %ValidationError{
            path: "zone.#{zone.name}",
            constraint: "min_length",
            message: "Prose content too short",
            expected: ">= #{min_length}",
            actual: String.length(zone.content)
          }
          | errors
        ]
      else
        errors
      end

    # Check max_length
    max_length = Map.get(schema, "max_length")

    errors =
      if max_length && String.length(zone.content) > max_length do
        [
          %ValidationError{
            path: "zone.#{zone.name}",
            constraint: "max_length",
            message: "Prose content too long",
            expected: "<= #{max_length}",
            actual: String.length(zone.content)
          }
          | errors
        ]
      else
        errors
      end

    errors
  end

  defp validate_zone(%Zone{type: :table} = zone, schema) do
    errors = []

    # Validate columns
    columns_schema = Map.get(schema, "columns", [])
    errors = errors ++ validate_table_columns(zone.content, columns_schema, zone.name)

    errors
  end

  defp validate_zone(%Zone{type: :list} = zone, schema) do
    errors = []

    # Check min_length
    min_length = Map.get(schema, "min_length")

    errors =
      if min_length && length(zone.content) < min_length do
        [
          %ValidationError{
            path: "zone.#{zone.name}",
            constraint: "min_length",
            message: "List has too few items",
            expected: ">= #{min_length}",
            actual: length(zone.content)
          }
          | errors
        ]
      else
        errors
      end

    # Check max_length
    max_length = Map.get(schema, "max_length")

    errors =
      if max_length && length(zone.content) > max_length do
        [
          %ValidationError{
            path: "zone.#{zone.name}",
            constraint: "max_length",
            message: "List has too many items",
            expected: "<= #{max_length}",
            actual: length(zone.content)
          }
          | errors
        ]
      else
        errors
      end

    errors
  end

  defp validate_zone(%Zone{} = _zone, _schema) do
    # Raw and seq zones - minimal validation for now
    []
  end

  defp validate_data_fields(data, fields_schema, path) when is_map(data) do
    # Check required fields
    required_errors =
      fields_schema
      |> Enum.filter(fn {_name, schema} -> Map.get(schema, "required", false) end)
      |> Enum.flat_map(fn {name, _schema} ->
        if Map.has_key?(data, name) do
          []
        else
          [
            %ValidationError{
              path: "#{path}.#{name}",
              constraint: "required",
              message: "Required field '#{name}' is missing",
              expected: "present",
              actual: "missing"
            }
          ]
        end
      end)

    # Validate each field's value
    value_errors =
      Enum.flat_map(data, fn {key, value} ->
        field_schema = Map.get(fields_schema, key, %{})
        validate_field_value(value, field_schema, "#{path}.#{key}")
      end)

    required_errors ++ value_errors
  end

  defp validate_data_fields(_data, _fields_schema, _path), do: []

  defp validate_field_value(value, schema, path) when map_size(schema) == 0 do
    # No schema for this field - skip validation
    _ = {value, path}
    []
  end

  defp validate_field_value(value, schema, path) do
    errors = []

    # Check nullable
    nullable = Map.get(schema, "nullable", true)

    errors =
      if value == nil && !nullable do
        [
          %ValidationError{
            path: path,
            constraint: "nullable",
            message: "Field cannot be null",
            expected: "non-null",
            actual: nil
          }
          | errors
        ]
      else
        errors
      end

    # If null and nullable, skip further checks
    if value == nil do
      errors
    else
      errors = errors ++ validate_type(value, schema, path)
      errors = errors ++ validate_constraints(value, schema, path)
      errors
    end
  end

  defp validate_type(value, schema, path) do
    expected_type = Map.get(schema, "type")

    if expected_type == nil do
      []
    else
      actual_type = infer_type(value)

      if type_matches?(actual_type, expected_type) do
        []
      else
        [
          %ValidationError{
            path: path,
            constraint: "type",
            message: "Type mismatch",
            expected: expected_type,
            actual: actual_type
          }
        ]
      end
    end
  end

  defp infer_type(value) when is_binary(value), do: "string"
  defp infer_type(value) when is_integer(value), do: "integer"
  defp infer_type(value) when is_float(value), do: "float"
  defp infer_type(value) when is_boolean(value), do: "boolean"
  defp infer_type(value) when is_nil(value), do: "null"
  defp infer_type(value) when is_list(value), do: "array"
  defp infer_type(value) when is_map(value), do: "object"
  defp infer_type(%DateTime{}), do: "datetime"
  defp infer_type(%NaiveDateTime{}), do: "datetime"
  defp infer_type(%Date{}), do: "date"
  defp infer_type(%Time{}), do: "time"
  defp infer_type(_), do: "unknown"

  defp type_matches?(actual, expected) do
    actual == expected or
      (actual == "integer" and expected == "number") or
      (actual == "float" and expected == "number")
  end

  defp validate_constraints(value, schema, path) do
    errors = []

    # Pattern constraint (for strings)
    errors =
      case Map.get(schema, "pattern") do
        nil ->
          errors

        pattern when is_binary(value) ->
          case Regex.compile(pattern) do
            {:ok, regex} ->
              if Regex.match?(regex, value) do
                errors
              else
                [
                  %ValidationError{
                    path: path,
                    constraint: "pattern",
                    message: "Value does not match pattern",
                    expected: pattern,
                    actual: value
                  }
                  | errors
                ]
              end

            {:error, _} ->
              errors
          end

        _ ->
          errors
      end

    # Min constraint (for numbers)
    errors =
      case Map.get(schema, "min") do
        nil ->
          errors

        min when is_number(value) ->
          if value >= min do
            errors
          else
            [
              %ValidationError{
                path: path,
                constraint: "min",
                message: "Value below minimum",
                expected: ">= #{min}",
                actual: value
              }
              | errors
            ]
          end

        _ ->
          errors
      end

    # Max constraint (for numbers)
    errors =
      case Map.get(schema, "max") do
        nil ->
          errors

        max when is_number(value) ->
          if value <= max do
            errors
          else
            [
              %ValidationError{
                path: path,
                constraint: "max",
                message: "Value above maximum",
                expected: "<= #{max}",
                actual: value
              }
              | errors
            ]
          end

        _ ->
          errors
      end

    # Min length (for strings and arrays)
    errors =
      case Map.get(schema, "min_length") do
        nil ->
          errors

        min_len when is_binary(value) ->
          if String.length(value) >= min_len do
            errors
          else
            [
              %ValidationError{
                path: path,
                constraint: "min_length",
                message: "String too short",
                expected: ">= #{min_len}",
                actual: String.length(value)
              }
              | errors
            ]
          end

        min_len when is_list(value) ->
          if length(value) >= min_len do
            errors
          else
            [
              %ValidationError{
                path: path,
                constraint: "min_length",
                message: "Array too short",
                expected: ">= #{min_len}",
                actual: length(value)
              }
              | errors
            ]
          end

        _ ->
          errors
      end

    # Max length (for strings and arrays)
    errors =
      case Map.get(schema, "max_length") do
        nil ->
          errors

        max_len when is_binary(value) ->
          if String.length(value) <= max_len do
            errors
          else
            [
              %ValidationError{
                path: path,
                constraint: "max_length",
                message: "String too long",
                expected: "<= #{max_len}",
                actual: String.length(value)
              }
              | errors
            ]
          end

        max_len when is_list(value) ->
          if length(value) <= max_len do
            errors
          else
            [
              %ValidationError{
                path: path,
                constraint: "max_length",
                message: "Array too long",
                expected: "<= #{max_len}",
                actual: length(value)
              }
              | errors
            ]
          end

        _ ->
          errors
      end

    # Enum constraint
    errors =
      case Map.get(schema, "enum") do
        nil ->
          errors

        allowed when is_list(allowed) ->
          if value in allowed do
            errors
          else
            [
              %ValidationError{
                path: path,
                constraint: "enum",
                message: "Value not in allowed list",
                expected: allowed,
                actual: value
              }
              | errors
            ]
          end

        _ ->
          errors
      end

    # Format constraint
    errors =
      case Map.get(schema, "format") do
        nil -> errors
        format when is_binary(value) -> validate_format(value, format, path, errors)
        _ -> errors
      end

    errors
  end

  defp validate_format(value, "email", path, errors) do
    if Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, value) do
      errors
    else
      [
        %ValidationError{
          path: path,
          constraint: "format",
          message: "Invalid email format",
          expected: "email",
          actual: value
        }
        | errors
      ]
    end
  end

  defp validate_format(value, "uri", path, errors) do
    case URI.parse(value) do
      %URI{scheme: scheme} when not is_nil(scheme) ->
        errors

      _ ->
        [
          %ValidationError{
            path: path,
            constraint: "format",
            message: "Invalid URI format",
            expected: "uri",
            actual: value
          }
          | errors
        ]
    end
  end

  defp validate_format(value, "uuid", path, errors) do
    uuid_regex = ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

    if Regex.match?(uuid_regex, value) do
      errors
    else
      [
        %ValidationError{
          path: path,
          constraint: "format",
          message: "Invalid UUID format",
          expected: "uuid",
          actual: value
        }
        | errors
      ]
    end
  end

  defp validate_format(value, "hostname", path, errors) do
    hostname_regex = ~r/^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/

    if Regex.match?(hostname_regex, value) do
      errors
    else
      [
        %ValidationError{
          path: path,
          constraint: "format",
          message: "Invalid hostname format",
          expected: "hostname",
          actual: value
        }
        | errors
      ]
    end
  end

  defp validate_format(value, "ipv4", path, errors) do
    ipv4_regex = ~r/^(\d{1,3}\.){3}\d{1,3}$/

    valid =
      if Regex.match?(ipv4_regex, value) do
        value
        |> String.split(".")
        |> Enum.all?(fn part ->
          case Integer.parse(part) do
            {num, ""} -> num >= 0 and num <= 255
            _ -> false
          end
        end)
      else
        false
      end

    if valid do
      errors
    else
      [
        %ValidationError{
          path: path,
          constraint: "format",
          message: "Invalid IPv4 format",
          expected: "ipv4",
          actual: value
        }
        | errors
      ]
    end
  end

  defp validate_format(value, "semver", path, errors) do
    semver_regex = ~r/^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$/

    if Regex.match?(semver_regex, value) do
      errors
    else
      [
        %ValidationError{
          path: path,
          constraint: "format",
          message: "Invalid semver format",
          expected: "semver",
          actual: value
        }
        | errors
      ]
    end
  end

  defp validate_format(_value, _format, _path, errors) do
    # Unknown format - skip validation
    errors
  end

  defp validate_table_columns(rows, columns_schema, zone_name) do
    rows
    |> Enum.with_index()
    |> Enum.flat_map(fn {row, row_idx} ->
      validate_table_row(row, columns_schema, zone_name, row_idx)
    end)
  end

  defp validate_table_row(row, columns_schema, zone_name, row_idx) do
    columns_schema
    |> Enum.flat_map(fn col_schema ->
      col_name = Map.get(col_schema, "name")
      value = Map.get(row, col_name)
      path = "zone.#{zone_name}[#{row_idx}].#{col_name}"

      errors = []

      # Check nullable
      nullable = Map.get(col_schema, "nullable", true)

      errors =
        if value == nil && !nullable do
          [
            %ValidationError{
              path: path,
              constraint: "nullable",
              message: "Column cannot be null",
              expected: "non-null",
              actual: nil
            }
            | errors
          ]
        else
          errors
        end

      # Check unique (if specified, validate across all rows)
      # This is simplified - a full implementation would check uniqueness properly
      errors = errors ++ validate_constraints(value, col_schema, path)

      errors
    end)
  end

  @doc """
  Loads and parses a schema from a file.
  """
  @spec load_schema(Path.t()) :: {:ok, Document.t()} | {:error, Error.t()}
  def load_schema(path) do
    Crisp.decode_file(path)
  end

  @doc """
  Creates a schema document from a map definition.
  """
  @spec from_map(map()) :: Document.t()
  def from_map(schema_map) do
    %Document{
      preamble: %{"crisp" => "1.0", "schema-version" => "1.0"},
      zones: [
        %Zone{
          type: :data,
          name: "schema",
          content: schema_map
        }
      ]
    }
  end
end
