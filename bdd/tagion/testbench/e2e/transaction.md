Feature: Send a contract through the shell
Scenario: send a contract with one outputs through the shell
Given i have a running network
Given i have a running shell
When i create a contract with all my bills
When i send the contract
Then the transaction should go through
