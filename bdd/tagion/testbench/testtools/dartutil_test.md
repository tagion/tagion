Feature: dartutil scenarios

Scenario: Bullseye
Given initial dart file
When dartutil is called with given input file
Then the bullseye should be as expected
