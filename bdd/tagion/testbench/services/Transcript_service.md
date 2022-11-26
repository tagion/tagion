Feature Transcript service
This service takes care of processing the consensus ordered list of smart-contracts (here in call an epoch list).
The service should execute the smart-contracts in-order and sends the modifications updates to the DART-Service.

Scenario Process an epoch-list with all valid epochs

Given an list of valid inputs collected in Collector service.

Given an epoch-list where all the smart-contracts has been approved by the Collector service.

When the epoch-list is available then send the epoch-list to the Transcript services.

When the transcript services has executed the smart-contracts the Recorder produces should be send to the DART-Services

Then the Recorder received to DART-Services should be check that it contains the correct modifications.


Scenario Process an epoch-list where the inputs are reused
This scenario check for double spend when the same input is available for several smart-contracts in the only the first in the process should be executed.
And the all the smart contracts with which uses the same input should be given processed but the penalty process.

Given an list of valid inputs collected in the Collector service.

Given an epoch-list where some of the inputs is used multiple time.

When the epoch-list is available then send the epoch-list to the Transcript services.

When the transcript services has executed the smart-contracts the Recorder produces should be send to the DART-Services

Then the Recorder received to DART-Services should be check that it contains the correct modifications and check that the penalty has been perform on the inputs with which are used in multiple contracts.






