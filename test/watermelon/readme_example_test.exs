defmodule Watermelon.ReadmeExampleTest do
  use ExUnit.Case, async: true
  use Watermelon.Case

  defmodule Machine do
    defstruct coffee: 0, deposit: 0

    def new, do: %__MODULE__{}

    def put_coffee(machine, number), do: %{machine | coffee: number}

    def deposit(machine, _, deposit), do: %{machine | deposit: deposit}

    def press_coffee(_), do: :ok

    def take_drink(%{coffee: count, deposit: deposit}) when count > 0 and deposit > 0 do
      :coffee
    end
  end

  feature_file("coffee.feature")

  defgiven match(number) when "there are {int} coffee(s) left in the machine" do
    {:ok, %{machine: Machine.put_coffee(Machine.new(), number)}}
  end

  defgiven match(number) when "I have deposited £{int}", context: %{machine: machine} do
    {:ok, %{machine: Machine.deposit(machine, nil, number)}}
  end

  defwhen match when "I press the coffee button", context: state do
    Machine.press_coffee(state.machine)
  end

  defthen match when "I should be served a coffee", context: state do
    assert :coffee == Machine.take_drink(state.machine)
  end
end
