Feature: malformed contracts

Scenario: contract type without correct information
Given i have a malformed signed contract where the type is correct but the fields are wrong.
When i send the contract to the network.
Then the contract should be rejected.

Scenario: inputs are not bills in dart
Given i have a malformed contract where the inputs are another type than bills.
When i send the contract to the network.
Then the contract should be rejected.

Scenario: Negative amount and zero amount on output bills.
Given i have three contracts. One with output that is zero. Another where it is negative. And one with a negative and a valid output.
When i send the contracts to the network.
Then the contracts should be rejected.

Scenario: Contract where input is smaller than output.
Given i have a contract where the input bill is smaller than the output bill.
When i send the contract to the network.
Then the contract should be rejected.

