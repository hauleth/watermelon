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
