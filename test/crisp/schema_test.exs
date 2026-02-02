defmodule Crisp.SchemaTest do
  use ExUnit.Case
  alias Crisp.{Schema, Document, Zone}

  def create_schema(schema_content) do
    %Document{
      preamble: %{"crisp" => "1.0"},
      zones: [
        %Zone{
          type: :data,
          name: "schema",
          content: schema_content
        }
      ]
    }
  end

  describe "validate/2 - required zones" do
    test "passes when all required zones present" do
      schema =
        create_schema(%{
          "document" => %{
            "required_zones" => ["config"]
          }
        })

      doc = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{}}]
      }

      {:ok, errors} = Schema.validate(doc, schema)
      assert errors == []
    end

    test "fails when required zone missing" do
      schema =
        create_schema(%{
          "document" => %{
            "required_zones" => ["config", "readme"]
          }
        })

      doc = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{}}]
      }

      {:ok, errors} = Schema.validate(doc, schema)
      assert length(errors) == 1
      assert hd(errors).constraint == "required_zones"
    end
  end

  describe "validate/2 - field constraints" do
    test "validates required fields" do
      schema =
        create_schema(%{
          "zones" => %{
            "config" => %{
              "fields" => %{
                "name" => %{"required" => true}
              }
            }
          }
        })

      doc = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{}}]
      }

      {:ok, errors} = Schema.validate(doc, schema)
      assert length(errors) == 1
      assert hd(errors).constraint == "required"
    end

    test "validates field types" do
      schema =
        create_schema(%{
          "zones" => %{
            "config" => %{
              "fields" => %{
                "count" => %{"type" => "integer"}
              }
            }
          }
        })

      doc = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"count" => "not an integer"}}]
      }

      {:ok, errors} = Schema.validate(doc, schema)
      assert length(errors) == 1
      assert hd(errors).constraint == "type"
    end

    test "validates pattern constraint" do
      schema =
        create_schema(%{
          "zones" => %{
            "config" => %{
              "fields" => %{
                "name" => %{"pattern" => "^[a-z]+$"}
              }
            }
          }
        })

      doc = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"name" => "Invalid123"}}]
      }

      {:ok, errors} = Schema.validate(doc, schema)
      assert length(errors) == 1
      assert hd(errors).constraint == "pattern"
    end

    test "validates min/max constraints" do
      schema =
        create_schema(%{
          "zones" => %{
            "config" => %{
              "fields" => %{
                "port" => %{"min" => 1, "max" => 65535}
              }
            }
          }
        })

      doc = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"port" => 100_000}}]
      }

      {:ok, errors} = Schema.validate(doc, schema)
      assert length(errors) == 1
      assert hd(errors).constraint == "max"
    end

    test "validates min_length/max_length for strings" do
      schema =
        create_schema(%{
          "zones" => %{
            "config" => %{
              "fields" => %{
                "name" => %{"min_length" => 3, "max_length" => 10}
              }
            }
          }
        })

      # Too short
      doc1 = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"name" => "ab"}}]
      }

      {:ok, errors1} = Schema.validate(doc1, schema)
      assert length(errors1) == 1
      assert hd(errors1).constraint == "min_length"

      # Too long
      doc2 = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"name" => "this is way too long"}}]
      }

      {:ok, errors2} = Schema.validate(doc2, schema)
      assert length(errors2) == 1
      assert hd(errors2).constraint == "max_length"
    end

    test "validates enum constraint" do
      schema =
        create_schema(%{
          "zones" => %{
            "config" => %{
              "fields" => %{
                "level" => %{"enum" => ["debug", "info", "warn", "error"]}
              }
            }
          }
        })

      doc = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"level" => "verbose"}}]
      }

      {:ok, errors} = Schema.validate(doc, schema)
      assert length(errors) == 1
      assert hd(errors).constraint == "enum"
    end

    test "validates nullable constraint" do
      schema =
        create_schema(%{
          "zones" => %{
            "config" => %{
              "fields" => %{
                "required_field" => %{"nullable" => false}
              }
            }
          }
        })

      doc = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"required_field" => nil}}]
      }

      {:ok, errors} = Schema.validate(doc, schema)
      assert length(errors) == 1
      assert hd(errors).constraint == "nullable"
    end
  end

  describe "validate/2 - format constraints" do
    test "validates email format" do
      schema =
        create_schema(%{
          "zones" => %{
            "config" => %{
              "fields" => %{
                "email" => %{"format" => "email"}
              }
            }
          }
        })

      # Valid
      doc1 = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"email" => "user@example.com"}}]
      }

      {:ok, errors1} = Schema.validate(doc1, schema)
      assert errors1 == []

      # Invalid
      doc2 = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"email" => "not-an-email"}}]
      }

      {:ok, errors2} = Schema.validate(doc2, schema)
      assert length(errors2) == 1
    end

    test "validates uri format" do
      schema =
        create_schema(%{
          "zones" => %{
            "config" => %{
              "fields" => %{
                "url" => %{"format" => "uri"}
              }
            }
          }
        })

      # Valid
      doc1 = %Document{
        preamble: %{},
        zones: [
          %Zone{type: :data, name: "config", content: %{"url" => "https://example.com/path"}}
        ]
      }

      {:ok, errors1} = Schema.validate(doc1, schema)
      assert errors1 == []

      # Invalid
      doc2 = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"url" => "not a url"}}]
      }

      {:ok, errors2} = Schema.validate(doc2, schema)
      assert length(errors2) == 1
    end

    test "validates uuid format" do
      schema =
        create_schema(%{
          "zones" => %{
            "config" => %{
              "fields" => %{
                "id" => %{"format" => "uuid"}
              }
            }
          }
        })

      # Valid
      doc1 = %Document{
        preamble: %{},
        zones: [
          %Zone{
            type: :data,
            name: "config",
            content: %{"id" => "550e8400-e29b-41d4-a716-446655440000"}
          }
        ]
      }

      {:ok, errors1} = Schema.validate(doc1, schema)
      assert errors1 == []

      # Invalid
      doc2 = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"id" => "not-a-uuid"}}]
      }

      {:ok, errors2} = Schema.validate(doc2, schema)
      assert length(errors2) == 1
    end

    test "validates semver format" do
      schema =
        create_schema(%{
          "zones" => %{
            "config" => %{
              "fields" => %{
                "version" => %{"format" => "semver"}
              }
            }
          }
        })

      # Valid
      doc1 = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"version" => "1.2.3"}}]
      }

      {:ok, errors1} = Schema.validate(doc1, schema)
      assert errors1 == []

      # Valid with pre-release
      doc2 = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"version" => "1.0.0-alpha.1"}}]
      }

      {:ok, errors2} = Schema.validate(doc2, schema)
      assert errors2 == []

      # Invalid
      doc3 = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"version" => "1.2"}}]
      }

      {:ok, errors3} = Schema.validate(doc3, schema)
      assert length(errors3) == 1
    end

    test "validates ipv4 format" do
      schema =
        create_schema(%{
          "zones" => %{
            "config" => %{
              "fields" => %{
                "ip" => %{"format" => "ipv4"}
              }
            }
          }
        })

      # Valid
      doc1 = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"ip" => "192.168.1.1"}}]
      }

      {:ok, errors1} = Schema.validate(doc1, schema)
      assert errors1 == []

      # Invalid (out of range)
      doc2 = %Document{
        preamble: %{},
        zones: [%Zone{type: :data, name: "config", content: %{"ip" => "256.1.1.1"}}]
      }

      {:ok, errors2} = Schema.validate(doc2, schema)
      assert length(errors2) == 1
    end
  end

  describe "validate/2 - prose zones" do
    test "validates prose min_length" do
      schema =
        create_schema(%{
          "zones" => %{
            "readme" => %{
              "min_length" => 50
            }
          }
        })

      doc = %Document{
        preamble: %{},
        zones: [%Zone{type: :prose, name: "readme", content: "Short"}]
      }

      {:ok, errors} = Schema.validate(doc, schema)
      assert length(errors) == 1
      assert hd(errors).constraint == "min_length"
    end

    test "validates prose max_length" do
      schema =
        create_schema(%{
          "zones" => %{
            "readme" => %{
              "max_length" => 10
            }
          }
        })

      doc = %Document{
        preamble: %{},
        zones: [%Zone{type: :prose, name: "readme", content: "This is way too long content"}]
      }

      {:ok, errors} = Schema.validate(doc, schema)
      assert length(errors) == 1
      assert hd(errors).constraint == "max_length"
    end
  end

  describe "validate/2 - list zones" do
    test "validates list min_length" do
      schema =
        create_schema(%{
          "zones" => %{
            "items" => %{
              "min_length" => 3
            }
          }
        })

      doc = %Document{
        preamble: %{},
        zones: [%Zone{type: :list, name: "items", content: ["a", "b"]}]
      }

      {:ok, errors} = Schema.validate(doc, schema)
      assert length(errors) == 1
      assert hd(errors).constraint == "min_length"
    end
  end

  describe "from_map/1" do
    test "creates schema document from map" do
      schema_map = %{
        "document" => %{"required_zones" => ["config"]},
        "zones" => %{
          "config" => %{
            "fields" => %{
              "name" => %{"required" => true}
            }
          }
        }
      }

      schema_doc = Schema.from_map(schema_map)

      assert schema_doc.preamble["crisp"] == "1.0"
      assert length(schema_doc.zones) == 1
      assert hd(schema_doc.zones).name == "schema"
    end
  end

  describe "complex validation" do
    test "validates document with multiple constraints" do
      schema =
        create_schema(%{
          "document" => %{
            "required_zones" => ["config"]
          },
          "zones" => %{
            "config" => %{
              "fields" => %{
                "name" => %{
                  "type" => "string",
                  "required" => true,
                  "min_length" => 1,
                  "max_length" => 50,
                  "pattern" => "^[a-z][a-z0-9-]*$"
                },
                "version" => %{
                  "type" => "string",
                  "required" => true,
                  "format" => "semver"
                },
                "port" => %{
                  "type" => "integer",
                  "min" => 1,
                  "max" => 65535
                }
              }
            }
          }
        })

      # Valid document
      valid_doc = %Document{
        preamble: %{},
        zones: [
          %Zone{
            type: :data,
            name: "config",
            content: %{
              "name" => "my-app",
              "version" => "1.0.0",
              "port" => 8080
            }
          }
        ]
      }

      {:ok, errors} = Schema.validate(valid_doc, schema)
      assert errors == []

      # Invalid document (multiple errors)
      invalid_doc = %Document{
        preamble: %{},
        zones: [
          %Zone{
            type: :data,
            name: "config",
            content: %{
              "name" => "Invalid-Name!",
              "version" => "not-semver",
              "port" => 100_000
            }
          }
        ]
      }

      {:ok, errors} = Schema.validate(invalid_doc, schema)
      assert length(errors) >= 3
    end
  end
end
