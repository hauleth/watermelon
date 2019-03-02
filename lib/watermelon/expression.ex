defmodule Watermelon.Expression do
  defstruct [:raw, :match]

  defmodule Type do
    @moduledoc false
    @enforce_keys [:name, :regexp]
    defstruct [:name, :regexp, :transform]
  end

  @opaque match_spec :: [{:text, binary()} | {:match, binary()} | {:optional, binary()}]

  @type t :: %__MODULE__{
          raw: binary(),
          match: Regex.t() | match_spec()
        }

  @doc ~S"""
  Creates new expression using provided type.

  When regular expression is passed then it will assume that this will be exactly
  the matcher for the given step, it will not use any transformations and will
  return all matched groups (but not whole match) to the match function.

  When string is passed it will parse it as a Cucumber expression and will be
  parsed as Cucumber expression.

  To match resulting value against your string, see `match/2`.

  ## Default types registered

  - `{int}` that will match `\d+` regular expression and will return number which
    is represented by decimal values that were matched
  - `{float}` that will match `\d*\.\d+` and will return float represented by
    the decimal value that is matched, it also allows floats without digits before
    dot, so `".1"` will be matched and will result with `0.1`
  - `{word}` that will match any whitespace delimited word
  - `{string}` that will match any quoted/double-quoted string (escaping of
    the nested quotes is not supported)
  - `{}` what will match any string, this can be used only once at the end of
    the string, otherwise will always cause match failures

  ## Examples

      iex> Watermelon.Expression.from(~r/^foo and (\d+) bar(:?s)$/)
      #Watermelon.Expression<~r/^foo and (\d+) bar(:?s)$/>

      iex> Watermelon.Expression.from("foo and {int} bar(s)")
      #Watermelon.Expression<foo and {int} bar(s)>

  Above expressions are will match exactly the same steps, however the second one
  (one using Cucumber expressions) will automatically convert matched value to
  integer while the one using regular expression will leave it as a string.
  """
  @spec from(Regex.t() | binary()) :: t()
  def from(%Regex{} = regex) do
    %__MODULE__{
      raw: Regex.source(regex),
      match: regex
    }
  end

  def from(string) when is_binary(string) do
    parsed = parse(string)

    %__MODULE__{raw: string, match: parsed}
  end

  # TYPES

  @doc ~S"""
  Register new type definition for Cucumber expressions.

  ## Example

      iex> Watermelon.Expression.register_type(:bin, ~r/[01]+/, &String.to_integer(&1, 2))
      iex>
      iex> match = Watermelon.Expression.from("match {bin}")
      iex> Watermelon.Expression.match(match, "match 101")
      {:ok, [5]}
  """
  @spec register_type(name :: binary(), regexp :: Regex.t(), transform) :: :ok
        when transform: (... -> term())
  def register_type(name, regexp, transform \\ & &1) do
    types = Application.get_env(:watermelon, :types, %{})
    name = to_string(name)

    Application.put_env(
      :watermelon,
      :types,
      Map.put(types, name, %Type{name: name, regexp: regexp, transform: transform})
    )

    :ok
  end

  defp get_type("int"),
    do: %Type{name: "int", regexp: ~r/-?\d+/, transform: &String.to_integer/1}

  defp get_type("float"),
    do: %Type{name: "float", regexp: ~r/-?\d*\.\d+(?:e\d+)?/, transform: &float/1}

  defp get_type("word"),
    do: %Type{name: "word", regexp: ~r/\w+/, transform: & &1}

  defp get_type("string"),
    do: %Type{name: "string", regexp: ~r/(?:"[^"]*"|'[^']*')/, transform: &string/1}

  defp get_type(""),
    do: %Type{name: "anonymous", regexp: ~r/.*/, transform: & &1}

  defp get_type(name) do
    types = Application.get_env(:watermelon, :types, %{})

    case Map.fetch(types, name) do
      {:ok, %Type{} = type} -> type
      :error ->
        proposals =
          types
          |> Map.keys()
          |> Enum.concat(~w[int float word string])
          |> Enum.filter(& String.jaro_distance(&1, name) > 0.5)
          |> Enum.sort()
          |> Enum.join("\n    ")

        raise """
        Undefined type `#{name}`.

        Did you mean:

            #{proposals}
        """
    end
  end

  ## MATCHING

  @doc """
  Run matching against expression.
  """
  @spec match(match :: t(), data :: binary()) :: {:ok, [term()]} | :error
  def match(%__MODULE__{match: %Regex{} = regex}, data) do
    case Regex.run(regex, data) do
      nil -> :error
      [_ | matches] -> {:ok, matches}
    end
  end

  def match(%__MODULE__{match: match}, data),
    do: match(match, data, [])

  defp match([], <<>>, values), do: {:ok, Enum.reverse(values)}

  defp match([], _, _), do: :error

  defp match([{:text, match} | matches], data, values) do
    with {:ok, data} <- split_match(match, data),
         do: match(matches, data, values)
  end

  defp match([{:optional, match} | matches], data, values) do
    case split_match(match, data) do
      {:ok, rest} -> match(matches, rest, values)
      :error -> match(matches, data, values)
    end
  end

  defp match([{:match, name} | matches], data, values) do
    matcher = get_type(name)

    case Regex.run(matcher.regexp, data) do
      nil ->
        :error

      [full | _] = match ->
        value = apply(matcher.transform, match)
        size = byte_size(full)
        rest = binary_part(data, size, byte_size(data) - size)

        match(matches, rest, [value | values])
    end
  end

  defp split_match("", rest), do: {:ok, rest}
  defp split_match(<<a>> <> match, <<a>> <> data), do: split_match(match, data)
  defp split_match(_, _), do: :error

  ## Parsing

  # Parse provided expression into stream of submatches accordingly to the Cucumber
  # expression syntax.
  #
  # ## Syntax
  #
  # - `{value}` is used to define submatch that will be provided to the match
  #   function. For list of allowed `value`s check out `register_type/3`
  # - `(opt)` optional string, that will be ignored if not present, it will
  #   be matched literally, so `{value}` matches within optional fragments will be
  #   ignored
  # - `a1/a2` alternative text, **not yet supported**
  #
  # If you want to match literal `{}` or `()` then you can escape it with `\` like:
  #
  #     ~S"foo \{bar}"
  #
  # Will match string
  #
  #     foo {bar}
  #
  # So as you can see you need to escape only first of the pair (but nothing stops
  # you from escaping both, that will do no harm).
  #
  # ## TODO:
  #
  # - Add support for alternative words
  @spec parse(binary()) :: match_spec()
  defp parse(expression) do
    expression
    |> parse({:text, ""}, [])
    |> Enum.reverse()
  end

  defp parse(<<>>, token, tokens), do: [token | tokens]

  defp parse(<<?\\, c>> <> rest, {type, agg}, tokens),
    do: parse(rest, {type, agg <> <<c>>}, tokens)

  defp parse("{" <> rest, agg, tokens),
    do: parse(rest, {:match, ""}, [agg | tokens])

  defp parse("}" <> rest, {:match, _} = token, tokens),
    do: parse(rest, {:text, ""}, [token | tokens])

  defp parse("(" <> rest, token, tokens),
    do: parse(rest, {:optional, ""}, [token | tokens])

  defp parse(")" <> rest, {:optional, _} = token, tokens),
    do: parse(rest, {:text, ""}, [token | tokens])

  defp parse(<<c>> <> rest, {type, agg}, tokens),
    do: parse(rest, {type, agg <> <<c>>}, tokens)

  ## HELPERS

  defp string(str) do
    size = byte_size(str)

    binary_part(str, 1, size - 2)
  end

  defp float("." <> frac), do: String.to_float("0." <> frac)
  defp float("-." <> frac), do: String.to_float("-0." <> frac)
  defp float(float), do: String.to_float(float)

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(expression, opts) do
      text =
        case expression.match do
          %Regex{} = regex -> to_doc(regex, opts)
          _ -> expression.raw
        end

      concat(["#Watermelon.Expression<", text, ">"])
    end
  end
end
