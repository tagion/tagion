## Feature: Transcript service
This service takes care of processing the consensus-ordered list of smart-contracts (here in called an epoch list).
The service should execute the smart-contracts in-order and sends the modifications updates to the DART-Service.

`tagion.testbench.services.Transcript_service`

### Scenario: Process an epoch-list with all valid epochs

`ProcessAnEpochlistWithAllValidEpochs`

*Given* a list of valid inputs collected in Collector service.

`inCollectorService`

*Given* an epoch-list where all the smart-contracts has been approved by the Collector service.

`theCollectorService`

*When* the epoch-list is available then send the epoch-list to the Transcript services.

`theTranscriptServices`

*When* the transcript services have executed the smart-contracts the Recorder produces should be sent to the DART-Services

`toTheDARTServices`

*Then* the Recorder received to DART-Services should be checked that it contains the correct modifications.

`theCorrectModifications`


### Scenario: Process an epoch-list where the inputs are reused
This scenario checks for double spending when the same input is available for several smart-contracts in only the first in the process should be executed.
And all the smart contracts which use the same input should be given processed but the penalty process.

`ProcessAnEpochlistWhereTheInputsAreReused`

*Given* a list of valid inputs collected in the Collector service.

`service`

*Given* an epoch-list where some of the inputs are used multiple time.

`time`

*When* the epoch-list is available then send the epoch-list to the Transcript services.

`services`

*When* the transcript services have been executed the smart-contracts the Recorder produces should be sent to the DART-Services

`dARTServices`

*Then* the Recorder received by DART-Services should be checked that it contains the correct modifications and check that the penalty has been performed on the inputs which are used in multiple contracts.

`contracts`


