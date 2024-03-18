Feature: Check network stability when runninng many epochs
Scenario: Run passive fast network
Given i have a running network
When the nodes creates epochs
Then the epochs should be the same
