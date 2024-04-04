Feature: TRT contract scenarios

Scenario: Proper contract
Given a network
Given a correctly signed contract
When the contract is sent to the network
When the contract goes through
Then the contract should be saved in the TRT 

Scenario: Invalid contract
Given a network
Given one correctly signed contract
Given another malformed contract correctly signed with two inputs which are the same
When contracts are sent to the network 
Then one contract goes through and another should be rejected
Then one contract should be stored in TRT and anohter should not 