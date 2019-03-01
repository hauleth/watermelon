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

    quote location: :keep, bind_quoted: [steps: Macro.escape(steps)] do
      def apply_step(text, context) do
        unquote(steps)
        |> Enum.find_value({false, context}, fn {regex, transforms, name} ->
          case Regex.run(regex, text) do
            nil ->
              nil

            [_ | matches] ->
              {true, Watermelon.DSL.apply(__MODULE__, name, matches, transforms, context)}
          end
        end)
      end
    end
  end

  def apply(mod, name, matches, transforms, context) when is_map(context) do
    args =
      if transforms do
        for {{mod, func}, match} <- Enum.zip(transforms, matches), do: apply(mod, func, [match])
      else
        matches
      end

    case apply(mod, name, [context | args]) do
      :ok -> context
      {:ok, map} -> {:ok, Map.merge(context, Map.new(map))}
      value when is_map(value) or is_list(value) -> {:ok, Map.merge(context, Map.new(value))}
      other -> other
    end
  end

  defmacro defgiven({:when, _, [{:match, _, params}, match]}, options \\ [], do: body) do
    context = Keyword.get(options, :context, quote(do: _))
    params = params || []

    add_step(:given, match, params, context, body)
  end

  defmacro defwhen({:when, _, [{:match, _, params}, match]}, options \\ [], do: body) do
    context = Keyword.get(options, :context, quote(do: _))
    params = params || []

    add_step(:given, match, params, context, body)
  end

  defmacro defthen({:when, _, [{:match, _, params}, match]}, options \\ [], do: body) do
    context = Keyword.get(options, :context, quote(do: _))
    params = params || []

    add_step(:given, match, params, context, body)
  end

  defp add_step(step_type, match, params, context, body) do
    params = Macro.escape(params)
    context = Macro.escape(context)
    body = Macro.escape(body, unquote: true)

    quote bind_quoted: [
            match: match,
            params: params,
            context: context,
            body: body,
            step_type: step_type
          ] do
      expression = Watermelon.Expression.from(match)
      name = Watermelon.DSL.register_step(__ENV__, step_type, expression)

      def unquote(name)(unquote(context), unquote_splicing(params)) do
        unquote(body)
      end
    end
  end

  def register_step(%{module: module}, type, expression) do
    name = :"step #{type} #{expression.raw}"

    Module.put_attribute(
      module,
      :steps,
      Macro.escape({expression.regex, expression.transforms, name})
    )

    name
  end
end
