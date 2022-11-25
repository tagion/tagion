Feature: Collector service.

The collector service is responsible for collecting the inputs and the read-only archive from the DART.

This service should handle the smart-contract validation according to the Smart Contract Consensus rules.
And the services should be able to receive smart contracts from either the Transaction service or from the HashGraph events which should include smart contracts in the payload.

The tests performed in this feature should be performed on a simple transfer contract.

Scenario should create a wallet and bills

Given a number of Wallets

Given a number of bills belonging to the Wallets

When the wallets and the bills have been created

Then check that the bills can be read from the DART


Scenario should create a transfer smart contract

Given a list of transfer contracts with the input bills and signatures

When the contract has been created

Then check that the contract has been correctly formatted.


Scenario handling contract from the Transaction Service.
@transaction

Given one of transfer-contract should be sent to the Collector service

When Collector services receive the contract

When the Collector services should collect the inputs from the DART

Then when the Collector services collected the input the smart contract should be check
according to the Smart Contract Consensus

Then the inputs should be added to a list in the collector services.

Then if the contract complies with the consensus rules the contract should be sent to the HashGraph.

But if all the input was not available in the DART the test should fail.


Scenario handling contracts received from the HashGraph payload.
@hashgraph

Given one of transfer contracts should be sent to the Collector service

When Collector services receive the contract

When the Collector services should collect the inputs  from the DART

Then when the Collector services collected the input the smart contract should be check
according to the Smart Contract Consensus

Then the inputs should be added to a list in the collector services.

Then if the contract complies with the consensus rules the contract should be sent to the HashGraph.
Note. In this case, the smart contract should not be sent back to the HashGraph.

But if all the input was not available in the DART the test should fail.


Scenario the contract handling should be repeated 

Given a number of contracts, the contracts should be selected for scenario @transaction or @hashgraph

Then this test parses if all the scenario @transaction and @hashgraph has passed


Scenario the Transcript services should request inputs from the Collector services
@transcript

Given a selected list of smart-contracts the fingerprints of those inputs should be listed

Given the list of fingerprints is sent to the Collector services.

Then the collector services receive the list of fingerprints the collector services should collect all the inputs in the list and send it back to the Transcript services. 
If some of the fingerprints in not available those inputs should not be added to the list send back to the Transcript services.
The Collector services should remove all the inputs sent back from the collector list.


Scenario The Collector services should remove used inputs

Given a list of fingerprints that are stored in the DART perform @transcript on this list

When the @transcript has been performed the check that all the inputs have been collected

Then perform the same @transcript again and check that the input list received by the transcript services is empty.


Scenario The Collector services should partly collect inputs

Given a list L of fingerprints where the inputs are available in the DART.

Given a part of the list L call M the scenario @transaction should be performed.

When all the input in list M should be received by the Transcript services.

Then @transcript should be performed on L and the inputs should on includes the inputs of L which excludes the inputs in list M.



