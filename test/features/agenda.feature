@baz
Feature: Agenda
    Submissions are the single proposals for placing into the Agenda.

    @foo
    @bar
    Scenario: Add new submission to agenda
        Given submission named "Foo about bar" described as "Foo bar baz quux"
        When create submission
        Then it is listed in all submissions

    Scenario: Add new submission and listen on events
        Given submission named "Foo about bar" described as "Foo bar baz quux"
        And subscribing to "submissions"
        When create submission
        Then there is event
