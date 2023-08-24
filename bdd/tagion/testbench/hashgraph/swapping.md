Feature Hashgraph Swapping
This test is meant to test that a node can be swapped out at a specific epoch

Scenario node swap
Given i have a hashgraph testnetwork with n number of nodes.
Given that all nodes knows when a node should be swapped.
When a node has created a specific amount of epochs, it swaps in the new node.
Then the new node should come in graph.
Then compare the epochs created from the point of the swap.
Then stop the network.

