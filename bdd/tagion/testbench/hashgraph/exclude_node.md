Feature Hashgraph exclude node
This test is meant to test if a node completely stops communicating.
Scenario static exclusion of a node
Given i have a hashgraph testnetwork with n number of nodes
when all nodes have created at least one epoch
When i mark one node statically as non-voting and disable communication for him
Then the network should still reach consensus
then stop the network
