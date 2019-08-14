defmodule Watermelon.CaseTest do
  use ExUnit.Case, async: true
  use Watermelon.Case

  defmodule Foo do
    use Watermelon.DSL

    defgiven match(_, _) when "submission named {string} described as {string}" do
      :ok
    end

    defgiven match(_) when "subscribing to {string}" do
      :ok
    end

    defwhen match when "create submission" do
      :ok
    end

    defthen match when "it is listed in all submissions" do
      :ok
    end

    defthen match when "there is event" do
      :ok
    end
  end

  @step_modules [Foo]

  feature_file("agenda.feature")
end
