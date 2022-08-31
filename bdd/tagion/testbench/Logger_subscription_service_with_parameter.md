Feature: Logger subscription services with parameter.

This feature enables to probe parameters in a node.



Scenario: The logger request a list of valid parameters.

Given the logger creates a HiRPC to request a parameter from a task.

When the logger send the HiPRC to the network.

Then the logger receives a list of all valid parameters.



Scenario: The logger request a parameter.

Given the logger creates a HiRPC for to get parameter from a task.

When the logger sends the HiRPC to the network.

Then the logger receives value of the parameter as HiPRC response.







