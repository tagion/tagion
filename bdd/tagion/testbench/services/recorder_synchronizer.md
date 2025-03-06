Feature RecorderSynchronizer

Scenario a local node with a recorder reads data from a remote node
Given the empty local node
Given the remote node with random data
When the local node subscribes on the remote node 
Then the local node reads data from the remote node