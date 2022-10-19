Feature: Implementing  Name Records.

The name record is a unique "#<name>" in the DART.



Scenario: Create a none-existing name record.

Given the user have created a keypair.

Given the user has selected a name A.

Given the user creates a smart contract to request to create a name record A.

When the user send the contract has been send to the network.

When the network has process epoch.

Then the epoch should contain the completed contract for the name A.



Scenario: Request the name record of for name A.

Given the user sends requests of '#<name>'

When network receives a

