Feature: Logger subscription services.

The logger is defined here as the client which is re-questions the logging data.

The network node is a service that supplies the data to be logged.



Scenario: The logger will be rejected if  due to permission denied

Given the logger has created a keypair to be used for HiRPC.

Given the logger creates a HiRPC and signs it.

When the logger sends HiRPC to the network.

Then the logger receives an HiRPC error back due to permission denied.



Scenario: The logger has pubkey which are valid for the node.

Given the logger creates a HiRPC and signs it.

When the logger sends HiPRC to the network.

Then the network sends HiRPC result back to the logger.



Scenario: The logger request a list of all parameters.

Given the logger creates a HiPRC with a request of getting a list of all task's names in the network.

When the logger send the HiPRC to the network.

Then the logger will receive a list of all logger name.



Scenario: The logger request a logger stream from a specific service.

Given the logger creates a HiRPC which set a logger-mask and a task A.

When the logger send the HiRPC to the network.

Then the logger continues to send requested information as HiRPC results back to the logger.



Scenario: The logger changes the request.

Given the logger creates a HiPRC with a new logger-mask and a task B.

When the logger send the HiPRC to the network.

Then the logger will add the logger information the already requested

information and send it back to continue to send the HiPRC result back to the logger.



Scenario: The logger disables the request of task A.

Given the logger creates a HiPRC which set the logger-mask to no log for task A.

When the logger send the HiPRC to the network

Then the logger will receive information from task B.

But the logger will not receive information from task A



