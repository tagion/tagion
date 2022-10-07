Feature Transaction service
The transaction service act as the gate-keep for smart contracts before it is send to the network. 
The transaction service should be able to receive HiRPC which checked before it send to and send to the coordinator (HashGragh).
A data-package is defined as a string of bytes which a send to the transaction service.


Scenario A data package which exceed the maximum size.
Given a data package with larger than the maximum size.

Given that a connection to the logs on the transaction service     

Given the data package is send to the selected active node A in the network.


Scenario A malformed data packed should be rejected
Given a data 

