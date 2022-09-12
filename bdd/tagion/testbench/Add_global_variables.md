Feature: Add and define global variables

The global variables is a Document which is stored as a chain in the DART.

A user must be able to accessible the "#tagion" Name Recored from the transaction service which should contains a contains the global parameter.



Scenario: Request the global from the network.

Given that a HiRPC is created to read the "#tagion" record

When the HiPRC is send to the network.

Then the  "#tagion" Name Record is return to the user.



