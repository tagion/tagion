Feature: Check hashgraph stability when runninng many epochs
Scenario: Run passive fast hashgraph
Given i have a running hashgraph
When the nodes creates epochs
Then the epochs should be the same
