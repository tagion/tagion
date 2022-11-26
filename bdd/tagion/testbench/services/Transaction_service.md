Feature Transaction service.

The transaction service act as the gate-keep for smart contracts before it is sent to the network. 
The transaction service should be able to receive HiRPC which is checked before it sends to and send to the Collector services.
A data-package is defined as a string of bytes that a send to the transaction service.


Scenario a data package that exceeds the maximum size.

Given a data package with a size larger than the maximum.

Given that a connection to the logs on the transaction service.

Given the data package is sent to the selected active node A in the network.

When the data package has been received by the network.

Then the size of the data package should be checked and they should be rejected,
if the size is larger than the maximum size.

But the data package should not be sent to the Collector Service



Scenario a malformed data packed should be rejected

Given a data package is not a correctly HiRPC format.

When the data package has been received by the network.

Then network should check if the data package is a valid HiRPC
and if the package is invalid then the should be rejected.

But the data package should not be sent to the Collector Service


Scenario a data package that is not a HiRPC

Given a data package that is not a correct HiRPC.

When the data package has been received by the network.

Then the package should be checked that it is a correct HiRPC and if it is not it should be rejected.


Scenario corrected format HiRPC.

Given a correctly formatted transaction.

When the data package has been received by the network.

When the data package has been verified that it is correct HiRPC.

Then the HiRPC is sent to the Collector services.

Then check that the Collector services received the package.

