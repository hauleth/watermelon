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
```

In your test module:

```elixir
defmodule MyTest do
  use ExUnit.Case
  use Watermelon.Case

  feature_file "coffee.feature"

  setup do
    %{my_starting: :state, user: %User{}}
  end

  defgiven match(number) when ~r/^there (?:is|are) (\d+) coffee(?:s)? left in the machine$/, context: %{user: user} do
    {:ok, %{machine: Machine.put_coffee(Machine.new, number)}}
  end

  defgiven match(number) when "I have deposited £{int}", context: %{user: user, machine: machine} do
    {:ok, machine: Machine.deposit(machine, user, number)}
  end

  defwhen match when "I press the coffee button" do
    Machine.press_coffee(state.machine) # instead would be some `hound` or `wallaby` dsl
  end

  defthen match when "I should be served a coffee" do
    assert %Coffee{} = Machine.take_drink(state.machine)
  end
end
```

## LICENSE

Mozilla Public License 2.0, see [LICENSE](LICENSE).

[Cabbage]: https://github.com/cabbage-ex/cabbage
[white-bread]: https://github.com/meadsteve/white-bread
