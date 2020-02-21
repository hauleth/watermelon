defmodule Watermelon.ReadmeExampleTest do
  use ExUnit.Case, async: true
  use Watermelon.Case

  defmodule Machine do
    defstruct coffees: 0, deposit: 0, ready: false

    def new, do: %__MODULE__{}

    def put_coffee(machine, number), do: %{machine | coffees: number}

    def deposit(machine, _, deposit), do: %{machine | deposit: deposit}

    def press_coffee(%{coffees: count, deposit: deposit})
        when count > 0 and deposit > 0 do
      {:ok, %__MODULE__{coffees: count - 1, deposit: deposit - 1, ready: true}}
    end

    def press_coffee(machine) do
      {:error, machine}
    end

    def take_drink(%__MODULE__{ready: true} = machine) do
      {:coffee, %{machine | ready: false}}
    end
  end

  feature_file("coffee.feature")

  defgiven match(number) when "there are {int} coffee(s) left in the machine" do
    {:ok, %{machine: Machine.put_coffee(Machine.new(), number)}}
  end

  defgiven match(number) when "I have deposited £{int}", context: %{machine: machine} do
    {:ok, %{machine: Machine.deposit(machine, nil, number)}}
  end

  defwhen match when "I press the coffee button", context: %{machine: machine} do
    assert {:ok, machine} = Machine.press_coffee(machine)
    {:ok, machine: machine}
  end

  defwhen match(n) when "I press the coffee button {int} times", context: %{machine: machine} do
    machine =
      for _ <- 1..n, reduce: machine do
        machine ->
          assert {:ok, machine} = Machine.press_coffee(machine)

          machine
      end

    {:ok, machine: machine}
  end

  defthen match when "I should be served a coffee", context: state do
    assert {:coffee, _} = Machine.take_drink(state.machine)

    :ok
  end

  defthen match(num) when "I should have {int} coffee(s)", context: %{machine: machine} do
    assert machine.coffees == num

    :ok
  end
end
