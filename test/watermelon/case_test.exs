defmodule Watermelon.CaseTest do
  use ExUnit.Case
  use Watermelon.Case

  defmodule Foo do
    use Watermelon.DSL

    defgiven ~r/submission named/ do
      :ok
    end

    defgiven ~r/subscribing/ do
      :ok
    end

    defwhen ~r/create submission/ do
      :ok
    end

    defthen ~r/is listed/ do
      :ok
    end

    defthen ~r/there is event/ do
      :ok
    end
  end

  @step_modules [Foo]

  feature_file "agenda.feature"
end
