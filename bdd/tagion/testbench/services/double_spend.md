Feature: double spend scenarios

Scenario: Same inputs spend on one contract
Given i have a malformed contract with two inputs which are the same
When i send the contract to the network
Then the inputs should be deleted from the dart.

Scenario: one contract where some bills are used twice.
Given i have a malformed contract with three inputs where to are the same.
When i send the contract to the network
Then all the inputs should be deleted from the dart.

Scenario: Same contract different nodes.
Given i have a correctly signed contract.
When i send the same contract to two different nodes.
Then the first contract should go through and the second one should be rejected.

Scenario: Same contract in different epochs.
Given i have a correctly signed contract.
When i send the contract to the network in different epochs to the same node.
Then the first contract should go through and the second one should be rejected.

Scenario: Same contract in different epochs different node.
Given i have a correctly signed contract.
When i send the contract to the network in different epochs to different nodes.
Then the first contract should go through and the second one should be rejected.

Scenario: Two contracts same output
Given i have a payment request containing a bill.
When i pay the bill from two different wallets.
Then only one output should be produced.

Scenario: Bill age
Given i pay a contract where the output bills timestamp is newer than epoch_time + constant.
When i send the contract to the network.
Then the contract should be rejected.

Scenario: Amount on output bills
Given i create a contract with outputs bills that are smaller or equal to zero.
When i send the contract to the network.
Then the contract should be rejected.
 


