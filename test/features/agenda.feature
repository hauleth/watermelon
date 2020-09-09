@baz
Feature: Agenda
    Submissions are the single proposals for placing into the Agenda.

  Background: Assume the user is authenticated for all scenarios
    Given the user is authenticated

    @foo
    @bar
    Scenario: Add new submission to agenda
        Given submissions:
          | name          | description      |
          | Foo about bar | Foo bar baz quux |
        When create submission
        Then it is listed in all submissions

    Scenario: Add new submission and listen on events
        Given submission named "Foo about bar" described as "Foo bar baz quux"
        And subscribing to "submissions"
        When create submission
        Then there is event

  Scenario: Logout makes user not authenticated
    When the user logs out
    Then the user is not authenticated
