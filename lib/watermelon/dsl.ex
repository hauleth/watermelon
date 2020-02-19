# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Watermelon.DSL do
  @moduledoc """
  Module with helper functions for defining Gherkin steps.

  ## Defining steps

  There are 3 helper macros that allows you to define steps for your feature
  specs:

  - `defgiven/3`
  - `defwhen/3`
  - `defthen/3`

  All with exactly the same syntax:

  ```elixir
  defgiven match(a, b) when "sum of {int} and {int}" do
    {:ok, sum: a + b}
  end
  ```

  Syntax for `when` part is identical with `Watermelon.Expression.from/1` so you
  can provide either `Regex` or string. Matching groups are then the arguments
  for `match` function.

  ## Context

  Step definition can access and modify it's context which is a way to propagate
  values between different steps.

  Return value can be one of:

  - `true`
  - `:ok`
  - keyword list
  - map
  - tuple `{:ok, map() | keyword()}`

  In case of keyword list or map, the returned values will be merged into current
  context. When it is `:ok` or `true` then the context will be left as is.

  Context can be made available by using `:context` option:

  ```elixir
  defwhen match(a) when "I multiply sum by {int}", context: ctx do
    {:ok, result: a * ctx.sum}
  end
  ```

  ## TODO

  - add support for data table
  - add support for doc strings
  """

  @doc false
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
      def apply_step(%{text: text} = step, context) do
        unquote(steps)
        |> Enum.find_value(:error, fn {match, name} ->
          case Watermelon.Expression.match(match, text) do
            {:ok, matches} ->
              context = Map.put(context, :table_data, step.table_data)
              {:ok, Watermelon.DSL.apply(__MODULE__, name, matches, context)}

            :error ->
              false
          end
        end)
      end
    end
  end

  @doc false
  def apply(mod, name, matches, context) when is_map(context) do
    case apply(mod, name, [context | matches]) do
      true -> {:ok, context}
      :ok -> {:ok, context}
      {:ok, map} -> {:ok, Map.merge(context, Map.new(map))}
      value when is_map(value) or is_list(value) -> {:ok, Map.merge(context, Map.new(value))}
      other -> other
    end
  end

  defmacro defgiven({:when, _, [{:match, _, params}, match]}, options \\ [], do: body) do
    add_step(:given, match, params, options, body)
  end

  defmacro defwhen({:when, _, [{:match, _, params}, match]}, options \\ [], do: body) do
    add_step(:when, match, params, options, body)
  end

  defmacro defthen({:when, _, [{:match, _, params}, match]}, options \\ [], do: body) do
    add_step(:then, match, params, options, body)
  end

  defp add_step(step_type, match, params, opts, body) do
    params = Macro.escape(params || [])
    context = optional(opts, :context)
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

  @doc """
  Register new step function.

  Returns function name that must be used in step definition.
  """
  @spec register_step(Macro.Env.t(), atom(), Watermelon.Expression.t()) :: atom()
  def register_step(%{module: module}, type, expression) do
    name = :"step #{type} #{Watermelon.Expression.raw(expression)}"

    Module.put_attribute(
      module,
      :steps,
      Macro.escape({expression, name})
    )

    name
  end

  defp optional(opts, key) do
    opts
    |> Keyword.get(key, quote(do: _))
    |> Macro.escape()
  end
end
