# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Watermelon.Case do
  @moduledoc """
  Helpers for generating feature test modules.

  This module needs to be used within your `ExUnit.Case` module to provide
  functionalities needed for building feature tests within your regular `ExUnit`
  tests.

  For documentation about defining steps, check out `Watermelon.DSL`.

  ## Example

  ```elixir
  defmodule MyApp.FeatureTest do
    use ExUnit.Case, async: true
    use #{inspect(__MODULE__)}

    feature \"\"\"
    Feature: Example
      Scenario: simple test
        Given empty stack
        And pushed 1
        And pushed 2
        When execute sum function
        Then have 3 on top of stack
    \"\"\"

    defgiven match when "empty stack", do: {:ok, stack: []}

    defgiven match(val) when "pushed {num}", context: %{stack: stack} do
      {:ok, stack: [val | stack]}
    end

    defwhen match when "execute sum function", context: ctx do
      assert [a, b | rest] = ctx.stack

      {:ok, stack: [a + b | rest]}
    end

    defthen match(result) when "have {num} on top of stack", context: ctx do
      assert [^result | _] = ctx.stack
    end
  end
  ```

  Which is rough equivalent of:

  ```elixir
  defmodule MyApp.FeatureTest do
    use ExUnit.Case, async: true

    test "simple test" do
      stack = [1, 2]
      assert [a, b | _] = stack
      assert 3 == a + b
    end
  end
  ```

  ## Importing steps from different modules

  In time amount of steps can grow and grow, and a lot of them will repeat between
  different tests, so for your convenience `#{inspect(__MODULE__)}` provide a way for
  importing steps definitions from other modules via setting `@step_modules` module
  attribute. For example to split above steps we can use:

  ```elixir
  defmodule MyApp.FeatureTest do
    use ExUnit.Case, async: true
    use #{inspect(__MODULE__)}

    @step_modules [
      MyApp.StackSteps
    ]

    feature_file "stack.feature"
  end
  ```

  ## Setup and teardown

  Nothing special there, just use old `ExUnit.Callbacks.setup/2`
  or `ExUnit.Callbacks.setup_all/2` like in any other of Your test modules.
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Watermelon.DSL

      import unquote(__MODULE__), only: [feature: 1, feature_file: 1]

      @feature_defined false
      @step_modules []
    end
  end

  @doc """
  Define inline feature description.

  It accepts inline feature description declaration.

  ## Example

  ```elixir
  defmodule ExampleTest do
    use ExUnit.Case
    use #{inspect(__MODULE__)}

    feature \"\"\"
    Feature: Inline feature
      Scenario: Example
        Given foo
        When bar
        Then baz
    \"\"\"

    # Steps definitions
  end
  ```
  """
  defmacro feature(string) do
    feature = Gherkin.parse(string)

    generate_feature_test(feature)
  end

  @doc """
  Load file from features directory.

  Default features directory is set to `test/features`, however you can change
  it by setting `config :watermelon, features_path: "my_features_dir/"` in your
  configuration file.

  ## Example

  ```elixir
  defmodule ExampleTest do
    use ExUnit.Case
    use #{inspect(__MODULE__)}

    feature_file "my_feature.feature"

    # Steps definitions
  end
  ```
  """
  defmacro feature_file(filename) do
    root = Application.get_env(:watermelon, :features_path, "test/features")
    path = Path.expand(filename, root)
    feature = Gherkin.parse_file(path)

    Module.put_attribute(__CALLER__.module, :external_attribute, filename)

    generate_feature_test(feature)
  end

  defp generate_feature_test(feature) do
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

      for %Gherkin.Elements.Scenario{name: scenario_name, steps: steps, tags: tags} <-
            feature.scenarios do
        name =
          ExUnit.Case.register_test(
            __ENV__,
            :scenario,
            "#{feature.name} - #{scenario_name}",
            tags
          )

        def unquote(name)(context) do
          Watermelon.Case.run_steps(
            unquote(Macro.escape(steps)),
            context,
            unquote(step_modules)
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
      |> Enum.find_value(:error, &step(&1, text, context))
      |> case do
        {_, {:ok, context}} -> context
        {_, other} -> raise "Unexpected return value `#{inspect(other)}` in step `#{text}`"
        :error -> raise "Definition for `#{text}` not found"
      end
    end)
  end

  defp step(module, text, context) do
    case module.apply_step(text, context) do
      {:ok, _} = return -> return
      :error -> false
    end
  end
end
