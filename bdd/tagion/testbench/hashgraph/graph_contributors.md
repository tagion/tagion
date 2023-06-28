Feature Hashgraph contributors
This test is meant to test the ability for a node to get marked as non-voting which should result in the rest of the network continuing to run.
Scenario a non-voting node
Given i have a hashgraph testnetwork with n number of nodes
when all nodes have created at least one epoch
when i mark one node as non-voting
then the network should still reach consensus
then stop the network 
