## Feature: ContractInterface service.

The transaction service should be able to receive HiRPC, validate data format and protocol rules before it sends to and send to the Collector services.
The HiRPC is package into a HiBON-Document in the following called doc.

`tagion.testbench.services.contract`


### Scenario: The Document is not a HiRPC

`TheDocumentIsNotAHiRPC`

*Given* a doc with a correct document format but which is incorrect HiRPC format.

`format`

*When* the doc should be received by the this services.

`services`

*Then* the doc should be checked that it is a correct HiRPC and if it is not it should be rejected.

`rejected`

*But* the doc should not be sent to the Collector Service

`collectorService`


### Scenario: Correct HiRPC format and permission.
The #permission scenario can be executed with and without correct permission.

`CorrectHiRPCFormatAndPermission`

*Given* a correctly formatted transaction.

`transaction`

*When* the doc package has been verified that it is correct Document.

`document`

*When* the doc package has been verified that it is correct HiRPC.

`hiRPC`

*Then* the method of HiRPC should be checked that it is 'submit'.

`submit`

*Then* the parameter for the send to the Collector service.
The parameter for the 'submit' method contains the contract.

`service`

*Then* if check that the Collector services received the contract.

`contract`


### Scenario: Correct HiRPC with permission denied.

`CorrectHiRPCWithPermissionDenied`

*Given* a HiPRC with incorrect permission

`incorrectPermission`

*When* do scenario '#permission'

`scenarioPermission`

*Then* check that the contract is not send to the Collector.

`theCollector`


