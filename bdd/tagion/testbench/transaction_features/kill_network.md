Feature: Kill the network.

Scenario: Kill the network with PIDS.

Given a network with pid_files of the processes.

When i send two kill commands. 

Then check if the network has been stopped.

