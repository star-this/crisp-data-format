defmodule Crisp.ParserTest do
  use ExUnit.Case
  alias Crisp.Parser

  describe "parse/1 - preamble" do
    test "parses empty preamble" do
      content = "@data:config\n  key = \"value\""

      {:ok, doc} = Parser.parse(content)
      assert doc.preamble == %{}
    end

    test "parses preamble with version" do
      content = """
      %crisp 1.0

      @data:config
        key = "value"
      """

      {:ok, doc} = Parser.parse(content)
      assert doc.preamble["crisp"] == "1.0"
    end

    test "parses preamble with multiple directives" do
      content = """
      %crisp 1.0
      %title "Test Document"
      %author "Alice"
      %created 2026-02-02T10:30:00Z

      @data:config
        key = "value"
      """

      {:ok, doc} = Parser.parse(content)
      assert doc.preamble["crisp"] == "1.0"
      assert doc.preamble["title"] == "Test Document"
      assert doc.preamble["author"] == "Alice"
    end

    test "parses custom directives" do
      content = """
      %crisp 1.0
      %x-custom value

      @data:config
        key = "value"
      """

      {:ok, doc} = Parser.parse(content)
      assert doc.preamble["x-custom"] == "value"
    end
  end

  describe "parse/1 - data zones" do
    test "parses simple key-value pairs" do
      content = """
      @data:config
        name = "test"
        count = 42
        enabled = true
        ratio = 3.14
        missing = ~
      """

      {:ok, doc} = Parser.parse(content)
      config = hd(doc.zones)

      assert config.content["name"] == "test"
      assert config.content["count"] == 42
      assert config.content["enabled"] == true
      assert config.content["ratio"] == 3.14
      assert config.content["missing"] == nil
    end

    test "parses nested tables" do
      content = """
      @data:config
        [server]
        host = "localhost"
        port = 8080

        [server.database]
        name = "mydb"
      """

      {:ok, doc} = Parser.parse(content)
      config = hd(doc.zones)

      assert config.content["server"]["host"] == "localhost"
      assert config.content["server"]["port"] == 8080
      assert config.content["server"]["database"]["name"] == "mydb"
    end

    test "parses array of tables" do
      content = """
      @data:config
        [[routes]]
        path = "/api"
        method = "GET"

        [[routes]]
        path = "/users"
        method = "POST"
      """

      {:ok, doc} = Parser.parse(content)
      config = hd(doc.zones)

      assert length(config.content["routes"]) == 2
      assert Enum.at(config.content["routes"], 0)["path"] == "/api"
      assert Enum.at(config.content["routes"], 1)["path"] == "/users"
    end

    test "parses arrays" do
      content = """
      @data:config
        numbers = [1, 2, 3]
        strings = ["a", "b", "c"]
        mixed = [1, "two", true, ~]
        nested = [[1, 2], [3, 4]]
      """

      {:ok, doc} = Parser.parse(content)
      config = hd(doc.zones)

      assert config.content["numbers"] == [1, 2, 3]
      assert config.content["strings"] == ["a", "b", "c"]
      assert config.content["mixed"] == [1, "two", true, nil]
      assert config.content["nested"] == [[1, 2], [3, 4]]
    end

    test "parses inline tables" do
      content = """
      @data:config
        point = { x = 10, y = 20 }
      """

      {:ok, doc} = Parser.parse(content)
      config = hd(doc.zones)

      assert config.content["point"]["x"] == 10
      assert config.content["point"]["y"] == 20
    end

    test "parses @ref references" do
      content = """
      @data:defaults
        timeout = 30
        retries = 3

      @data:production
        @ref defaults
        timeout = 60
      """

      {:ok, doc} = Parser.parse(content)
      production = Enum.find(doc.zones, &(&1.name == "production"))

      # Should have inherited retries from defaults
      assert production.content["retries"] == 3
      # Should have overridden timeout
      assert production.content["timeout"] == 60
    end

    test "returns error for undefined reference" do
      content = """
      @data:config
        @ref undefined_zone
        key = "value"
      """

      {:error, error} = Parser.parse(content)
      assert error.category == :reference
    end
  end

  describe "parse/1 - prose zones" do
    test "parses prose content" do
      content = """
      @prose:readme
        # Hello World

        This is **markdown** content.

        - Item 1
        - Item 2
      @end
      """

      {:ok, doc} = Parser.parse(content)
      readme = hd(doc.zones)

      assert readme.type == :prose
      assert String.contains?(readme.content, "# Hello World")
      assert String.contains?(readme.content, "**markdown**")
    end

    test "applies dedentation to prose" do
      content = """
      @prose:readme
        # Heading

          Indented paragraph

        Normal paragraph
      @end
      """

      {:ok, doc} = Parser.parse(content)
      readme = hd(doc.zones)

      # The content should be dedented based on minimum indent
      lines = String.split(readme.content, "\n")
      first_non_empty = Enum.find(lines, &(String.trim(&1) != ""))
      assert String.starts_with?(first_non_empty, "#")
    end

    test "preserves # as content not comment" do
      content = """
      @prose:readme
        # This is a heading
        ## This is also a heading
      @end
      """

      {:ok, doc} = Parser.parse(content)
      readme = hd(doc.zones)

      assert String.contains?(readme.content, "# This is a heading")
      assert String.contains?(readme.content, "## This is also a heading")
    end

    test "returns error for missing @end" do
      content = """
      @prose:readme
        Some content
      @data:next
        key = "value"
      """

      {:error, error} = Parser.parse(content)
      assert error.category == :syntax
    end
  end

  describe "parse/1 - table zones" do
    test "parses table with typed columns" do
      content = """
      @table:users [id:int, name:str, active:bool]
      \t1\tAlice\ttrue
      \t2\tBob\tfalse
      @end
      """

      {:ok, doc} = Parser.parse(content)
      users = hd(doc.zones)

      assert users.type == :table
      assert length(users.content) == 2

      first_row = Enum.at(users.content, 0)
      assert first_row["id"] == 1
      assert first_row["name"] == "Alice"
      assert first_row["active"] == true
    end

    test "handles null values in tables" do
      content = """
      @table:data [id:int, value:str]
      \t1\t~
      \t2\thello
      @end
      """

      {:ok, doc} = Parser.parse(content)
      data = hd(doc.zones)

      first_row = Enum.at(data.content, 0)
      assert first_row["value"] == nil

      second_row = Enum.at(data.content, 1)
      assert second_row["value"] == "hello"
    end

    test "handles empty strings vs null" do
      content = """
      @table:data [a:str, b:str]
      \t\t~
      @end
      """

      {:ok, doc} = Parser.parse(content)
      data = hd(doc.zones)

      row = Enum.at(data.content, 0)
      assert row["a"] == ""
      assert row["b"] == nil
    end

    test "parses date columns" do
      content = """
      @table:events [id:int, date:date, timestamp:datetime]
      \t1\t2026-02-02\t2026-02-02T10:30:00Z
      @end
      """

      {:ok, doc} = Parser.parse(content)
      events = hd(doc.zones)

      row = Enum.at(events.content, 0)
      assert row["date"] == ~D[2026-02-02]
      assert %DateTime{} = row["timestamp"]
    end
  end

  describe "parse/1 - list zones" do
    test "parses string list" do
      content = """
      @list:hosts [str]
        localhost
        127.0.0.1
        example.com
      @end
      """

      {:ok, doc} = Parser.parse(content)
      hosts = hd(doc.zones)

      assert hosts.type == :list
      assert hosts.content == ["localhost", "127.0.0.1", "example.com"]
    end

    test "parses integer list" do
      content = """
      @list:numbers [int]
        1
        2
        3
      @end
      """

      {:ok, doc} = Parser.parse(content)
      numbers = hd(doc.zones)

      assert numbers.content == [1, 2, 3]
    end

    test "parses list with null values" do
      content = """
      @list:optional [int]
        1
        ~
        3
      @end
      """

      {:ok, doc} = Parser.parse(content)
      optional = hd(doc.zones)

      assert optional.content == [1, nil, 3]
    end

    test "parses multiline items with continuation" do
      content = """
      @list:items [str]
        simple item
        |multi-line
        |item here
        another simple
      @end
      """

      {:ok, doc} = Parser.parse(content)
      items = hd(doc.zones)

      assert length(items.content) == 3
      assert Enum.at(items.content, 0) == "simple item"
      assert Enum.at(items.content, 1) == "multi-line\nitem here"
      assert Enum.at(items.content, 2) == "another simple"
    end
  end

  describe "parse/1 - raw zones" do
    test "preserves content verbatim" do
      content = """
      @raw:template [lang=html]
      <div>
        {{ content }}
      </div>
      @end
      """

      {:ok, doc} = Parser.parse(content)
      template = hd(doc.zones)

      assert template.type == :raw
      assert String.contains?(template.content, "<div>")
      assert String.contains?(template.content, "{{ content }}")
    end

    test "preserves special characters" do
      content = """
      @raw:code
      # This is not a comment
      @ref this-is-not-a-ref
      key = "not parsed"
      @end
      """

      {:ok, doc} = Parser.parse(content)
      code = hd(doc.zones)

      assert String.contains?(code.content, "# This is not a comment")
      assert String.contains?(code.content, "@ref")
    end

    test "no dedentation is applied" do
      content = """
      @raw:indented
          Indented content
            More indented
      @end
      """

      {:ok, doc} = Parser.parse(content)
      indented = hd(doc.zones)

      # Should preserve exact whitespace
      assert String.starts_with?(indented.content, "    ")
    end
  end

  describe "parse/1 - seq zones" do
    test "parses entries with attributes" do
      content = """
      @seq:messages
        [message role=user]
          Hello
        [/message]

        [message role=assistant]
          Hi there!
        [/message]
      @end
      """

      {:ok, doc} = Parser.parse(content)
      messages = hd(doc.zones)

      assert messages.type == :seq
      assert length(messages.content) == 2

      first = Enum.at(messages.content, 0)
      assert first.type == "message"
      assert first.attributes["role"] == "user"
      assert String.trim(first.content) == "Hello"
    end

    test "parses entry attributes with various types" do
      content = """
      @seq:events
        [event type=login timestamp=2026-02-02T10:00:00Z count=5]
          User logged in
        [/event]
      @end
      """

      {:ok, doc} = Parser.parse(content)
      events = hd(doc.zones)

      event = Enum.at(events.content, 0)
      assert event.attributes["type"] == "login"
      assert event.attributes["count"] == 5
    end

    test "handles quoted attribute values" do
      content = """
      @seq:items
        [item name="Value with spaces"]
          Content
        [/item]
      @end
      """

      {:ok, doc} = Parser.parse(content)
      items = hd(doc.zones)

      item = Enum.at(items.content, 0)
      assert item.attributes["name"] == "Value with spaces"
    end
  end

  describe "parse/1 - multiple zones" do
    test "parses document with mixed zone types" do
      content = """
      %crisp 1.0

      @data:config
        name = "test"

      @prose:readme
        # Hello
      @end

      @table:users [id:int, name:str]
      \t1\tAlice
      @end

      @list:tags [str]
        tag1
        tag2
      @end
      """

      {:ok, doc} = Parser.parse(content)
      assert length(doc.zones) == 4

      types = Enum.map(doc.zones, & &1.type)
      assert types == [:data, :prose, :table, :list]
    end

    test "preserves zone order" do
      content = """
      @data:first
        a = 1

      @data:second
        b = 2

      @data:third
        c = 3
      """

      {:ok, doc} = Parser.parse(content)
      names = Enum.map(doc.zones, & &1.name)
      assert names == ["first", "second", "third"]
    end
  end
end
