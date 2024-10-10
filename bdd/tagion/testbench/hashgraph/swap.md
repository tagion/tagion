## Feature: Hashgraph Swapping
This test is meant to test that a node can be swapped out at a specific epoch

`tagion.testbench.hashgraph.swap`

### Scenario: node swap

`NodeSwap`

*Given* i have a hashgraph testnetwork with n number of nodes.

`nodes`

*Given* that all nodes knows a node should be swapped.

`swapped`

*When* a node has created a specific amount of epochs, it swaps in the new node.

`node`

*Then* the new node should come in graph.

`graph`

*Then* compare the epochs created from the point of the swap.

`swap`

*Then* stop the network.

`network`


