defmodule Watermelon.DSL do
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :steps, accumulate: true)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    steps = Module.get_attribute(env.module, :steps)

    quote bind_quoted: [steps: Macro.escape(steps)] do
      def apply_step(text, context) do
        unquote(steps)
        |> Enum.find_value({false, context}, fn {regex, name} ->
          case Regex.named_captures(regex, text) do
            nil -> nil
            matches -> {true, Watermelon.DSL.apply(__MODULE__, name, matches, context)}
          end
        end)
      end
    end
  end

  def apply(mod, name, matches, context) when is_map(context) do
    case apply(mod, name, [matches, context]) do
      :ok -> context
      {:ok, map} -> {:ok, Map.merge(context, Map.new(map))}
      value when is_map(value) or is_list(value) -> {:ok, Map.merge(context, Map.new(value))}
      other -> other
    end
  end

  defmacro defgiven(match, params \\ quote(do: _), context \\ quote(do: _), content) do
    add_step(:given, match, params, context, content)
  end

  defmacro defwhen(match, params \\ quote(do: _), context \\ quote(do: _), content) do
    add_step(:when, match, params, context, content)
  end

  defmacro defthen(match, params \\ quote(do: _), context \\ quote(do: _), content) do
    add_step(:then, match, params, context, content)
  end

  defp add_step(step_type, match, params, context, content) do
    match = Macro.escape(match)
    params = Macro.escape(params)
    context = Macro.escape(context)
    content = Macro.escape(content, unquote: true)

    quote bind_quoted: [
            match: match,
            params: params,
            context: context,
            content: content,
            step_type: step_type
          ] do
      name = Watermelon.DSL.register_step(__ENV__, step_type, match)

      def unquote(name)(unquote(params), unquote(context)), unquote(content)
    end
  end

  def register_step(%{module: module}, type, match) do
    name = :"step #{type} #{to_name(match)}"

    Module.put_attribute(module, :steps, {match, name})

    name
  end

  defp to_name(match) when is_binary(match), do: match
  defp to_name({:sigil_r, _, [{:<<>>, _, [name]}, _]}), do: name
  defp to_name({:sigil_R, _, [{:<<>>, _, [name]}, _]}), do: name
end
