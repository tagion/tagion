Feature Bootstrap of hashgraph
Scenario Start network with n amount of nodes
Given I have a HashGraph TestNetwork with n number of nodes
When the network has started
When all nodes are sending ripples
When all nodes are coherent
Then wait until the first epoch
Then stop the network
 