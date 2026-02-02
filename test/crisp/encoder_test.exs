defmodule Crisp.EncoderTest do
  use ExUnit.Case
  alias Crisp.{Encoder, Document, Zone}

  describe "encode/1 - preamble" do
    test "encodes empty preamble with version" do
      doc = %Document{preamble: %{}, zones: []}

      {:ok, output} = Encoder.encode(doc)
      # Should not include preamble if empty
      refute String.contains?(output, "%crisp")
    end

    test "encodes preamble with directives" do
      doc = %Document{
        preamble: %{
          "crisp" => "1.0",
          "title" => "Test Document",
          "author" => "Alice"
        },
        zones: []
      }

      {:ok, output} = Encoder.encode(doc)

      assert String.contains?(output, "%crisp 1.0")
      assert String.contains?(output, "%title")
      assert String.contains?(output, "%author")
    end

    test "quotes values with spaces" do
      doc = %Document{
        preamble: %{
          "crisp" => "1.0",
          "title" => "My Test Document"
        },
        zones: []
      }

      {:ok, output} = Encoder.encode(doc)
      assert String.contains?(output, ~s(%title "My Test Document"))
    end
  end

  describe "encode/1 - data zones" do
    test "encodes simple key-value pairs" do
      zone = %Zone{
        type: :data,
        name: "config",
        content: %{
          "name" => "test",
          "count" => 42,
          "enabled" => true
        }
      }

      doc = %Document{preamble: %{"crisp" => "1.0"}, zones: [zone]}
      {:ok, output} = Encoder.encode(doc)

      assert String.contains?(output, "@data:config")
      assert String.contains?(output, ~s(name = "test"))
      assert String.contains?(output, "count = 42")
      assert String.contains?(output, "enabled = true")
    end

    test "encodes null values" do
      zone = %Zone{
        type: :data,
        name: "config",
        content: %{"missing" => nil}
      }

      doc = %Document{preamble: %{}, zones: [zone]}
      {:ok, output} = Encoder.encode(doc)

      assert String.contains?(output, "missing = ~")
    end

    test "encodes arrays" do
      zone = %Zone{
        type: :data,
        name: "config",
        content: %{
          "numbers" => [1, 2, 3],
          "strings" => ["a", "b", "c"]
        }
      }

      doc = %Document{preamble: %{}, zones: [zone]}
      {:ok, output} = Encoder.encode(doc)

      assert String.contains?(output, "[1, 2, 3]")
      assert String.contains?(output, ~s(["a", "b", "c"]))
    end

    test "encodes nested tables" do
      zone = %Zone{
        type: :data,
        name: "config",
        content: %{
          "server" => %{
            "host" => "localhost",
            "port" => 8080
          }
        }
      }

      doc = %Document{preamble: %{}, zones: [zone]}
      {:ok, output} = Encoder.encode(doc)

      assert String.contains?(output, "[server]")
      assert String.contains?(output, ~s(host = "localhost"))
      assert String.contains?(output, "port = 8080")
    end

    test "encodes datetime values" do
      zone = %Zone{
        type: :data,
        name: "config",
        content: %{
          "date" => ~D[2026-02-02],
          "time" => ~T[10:30:00]
        }
      }

      doc = %Document{preamble: %{}, zones: [zone]}
      {:ok, output} = Encoder.encode(doc)

      assert String.contains?(output, "2026-02-02")
      assert String.contains?(output, "10:30:00")
    end

    test "encodes inline tables" do
      zone = %Zone{
        type: :data,
        name: "config",
        content: %{
          "point" => %{"x" => 10, "y" => 20}
        }
      }

      doc = %Document{preamble: %{}, zones: [zone]}
      {:ok, output} = Encoder.encode(doc)

      # Inline tables should be on one line
      assert String.contains?(output, "point = {") or String.contains?(output, "[point]")
    end
  end

  describe "encode/1 - prose zones" do
    test "encodes prose content with @end" do
      zone = %Zone{
        type: :prose,
        name: "readme",
        content: "# Hello\n\nThis is content."
      }

      doc = %Document{preamble: %{}, zones: [zone]}
      {:ok, output} = Encoder.encode(doc)

      assert String.contains?(output, "@prose:readme")
      assert String.contains?(output, "# Hello")
      assert String.contains?(output, "@end")
    end

    test "indents prose content" do
      zone = %Zone{
        type: :prose,
        name: "readme",
        content: "Line 1\nLine 2"
      }

      doc = %Document{preamble: %{}, zones: [zone]}
      {:ok, output} = Encoder.encode(doc)

      lines = String.split(output, "\n")
      content_lines = Enum.filter(lines, &String.contains?(&1, "Line"))

      # Content should be indented
      assert Enum.all?(content_lines, &String.starts_with?(&1, " "))
    end
  end

  describe "encode/1 - table zones" do
    test "encodes table with column definitions" do
      zone = %Zone{
        type: :table,
        name: "users",
        content: [
          %{"id" => 1, "name" => "Alice"},
          %{"id" => 2, "name" => "Bob"}
        ],
        hints: %{
          columns: [
            %{name: "id", type: "int"},
            %{name: "name", type: "str"}
          ]
        }
      }

      doc = %Document{preamble: %{}, zones: [zone]}
      {:ok, output} = Encoder.encode(doc)

      assert String.contains?(output, "@table:users")
      assert String.contains?(output, "[id:int, name:str]")
      assert String.contains?(output, "@end")
    end

    test "encodes null values as ~" do
      zone = %Zone{
        type: :table,
        name: "data",
        content: [%{"id" => 1, "value" => nil}],
        hints: %{
          columns: [
            %{name: "id", type: "int"},
            %{name: "value", type: "str"}
          ]
        }
      }

      doc = %Document{preamble: %{}, zones: [zone]}
      {:ok, output} = Encoder.encode(doc)

      assert String.contains?(output, "~")
    end
  end

  describe "encode/1 - list zones" do
    test "encodes list with type annotation" do
      zone = %Zone{
        type: :list,
        name: "hosts",
        content: ["localhost", "127.0.0.1"],
        hints: %{item_type: "str"}
      }

      doc = %Document{preamble: %{}, zones: [zone]}
      {:ok, output} = Encoder.encode(doc)

      assert String.contains?(output, "@list:hosts [str]")
      assert String.contains?(output, "localhost")
      assert String.contains?(output, "127.0.0.1")
      assert String.contains?(output, "@end")
    end

    test "encodes multiline items with continuation" do
      zone = %Zone{
        type: :list,
        name: "items",
        content: ["simple", "multi\nline\nitem"],
        hints: %{item_type: "str"}
      }

      doc = %Document{preamble: %{}, zones: [zone]}
      {:ok, output} = Encoder.encode(doc)

      assert String.contains?(output, "simple")
      assert String.contains?(output, "|")
    end
  end

  describe "encode/1 - raw zones" do
    test "encodes raw content without processing" do
      zone = %Zone{
        type: :raw,
        name: "template",
        content: "<div>{{ content }}</div>",
        hints: %{"lang" => "html"}
      }

      doc = %Document{preamble: %{}, zones: [zone]}
      {:ok, output} = Encoder.encode(doc)

      assert String.contains?(output, "@raw:template")
      assert String.contains?(output, "<div>{{ content }}</div>")
      assert String.contains?(output, "@end")
    end
  end

  describe "encode/1 - seq zones" do
    test "encodes seq entries with attributes" do
      zone = %Zone{
        type: :seq,
        name: "messages",
        content: [
          %{type: "message", attributes: %{"role" => "user"}, content: "Hello"},
          %{type: "message", attributes: %{"role" => "assistant"}, content: "Hi!"}
        ]
      }

      doc = %Document{preamble: %{}, zones: [zone]}
      {:ok, output} = Encoder.encode(doc)

      assert String.contains?(output, "@seq:messages")
      assert String.contains?(output, "[message role=user]")
      assert String.contains?(output, "[/message]")
      assert String.contains?(output, "@end")
    end
  end

  describe "encode/1 - options" do
    test "respects indent option" do
      zone = %Zone{
        type: :data,
        name: "config",
        content: %{"key" => "value"}
      }

      doc = %Document{preamble: %{}, zones: [zone]}

      {:ok, output_2} = Encoder.encode(doc, indent: 2)
      {:ok, output_4} = Encoder.encode(doc, indent: 4)

      # Check indentation differences
      assert String.contains?(output_2, "  key")
      assert String.contains?(output_4, "    key")
    end

    test "supports CRLF line endings" do
      zone = %Zone{type: :data, name: "config", content: %{"key" => "value"}}
      doc = %Document{preamble: %{}, zones: [zone]}

      {:ok, output} = Encoder.encode(doc, line_ending: :crlf)
      assert String.contains?(output, "\r\n")
    end
  end

  describe "round-trip encoding" do
    test "preserves data through decode/encode cycle" do
      original = """
      %crisp 1.0
      %title "Test"

      @data:config
        name = "test"
        count = 42
        enabled = true
        items = [1, 2, 3]
      """

      {:ok, doc1} = Crisp.decode(original)
      {:ok, encoded} = Crisp.encode(doc1)
      {:ok, doc2} = Crisp.decode(encoded)

      config1 = Crisp.get_zone(doc1, :data, "config")
      config2 = Crisp.get_zone(doc2, :data, "config")

      assert config1.content["name"] == config2.content["name"]
      assert config1.content["count"] == config2.content["count"]
      assert config1.content["enabled"] == config2.content["enabled"]
      assert config1.content["items"] == config2.content["items"]
    end
  end
end
