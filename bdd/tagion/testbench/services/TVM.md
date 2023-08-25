## Feature: Tagion Virtual Machine services
This feature handles the execution of the smart contracts.
The purpose of this services is to execute the contract with the input and the readonly archives received.

`tagion.testbench.services.TVM`

### Scenario: should execute the contract.

`ShouldExecuteTheContract`

*Given* a contract with inputs and readonly archives.

`inputsAndReadonlyArchives`

*When* the format and the method of the contract has been check.

`contractHasBeenCheck`

*Then* the contract is execute and the result should be send to the transcript.

`sendToTheTranscript`

*But* if contract fails the fails should be reported to the transcript.

`reportedToTheTranscript`


