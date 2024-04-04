Feature: TRT contract scenarios

Scenario: Proper contract
Given a network
Given a correctly signed contract
When the contract is sent to the network
When the contract goes through
Then the contract should be saved in the TRT 

Scenario: Invalid contract
Given a network
Given a incorrect contract which fails in the Transcript
When the contract is sent to the network 
Then it should be rejected
Then the contract should not be stored in the TRT