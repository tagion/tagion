Feature: God Contract for the test network. 

This enables to change modify the DART in testnetwork.

The network need to be build with the version=GOD_CONTRACT


Scenario: Request network running in test-mode

Given that a test network is running.

When send a god-contract to add archives to the DART.

Then wait until the a network process a number of epochs

Then send a dartRead to check if the archives exists


Scenario: Remove one or more of the archives add to the DART

Given that the archives in the previous Scenario has been added.

When send a god-contract to remove one or more archives.

Then wait until the network has process a number of epochs.

Then send a checkRead to check that the archives has been removed. 


