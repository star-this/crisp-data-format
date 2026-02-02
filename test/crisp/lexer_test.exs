defmodule Crisp.LexerTest do
  use ExUnit.Case
  alias Crisp.Lexer

  describe "tokenize/1" do
    test "tokenizes preamble directives" do
      input = """
      %crisp 1.0
      %title "Test Document"
      %author "Alice"
      """

      {:ok, tokens} = Lexer.tokenize(input)

      directives =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :directive end)
        |> Enum.map(fn {:directive, {name, value}, _, _} -> {name, value} end)

      assert {"crisp", "1.0"} in directives
      assert {"title", "Test Document"} in directives
      assert {"author", "Alice"} in directives
    end

    test "tokenizes zone markers" do
      input = """
      @data:config
        key = "value"

      @prose:readme
        Hello
      @end
      """

      {:ok, tokens} = Lexer.tokenize(input)

      zone_markers =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :zone_marker end)
        |> Enum.map(fn {:zone_marker, {type, name, _hints}, _, _} -> {type, name} end)

      assert {:data, "config"} in zone_markers
      assert {:prose, "readme"} in zone_markers
    end

    test "tokenizes zone markers with hints" do
      input = "@table:users [id:int, name:str, active:bool]\n@end"

      {:ok, tokens} = Lexer.tokenize(input)

      [{:zone_marker, {:table, "users", hints}, _, _} | _] = tokens

      assert hints[:columns] == [
               %{name: "id", type: "int"},
               %{name: "name", type: "str"},
               %{name: "active", type: "bool"}
             ]
    end

    test "tokenizes data zone content" do
      input = """
      @data:config
        name = "test"
        count = 42
        enabled = true
        ratio = 3.14
        missing = ~
      """

      {:ok, tokens} = Lexer.tokenize(input)

      key_tokens =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :key end)
        |> Enum.map(fn {:key, name, _, _} -> name end)

      assert "name" in key_tokens
      assert "count" in key_tokens
      assert "enabled" in key_tokens
      assert "ratio" in key_tokens
      assert "missing" in key_tokens
    end

    test "tokenizes string values" do
      input = ~s(@data:test\n  basic = "hello"\n  escaped = "line1\\nline2"\n  literal = 'no\\escape')

      {:ok, tokens} = Lexer.tokenize(input)

      string_values =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :string end)
        |> Enum.map(fn {:string, val, _, _} -> val end)

      assert "hello" in string_values
      assert "line1\nline2" in string_values
      assert "no\\escape" in string_values
    end

    test "tokenizes numeric values" do
      input = """
      @data:numbers
        dec = 42
        neg = -17
        hex = 0xDEAD
        oct = 0o755
        bin = 0b1010
        flt = 3.14
        sci = 1e10
      """

      {:ok, tokens} = Lexer.tokenize(input)

      int_values =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :integer end)
        |> Enum.map(fn {:integer, val, _, _} -> val end)

      assert 42 in int_values
      assert -17 in int_values
      assert 0xDEAD in int_values
      assert 0o755 in int_values
      assert 0b1010 in int_values
    end

    test "tokenizes datetime values" do
      input = """
      @data:dates
        full = 2026-02-02T10:30:00Z
        date = 2026-02-02
        time = 10:30:00
      """

      {:ok, tokens} = Lexer.tokenize(input)

      datetime_tokens =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :datetime end)

      date_tokens =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :date end)

      time_tokens =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :time end)

      assert length(datetime_tokens) == 1
      assert length(date_tokens) == 1
      assert length(time_tokens) == 1
    end

    test "tokenizes arrays" do
      input = ~s(@data:arrays\n  nums = [1, 2, 3]\n  strs = ["a", "b", "c"])

      {:ok, tokens} = Lexer.tokenize(input)

      array_tokens =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :array end)
        |> Enum.map(fn {:array, val, _, _} -> val end)

      assert [1, 2, 3] in array_tokens
      assert ["a", "b", "c"] in array_tokens
    end

    test "tokenizes table headers" do
      input = """
      @data:config
        [server]
        host = "localhost"

        [[routes]]
        path = "/api"
      """

      {:ok, tokens} = Lexer.tokenize(input)

      lbracket_tokens =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :lbracket end)
        |> Enum.map(fn {:lbracket, path, _, _} -> path end)

      double_lbracket_tokens =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :double_lbracket end)
        |> Enum.map(fn {:double_lbracket, path, _, _} -> path end)

      assert "server" in lbracket_tokens
      assert "routes" in double_lbracket_tokens
    end

    test "tokenizes comments" do
      input = """
      # This is a comment
      @data:config
        key = "value"  # inline comment
      """

      {:ok, tokens} = Lexer.tokenize(input)

      comment_tokens =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :comment end)

      assert length(comment_tokens) >= 1
    end

    test "tokenizes prose zone content as text" do
      input = """
      @prose:readme
        # Heading

        This is **bold** text.
      @end
      """

      {:ok, tokens} = Lexer.tokenize(input)

      text_tokens =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :text end)

      # Prose content is tokenized as text lines
      assert length(text_tokens) >= 1
    end

    test "tokenizes seq zone entries" do
      input = """
      @seq:messages
        [message role=user timestamp=2026-02-02T10:00:00Z]
          Hello
        [/message]
      @end
      """

      {:ok, tokens} = Lexer.tokenize(input)

      entry_open_tokens =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :entry_open end)

      entry_close_tokens =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :entry_close end)

      assert length(entry_open_tokens) == 1
      assert length(entry_close_tokens) == 1

      [{:entry_open, {"message", attrs}, _, _}] = entry_open_tokens
      assert attrs["role"] == "user"
    end

    test "tokenizes @ref directive" do
      input = """
      @data:base
        timeout = 30

      @data:production
        @ref base
        timeout = 60
      """

      {:ok, tokens} = Lexer.tokenize(input)

      ref_tokens =
        tokens
        |> Enum.filter(fn {type, _, _, _} -> type == :ref end)
        |> Enum.map(fn {:ref, name, _, _} -> name end)

      assert "base" in ref_tokens
    end

    test "handles CRLF line endings" do
      input = "%crisp 1.0\r\n@data:config\r\n  key = \"value\"\r\n"

      {:ok, tokens} = Lexer.tokenize(input)
      assert Enum.any?(tokens, fn {type, _, _, _} -> type == :directive end)
      assert Enum.any?(tokens, fn {type, _, _, _} -> type == :zone_marker end)
    end
  end
end
