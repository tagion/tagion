Feature: hirep scenarios

Scenario: List filtering
Given initial hibon file with several records
When hirep filter specific items in list
Then the output of hirep should be as expected
