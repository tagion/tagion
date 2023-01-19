Feature: Check for received epoch
Scenario: received_epoch
Given a network.
When i continously check if the node log contains received epoch
Then the pattern should be found
