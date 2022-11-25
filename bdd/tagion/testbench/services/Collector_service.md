Feature: Collector service.

The collector service is responsible for collecting the inputs and the read only archive from the DART.

This services should handle the smart-contract validation according to the Smart Contract Consensus rules.
And the services should be able to receive smart-contracts from either the Transaction service or the from the HashGraph events which should include smart-contracts in the payload.

The tests performed in this feature should performed on a simple transfer contract.

Scenario should create wallet and bills

Given a number of Wallets

Given a number of bills belonging to the Wallets

When the wallets and the bills has been created

Then check that the bills can be read from the DART


Scenario should create transfer smart contract

Given a list of transfer contracts with the input bills and signatures

When the contract has been created

Then check that the contract has the correct format.


Scenario handling contract from the Transaction service.
@transaction

Given one of transfer contract should be send to the Collector service

When the Collector services receives the contract

When the Collector services should collect the inputs from the from the DART

Then when the Collector services collected the input the smart contract should be check
according to the Smart Contract Consensus

Then the inputs should be added to an list in the collector services.

Then if the contract complies with the consensus rules the contract should be send to the HashGraph.

But if the all the input was not available in the DART the test should fail.


Scenario handling contracts received from the HashGraph payload.
@hashgraph

Given one of transfer contract should be send to the Collector service

When the Collector services receives the contract

When the Collector services should collect the inputs from the from the DART

Then when the Collector services collected the input the smart contract should be check
according to the Smart Contract Consensus

Then the inputs should be added to an list in the collector services.

Then if the contract complies with the consensus rules the contract should be send to the HashGraph.
Note in this case the smart contract should not be send back to the HashGraph.

But if the all the input was not available in the DART the test should fail.


Scenario the contract handling should be repeated 

Given a number of contracts the contracts should be selected for scenario @transaction or @hashgraph

Then this test parses if all the scenario @transaction and @hashgraph has passed


Scenario the Transcript services should request inputs from the Collector services
@transcript

Given a selected list of smart contracts the fingerprints of those inputs should be listed

Given the list of fingerprints is send to the Collector services.

Then the collector services receives the list fingerprints the collector services should collect all the inputs in the list and send it back to the Transcript services. 
If the some of the fingerprints in not available those input should not be added to the list send back to the Transcript services.
The Collector services should remove all the inputs send back from the collector list.


Scenario The Collector services should remove used inputs

Given a list of fingerprint which are stored in the DART perform @transcript on this list

When the @transcript has been performed the check that all the inputs has been collected

Then perform the same @transcript again and check that the input list received by the transcript services is empty.


Scenario The Collector services should partly collect inputs

Given a list L of fingerprint where the inputs are available in the DART.

Given a part of the list L call M the scenario @transaction should be performed.

When all the input in list M should be received by the Transcript services.

Then @transcript should be perform on L and the inputs should on includes the inputs of L which excludes the inputs in list M.












