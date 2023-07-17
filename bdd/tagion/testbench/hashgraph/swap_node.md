Feature Hashgraph swap node
This test is meant to test when a node has completely stopped communicating. That we can set it to null and add a new node in its position
Scenario Offline node swap
Given i have a hashgraph testnetwork with n number of nodes
when all nodes have created at least one epoch
when i disable all communication for one node.
when the node is marked as offline 
then the node should be deleted from the nodes.
then a new node should take its place.
then the new node should come in graph.
then compare the epochs the node creates from the point of swap.
then stop the network.
