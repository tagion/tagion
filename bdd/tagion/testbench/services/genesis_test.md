Feature: Boot system with genesis block.

Scenario: network running with genesis block and epoch chain.
Given i have a network booted with a genesis block
when the network continues to run.
then it should continue adding blocks to the _epochchain
then check the chains validity.

Scenario: create a transaction
given i have a payment request
when i pay the transaction
then the networks tagion globals amount should be updated.

