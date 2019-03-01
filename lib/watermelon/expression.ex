defmodule Watermelon.Expression do
  defstruct [:raw, :regex, :transforms]

  defmodule Type do
    @enforce_keys [:name, :regexp]
    defstruct [:name, :regexp, :transform]
  end

  def from(%Regex{} = regex) do
    %__MODULE__{
      raw: Regex.source(regex),
      regex: regex,
      transforms: nil
    }
  end

  def from(string) when is_binary(string), do: compile(string)

  def compile(raw) do
    parsed = parse(raw)
    regex =
      parsed
      |> Enum.map(&compile_token/1)
      |> Enum.join()
      |> Regex.compile!()

    transforms =
      for {:match, type} <- parsed, do: get_type(type).transform

    %__MODULE__{raw: raw, regex: regex, transforms: transforms}
  end

  defp compile_token(:start), do: "^"
  defp compile_token(:end), do: "$"
  defp compile_token({:text, text}), do: Regex.escape(text)
  defp compile_token({:optional, text}), do: "(?:#{Regex.escape(text)})?"
  defp compile_token({:match, type}), do: "(#{Regex.source(get_type(type).regexp)})"

  def register_type(name, regexp, transform) do
    types = Application.get_env(:watermelon, :types, %{})
    name = to_string(name)

    Application.put_env(
      :watermelon,
      :types,
      Map.put(types, name, %Type{name: name, regexp: regexp, transform: transform})
    )
  end

  defp get_type("int"),
    do: %Type{name: "int", regexp: ~r/\d+/, transform: {String, :to_integer}}

  defp get_type("float"),
    do: %Type{name: "float", regexp: ~r/\d*\.\d+/, transform: {__MODULE__, :float}}

  defp get_type("word"),
    do: %Type{name: "word", regexp: ~r/\w+/, transform: {__MODULE__, :id}}

  defp get_type("string"),
    do: %Type{name: "string", regexp: ~r/(?:"[^"]*"|'[^']*')/, transform: {__MODULE__, :string}}

  defp get_type(""),
    do: %Type{name: "anonymous", regexp: ~r/.*/, transform: {__MODULE__, :id}}

  defp get_type(name) do
    case Map.fetch(Application.get_env(:watermelon, :types, %{}), name) do
      {:ok, %Type{} = type} -> type
      :error -> raise "Undefined type `#{name}`"
    end
  end

  @doc false
  def id(data), do: data

  @doc false
  def float(str), do: String.to_float("0" <> str)

  @doc false
  def string(<<c>> <> str), do: String.trim(str, <<c>>)

  def parse(expression) do
    expression
    |> parse({:text, ""}, [:start])
    |> Enum.reverse([:end])
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
end
