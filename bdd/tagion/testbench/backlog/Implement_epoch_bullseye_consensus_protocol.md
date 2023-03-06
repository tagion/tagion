Feature: Implement epoch bullseye consensus protocol.
After an node has produced an epoch, the node must send signed bullseye as an event to the network.

Note. This feature only verifies only checks for the signed bullseyes.


Scenario an node should send a signed bullseye to the epoch.

Given the node has produced an epoch number N. 

When the epoch has signed the bullseye.

Then the epoch should put the signed bullseye into an event and gossip to the network.


Scenario a node should count the votes for the bullseye in the next epoch

Give the next epoch N+1 has been produced.

When the DART recorder for the epoch N+1 has been collected.

Then all the signed bullseye should be verified

Then all valid signed bullseye should be counted


