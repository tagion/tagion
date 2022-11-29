## Feature: Collector service.

The collector service is responsible for collecting the inputs and the read-only archive from the DART.

This service should handle the smart-contract validation according to the Smart Contract Consensus rules.
And the services should be able to receive smart contracts from either the Transaction service or from the HashGraph events which should include smart contracts in the payload.

The tests performed in this feature should be performed on a simple transfer contract.

`tagion.testbench.services.Collector_service`

### Scenario: should create a wallet and bills
`ShouldCreateAWalletAndBills`

*Given* a number of Wallets

`ofWallets`

*Given* a number of bills belonging to the Wallets

`theWallets`

*When* the wallets and the bills have been created

`beenCreated`

*Then* check that the bills can be read from the DART

`theDART`


### Scenario: should create a transfer smart contract
`ShouldCreateATransferSmartContract`

*Given* a list of transfer contracts with the input bills and signatures

`signatures`

*When* the contract has been created

`created`

*Then* check that the contract has been correctly formatted.

`formatted`


### Scenario: handling contract from the Transaction Service.
@transaction

`HandlingContractFromTheTransactionService`

*Given* one of transfer-contract should be sent to the Collector service
<!-- given transfer-contract is sent to the collector service -->
`service`

*When* Collector services receive the contract

`contract`

*When* the Collector services should collect the inputs from the DART

`dART`

<!-- remove when -->
*Then* when the Collector services collected the input the smart contract should be check
according to the Smart Contract Consensus

`checkConsensus`

*Then* the inputs should be added to a list in the collector services.

`services`
<!-- consensus rules? -->
*Then* if the contract complies with the consensus rules the contract should be sent to the HashGraph.

`hashGraph`

*But* if all the input was not available in the DART the test should fail.


`fail`


### Scenario: handling contracts received from the HashGraph payload.
@hashgraph

`HandlingContractsReceivedFromTheHashGraphPayload`

*Given* one of transfer contracts should be sent to the Collector service

`service`

*When* Collector services receive the contract

`contract`

*When* the Collector services should collect the inputs  from the DART

`dART`
<!-- remove when -->
*Then* when the Collector services collected the input the smart contract should be check
according to the Smart Contract Consensus

`checkConsensus`

*Then* the inputs should be added to a list in the collector services.

`services`
<!-- if it is after payload from hashgraph why send the payload back to the hashgraph -->
*Then* if the contract complies with the consensus rules the contract should be sent to the HashGraph.
Note. In this case, the smart contract should not be sent back to the HashGraph.

`hashGraph`

*But* if all the input was not available in the DART the test should fail.


`fail`


### Scenario: the contract handling should be repeated
`TheContractHandlingShouldBeRepeated`
<!-- add another scenario called @transaction -->
*Given* a number of contracts, the contracts should be selected for scenario @transaction or @hashgraph

`hashgraph`

*Then* this test parses if all the scenario @transaction and @hashgraph has passed

`passed`


### Scenario: the Transcript services should request inputs from the Collector services
@transcript

`TheTranscriptServicesShouldRequestInputsFromTheCollectorServices`
<!-- hash instead of fingerprint -->
*Given* a selected list of smart-contracts the fingerprints of those inputs should be listed

`beListed`

*Given* the list of fingerprints is sent to the Collector services.

`collectorServices`

*Then* the collector services receive the list of fingerprints the collector services should collect all the inputs in the list and send it back to the Transcript services.
If some of the fingerprints are not available those inputs should not be added to the list that is sent back to the Transcript services.
The Collector services should remove all the inputs sent back from the collector list.
<!-- removed from where -->
<!-- is it not better to mark that you have non valid inputs? -->

`transcriptServices`


### Scenario: The Collector services should remove used inputs
`TheCollectorServicesShouldRemoveUsedInputs`

*Given* a list of fingerprints that are stored in the DART perform @transcript on this list

`list`

*When* the @transcript has been performed 

`performed`

*Then* check that all the inputs have been collected

`collected`

*Then* perform the same @transcript again and check that the input list received by the transcript services is empty.

`empty`


### Scenario: The Collector services should partly collect inputs
`TheCollectorServicesShouldPartlyCollectInputs`

*Given* a list L of fingerprints where the inputs are available in the DART.

`dART`

*Given* a part of the list L called M the scenario @transaction should be performed.

`performed`

*When* all the inputs in list M are received by the Transcript services.

`services`

*Then* @transcript should be performed on L and the inputs should include the inputs of L which excludes the inputs in list M.

`listM`


