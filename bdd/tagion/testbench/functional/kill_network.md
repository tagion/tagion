Feature: Kill the network.

Scenario: Kill the network with PIDS.

Given i have a network with pids of the processes.

When i send two kill commands. 

Then check if the network has been stopped.

