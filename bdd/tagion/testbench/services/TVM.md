## Feature: Tagion Virtual Machine services
This feature handles the execution of the smart contracts.
The purpose of this service is to execute the contract with the input and the readonly archives received.

`tagion.testbench.services.TVM`

### Scenario: should execute the contract.

`ShouldExecuteTheContract`

*Given* a contract with inputs and readonly archives.

`inputsAndReadonlyArchives`

*When* the format and the method of the contract has been checked.

`contractHasBeenCheck`

*Then* the contract is executed and the result should be send to the transcript service.

`sendToTheTranscript`

*But* if the contract fails it should be reported to the transcript service.

`reportedToTheTranscript`


