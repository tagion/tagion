## Feature: Transcript service
This service takes care of processing the consensus-ordered list of smart-contracts (here in called an epoch list).
The service should check the smart-contracts in-order and check that the inputs has not been used.
The collected result should as a modifications updates to the DART-Service.

`tagion.testbench.services.transaction`

### Scenario: Process an epoch-list with all valid epochs

`ProcessAnEpochlistWithAllValidEpochs`

*Given* a list of contract where all the contracts has been executed bye the TVM-service.

`tVMservice`

*Given* a list of valid contract in an epoch-list.

`epochlist`

*When* the epoch-list and the list of contract is available.

`available`

*Then* the Recorder received to DART-Services should be checked that it contains the correct modifications.

`modifications`


### Scenario: Process an epoch-list where the inputs are reused
This scenario checks for double spending when the same input is available for several smart-contracts in only the first in the process should be executed.
And all the smart contracts which use the same input should be given processed but the penalty process.

`ProcessAnEpochlistWhereTheInputsAreReused`

*Given* a list of valid inputs collected in the TVM service.

`service`

*Given* an epoch-list where some of the inputs are used multiple time.

`time`

*When* the epoch-list and the list of contract is available.

`available`

*When* the transcript services have been executed the smart-contracts the Recorder produces should be sent to the DART-Services

`dARTServices`

*Then* the Recorder received to DART-Services should be checked that it contains the correct modifications.

`modifications`

*Then* the Recorder received should be checked that it contains the correct modifications and check that the penalty has been performed on the inputs which are used in multiple contracts.

`contracts`


