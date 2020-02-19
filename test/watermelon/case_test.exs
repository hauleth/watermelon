defmodule Watermelon.CaseTest do
  use ExUnit.Case, async: true
  use Watermelon.Case

  defmodule Foo do
    use Watermelon.DSL

    defgiven match(name, description) when "submission named {string} described as {string}" do
      assert "Foo about bar" == name
      assert "Foo bar baz quux" == description

      :ok
    end

    defgiven match when "submissions:", context: %{table_data: data} do
      assert %{name: "Foo about bar", description: "Foo bar baz quux"} in data

      :ok
    end

    defgiven match(channel) when "subscribing to {string}" do
      assert "submissions" == channel
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

  feature("""
  Feature: Test
    Scenario: Test
      Given submission named "Foo about bar" described as "Foo bar baz quux"
      And subscribing to "submissions"
      When create submission
      Then there is event
  """)
end
