Feature: epoch shutdown

Scenario: Stopping all nodes at a specific epoch
Given I have a running network producing epochs
When I send an epoch shutdown signal
Then the network should stop at the specified epoch
