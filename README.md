# Watermelon

Super simple Gherkin features to ExUnit tests translator.

Inspired by [Cabbage][], but with slightly different API and few ideas of my own
to simplify working with the library.

## Installation

The package can be installed by adding `watermelon` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:watermelon, "~> 0.1.0", only: [:test]}
  ]
end
```

The docs can be found at [https://hexdocs.pm/watermelon](https://hexdocs.pm/watermelon).

## Usage

Define file `tests/feature/coffe.feature`:

```gherkin
Feature: Serve coffee
  Coffee should not be served until paid for
  Coffee should not be served until the button has been pressed
  If there is no coffee left then money should be refunded

  Scenario: Buy last coffee
    Given there are 1 coffees left in the machine
    And I have deposited £1
    When I press the coffee button
    Then I should be served a coffee
  Scenario Outline: Coffee count
    Given there are <start> coffees left in the machine
    And I have deposited £<money>
    When I press the coffee button <orders> times
    Then I should have <left> coffees

    Examples:
      | start | money | orders | left |
      |    12 |     5 |      5 |    7 |
      |    20 |     5 |      5 |   15 |
```

In your test module:

```elixir
defmodule MyTest do
  use ExUnit.Case
  use Watermelon.Case

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
```

## LICENSE

Mozilla Public License 2.0, see [LICENSE](LICENSE).

[Cabbage]: https://github.com/cabbage-ex/cabbage
[white-bread]: https://github.com/meadsteve/white-bread
