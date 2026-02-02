defmodule CrispTest do
  use ExUnit.Case
  doctest Crisp

  describe "decode/1" do
    test "decodes a minimal document" do
      content = """
      %crisp 1.0

      @data:config
        name = "test"
      """

      assert {:ok, doc} = Crisp.decode(content)
      assert doc.preamble["crisp"] == "1.0"
      assert length(doc.zones) == 1

      config = Crisp.get_zone(doc, :data, "config")
      assert config.content["name"] == "test"
    end

    test "decodes document with all zone types" do
      content = """
      %crisp 1.0
      %title "Complete Example"

      @data:config
        key = "value"
        number = 42

      @prose:readme
        # Hello World

        This is **markdown** content.
      @end

      @table:users [id:int, name:str, active:bool]
      \t1\tAlice\ttrue
      \t2\tBob\tfalse
      @end

      @list:items [str]
        first
        second
        third
      @end

      @raw:template [lang=html]
      <div>{{ content }}</div>
      @end

      @seq:messages
        [message role=user]
          Hello
        [/message]
      @end
      """

      assert {:ok, doc} = Crisp.decode(content)
      assert doc.preamble["title"] == "Complete Example"
      assert length(doc.zones) == 6
    end

    test "returns error for invalid syntax" do
      content = """
      %crisp 1.0

      @invalid:zone
        this = is broken
      """

      assert {:error, %Crisp.Error{category: :syntax}} = Crisp.decode(content)
    end
  end

  describe "encode/1" do
    test "encodes a document back to string" do
      doc = Crisp.new(title: "Test Doc")
      doc = Crisp.add_zone(doc, :data, "config", %{"name" => "test", "version" => "1.0.0"})
      doc = Crisp.add_zone(doc, :prose, "readme", "# Hello\n\nWorld")

      assert {:ok, output} = Crisp.encode(doc)
      assert String.contains?(output, "%crisp")
      assert String.contains?(output, "@data:config")
      assert String.contains?(output, "@prose:readme")
      assert String.contains?(output, "@end")
    end

    test "round-trip decode/encode preserves data" do
      original = """
      %crisp 1.0

      @data:config
        name = "test"
        count = 42
        enabled = true
      """

      {:ok, doc} = Crisp.decode(original)
      {:ok, encoded} = Crisp.encode(doc)
      {:ok, doc2} = Crisp.decode(encoded)

      config1 = Crisp.get_zone(doc, :data, "config")
      config2 = Crisp.get_zone(doc2, :data, "config")

      assert config1.content == config2.content
    end
  end

  describe "get_zone/3" do
    test "returns zone by type and name" do
      content = """
      %crisp 1.0

      @data:config
        key = "value"

      @data:settings
        other = "data"
      """

      {:ok, doc} = Crisp.decode(content)

      config = Crisp.get_zone(doc, :data, "config")
      assert config.name == "config"
      assert config.content["key"] == "value"

      settings = Crisp.get_zone(doc, :data, "settings")
      assert settings.name == "settings"
      assert settings.content["other"] == "data"
    end

    test "returns nil for non-existent zone" do
      {:ok, doc} = Crisp.decode("%crisp 1.0\n@data:config\n  key = \"value\"")
      assert Crisp.get_zone(doc, :data, "missing") == nil
      assert Crisp.get_zone(doc, :prose, "config") == nil
    end
  end

  describe "get_zones_by_type/2" do
    test "returns all zones of given type" do
      content = """
      %crisp 1.0

      @data:one
        a = 1

      @prose:text
        Some text
      @end

      @data:two
        b = 2
      """

      {:ok, doc} = Crisp.decode(content)

      data_zones = Crisp.get_zones_by_type(doc, :data)
      assert length(data_zones) == 2
      assert Enum.map(data_zones, & &1.name) == ["one", "two"]

      prose_zones = Crisp.get_zones_by_type(doc, :prose)
      assert length(prose_zones) == 1
    end
  end

  describe "new/1 and add_zone/5" do
    test "creates empty document with preamble" do
      doc = Crisp.new(title: "My Doc", author: "Alice")

      assert doc.preamble[:version] == "1.0"
      assert doc.preamble[:title] == "My Doc"
      assert doc.preamble[:author] == "Alice"
      assert doc.zones == []
    end

    test "adds zones to document" do
      doc =
        Crisp.new()
        |> Crisp.add_zone(:data, "config", %{"key" => "value"})
        |> Crisp.add_zone(:prose, "readme", "# Hello")

      assert length(doc.zones) == 2
      assert Enum.at(doc.zones, 0).type == :data
      assert Enum.at(doc.zones, 1).type == :prose
    end
  end
end
