## Feature: Transcript service

This service takes care of processing the consensus-ordered list of smart-contracts (here in called an epoch list).

The service should check the smart-contracts in-order and check that the inputs has not been used.

The collected result should as a modifications updates to the DART-Service.


### Scenario: Process an epoch-list with all valid epochs


*Given* a list of contract where all the contracts has been executed bye the TVM-service.

*Given* a list of valid contract in an epoch-list.

*When* the epoch-list and the list of contract is available.

*Then* the Recorder received to DART-Services should be checked that it contains the correct modifications.



### Scenario: Process an epoch-list where the inputs are reused

This scenario checks for double spending when the same input is available for several smart-contracts in only the first in the process should be executed.

And all the smart contracts which use the same input should be given processed but the penalty process.


*Given* a list of valid inputs collected in the TVM service.


*Given* an epoch-list where some of the inputs are used multiple time.

*When* the epoch-list and the list of contract is available.


*When* the transcript services have been executed the smart-contracts the Recorder produces should be sent to the DART-Services

*Then* the Recorder received to DART-Services should be checked that it contains the correct modifications.

*Then* the Recorder received should be checked that it contains the correct modifications and check that the penalty has been performed on the inputs which are used in multiple contracts.

