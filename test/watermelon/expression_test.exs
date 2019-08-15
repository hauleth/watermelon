defmodule Watermelon.ExpressionTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Watermelon.Expression, as: Subject

  doctest Subject

  defp non_escaped_string do
    gen(
      all(
        source <- string(:printable),
        do: String.replace(source, ~W[( ) \ { }], "")
      )
    )
  end

  describe "from/1 with regexp" do
    property "contains the same regexp as passed in" do
      check all(
              source <- non_escaped_string(),
              {:ok, regex} = Regex.compile(source)
            ) do
        assert %Subject{match: ^regex} = Subject.from(regex)
      end
    end

    property "raw contains regex source" do
      check all(
              source <- non_escaped_string(),
              {:ok, regex} = Regex.compile(source)
            ) do
        assert %Subject{raw: ^source} = Subject.from(regex)
      end
    end
  end

  describe "from/1 with expression" do
    property "raw contains source" do
      check all(source <- non_escaped_string()) do
        assert %Subject{raw: ^source} = Subject.from(source)
      end
    end
  end

  describe "match/2" do
    test "escaped braces matches literally" do
      matcher = Subject.from(~S"\{foo}")

      assert {:ok, _} = Subject.match(matcher, "{foo}")
    end

    test "escaped parenthesis matches literally" do
      matcher = Subject.from(~S"\(foo)")

      assert {:ok, _} = Subject.match(matcher, "(foo)")
    end

    property "optional block is ignored when not present" do
      check all(
              main <- non_escaped_string(),
              optional <- non_escaped_string()
            ) do
        matcher = Subject.from("#{main}(#{optional})")

        assert {:ok, _} = Subject.match(matcher, main)
        assert {:ok, _} = Subject.match(matcher, main <> optional)
      end
    end

    property "incomplete match fails" do
      check all(
              main <- non_escaped_string(),
              other <- string(:printable, min_length: 1)
            ) do
        matcher = Subject.from("#{main}#{other}")
        assert :error == Subject.match(matcher, main)

        matcher = Subject.from("#{other}#{main}")
        assert :error == Subject.match(matcher, main)
      end
    end

    test "throws error on unknown type" do
      assert_raise RuntimeError, ~r/Undefined type `foo`/, fn ->
        matcher = Subject.from("{foo}")

        Subject.match(matcher, "")
      end
    end

    test "suggests possible types" do
      assert_raise RuntimeError, ~r/\bfloat\b\s*\bword\b/, fn ->
        matcher = Subject.from("{foo}")

        Subject.match(matcher, "")
      end
    end

    property "{int} returns value parsed to integer" do
      matcher = Subject.from("{int}")

      check all(num <- integer()) do
        assert {:ok, [num]} == Subject.match(matcher, "#{num}")
      end
    end

    property "{float} returns value parsed to float" do
      matcher = Subject.from("{float}")

      check all(num <- float()) do
        assert {:ok, [num]} == Subject.match(matcher, "#{num}")
      end
    end

    test "{float} accepts floats with negative exponent" do
      matcher = Subject.from("{float}")

      assert {:ok, [-6.3e-30]} == Subject.match(matcher, "-6.3e-30")
    end

    property "{float} do not need preceding digits" do
      matcher = Subject.from("{float}")

      assert {:ok, [0.0]} == Subject.match(matcher, ".0")
      assert {:ok, [0.0]} == Subject.match(matcher, "-.0")

      check all(frac <- positive_integer()) do
        float = String.to_float("0.#{frac}")

        assert {:ok, [float]} == Subject.match(matcher, ".#{frac}")
        assert {:ok, [-float]} == Subject.match(matcher, "-.#{frac}")
      end
    end

    test "{float} parses value with scientific notation" do
      matcher = Subject.from("{float}")

      assert {:ok, [1.1e18]} == Subject.match(matcher, "1.1e18")
    end

    property "{word} matches single word" do
      check all(word <- string(:alphanumeric, min_length: 1)) do
        matcher = Subject.from("{word}")
        assert {:ok, [word]} == Subject.match(matcher, word)

        matcher = Subject.from("{word} bar")
        assert {:ok, [word]} == Subject.match(matcher, word <> " bar")
        assert :error == Subject.match(matcher, word <> " foo bar")
      end
    end

    property "{string} matches quoted string" do
      matcher = Subject.from("{string}")
      quotes = ~w[' "]

      for q <- quotes do
        check all(
                string <- non_escaped_string(),
                not String.contains?(string, q)
              ) do
          assert {:ok, [string]} == Subject.match(matcher, q <> string <> q)
          assert :error == Subject.match(matcher, q <> string)
          assert :error == Subject.match(matcher, string <> q)
        end
      end

      check all(
              string <- non_escaped_string(),
              not String.contains?(string, quotes)
            ) do
        assert :error == Subject.match(matcher, ~s('#{string}"))
        assert :error == Subject.match(matcher, ~s("#{string}'))
      end
    end

    property "{} matches any string" do
      check all(string <- non_escaped_string()) do
        matcher = Subject.from("{}")
        assert {:ok, [string]} == Subject.match(matcher, string)

        matcher = Subject.from("foo {}")
        assert {:ok, [string]} == Subject.match(matcher, "foo " <> string)
      end
    end

    test "regex match matches that regex" do
      matcher = Subject.from(~r/^hex [0-9a-f]+/)

      assert {:ok, _} = Subject.match(matcher, "hex deadbeef")
    end
  end

  describe "user defined types" do
    test "user can define custom type that will match respective regex" do
      name = "bin#{System.unique_integer()}"
      Subject.register_type(name, ~r/[01]+/, &String.to_integer(&1, 2))

      matcher = Subject.from("{#{name}}")

      assert {:ok, [5]} == Subject.match(matcher, "101")
      assert :error == Subject.match(matcher, "121")
    end

    test "transform function is called with matches" do
      name = "date#{System.unique_integer()}"

      Subject.register_type(name, ~r/(\d{4})-(\d{2})-(\d{2})/, fn _, year, month, day ->
        {:ok, date} =
          Date.new(
            String.to_integer(year),
            String.to_integer(month),
            String.to_integer(day)
          )

        date
      end)

      matcher = Subject.from("{#{name}}")

      assert {:ok, [~D[1993-03-16]]} == Subject.match(matcher, "1993-03-16")
    end
  end
end
