## Feature: Transaction service.
<!-- Write the current functionality and the future state.  -->

The transaction service should act as a gate-keeper to validate smart-contract before they are send to the network.
The transaction service should be able to receive HiRPC which is checked before it sends to and send to the Collector services.
A data-package is defined as a string of bytes that a send to the transaction service.

`tagion.testbench.services.Transaction_service`

### Scenario: a data package that exceeds the maximum size.

`ADataPackageThatExceedsTheMaximumSize`

*Given* a data package with a size larger than the maximum.

`thanTheMaximum`

*Given* that a connection to the logs on the transaction service.

`theTransactionService`
*Given* the data package is sent to the selected active node A in the network.

`inTheNetwork`
<!-- what do you mean... Do you mean node A or to the network with a data package that doesent comply with rules -->
*When* the data package has been received by the network.

`byTheNetwork`

*Then* the size of the data package should be checked and they should be rejected,
if the size is larger than the maximum size.

`shouldBeRejected`

*But* the data package should not be sent to the Collector Service

`theCollectorService`


### Scenario: a malformed data packed should be rejected
<!-- is it a node receiving the package or the network again.. -->
`AMalformedDataPackedShouldBeRejected`

*Given* a data package is not a correctly HiRPC format.

`format`
<!-- can we use format here. Wont it collide with other function? -->
*When* the data package has been received by the network.

`network`

*Then* network should check if the data package is a valid HiRPC
and if the package is invalid then the should be rejected.

`hiRPC`
<!-- this should be a then because it is the same negative -->
*But* the data package should not be sent to the Collector Service

`service`


### Scenario: a data package that is not a HiRPC

`ADataPackageThatIsNotAHiRPC`
<!-- same here -->
*Given* a data package that is not a correct HiRPC.

`hiRPC`

*When* the data package has been received by the network.

`network`

*Then* the package should be checked that it is a correct HiRPC and if it is not it should be rejected.

`rejected`

<!-- Should we also have but here? -->

### Scenario: corrected format HiRPC.

`CorrectedFormatHiRPC`
<!-- use hirpc instead of transaction -->
*Given* a correctly formatted transaction.

`transaction`
<!-- network or node -->
*When* the data package has been received by the network.

`network`

*When* the data package has been verified that it is correct HiRPC.

`hiRPC`

*Then* the HiRPC is sent to the Collector services.

`services`

*Then* check that the Collector services received the package.

`checkPackage`

<!-- Extra scenarios -->
<!-- check signature on hiripc -->
<!-- check signature on bills -->
<!-- negative amount, zero amount and fee -->
<!-- check hashes -->