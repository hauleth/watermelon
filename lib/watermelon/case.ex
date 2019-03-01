defmodule Watermelon.Case do
  defmacro __using__(_opts) do
    quote do
      use Watermelon.DSL

      import unquote(__MODULE__), only: [feature_file: 1]

      @feature_defined false
      @step_modules []
    end
  end

  defmacro feature(string) do
    feature = Gherkin.parse(string)

    generate_feature_test(__CALLER__.module, feature)
  end

  @doc """
  """
  defmacro feature_file(filename) do
    root = Application.get_env(:watermelon, :features_path, "test/features")
    path = Path.expand(filename, root)
    feature = Gherkin.parse_file(path)

    Module.put_attribute(__CALLER__.module, :external_attribute, filename)

    generate_feature_test(__CALLER__.module, feature)
  end

  defp generate_feature_test(module, feature) do
    if Module.get_attribute(module, :feature_defined) do
      raise "You can define only one feature per module"
    else
      Module.put_attribute(module, :feature_defined, true)
    end

    quote location: :keep, bind_quoted: [feature: Macro.escape(feature)] do
      step_modules =
        cond do
          is_list(@step_modules) -> [__MODULE__ | @step_modules]
          is_nil(@step_modules) -> [__MODULE__]
          true -> raise "@step_modules, if set, must be list"
        end

      @moduletag Enum.map(feature.tags, &{&1, true})

      setup context do
        Watermelon.Case.run_steps(
          unquote(feature.background_steps),
          context,
          unquote(step_modules)
        )
      end

      for %Gherkin.Elements.Scenario{name: scenario_name, steps: steps, tags: tags} <- feature.scenarios do
        name = ExUnit.Case.register_test(__ENV__, :scenario, scenario_name, tags)

        def unquote(name)(context) do
          Watermelon.Case.run_steps(
            unquote(Macro.escape(steps)),
            context, unquote(step_modules)
          )
        end
      end
    end
  end

  @doc false
  def run_steps(steps, context, modules) do
    steps
    |> Enum.reduce(context, fn %{text: text}, context ->
      modules
      |> Enum.reduce_while({false, context}, fn
        _, {true, context} when is_map(context) -> {:halt, {true, context}}
        module, {_, context} when is_map(context) -> {:cont, module.apply_step(text, context)}
        _, {_, context} -> {:halt, {:error, context}}
      end)
      |> case do
        {false, _} -> raise "Definition for `#{text}` not found"
        {_, context} -> context
      end
    end)
  end
end
