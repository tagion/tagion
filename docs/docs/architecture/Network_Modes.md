---
sidebar_position: 2
---

# Network Modes

This document describes the different modes for the Tagion-network.

## Mode 0
This mode emulates the network via *inter-process communication* and runs as a single program where each node is spawned as different threads.

The network also runs with fixed number of nodes.
This mode allows for easy debugging since all logs and the startup are very easily created.

# Mode 1
This mode uses NNG sockets for creating a simple gossip protocol. The address of the nodes is loaded from the dart and the number of nodes are still fixed. The nodes are spawned as *seperate* programs and one node can go down (ex. segfault) without the entire network chrashing.

# Mode 2
This mode runs like Mode 1, but where mode1 does not allow for *catch-up* if a node goes down and wants to join again mode 2 does. This means that a node is able to subscribe to the recorder as well as synchronize the database simultaneosly in the end being able to join theg graph again.

# Mode 3
This mode run as mode 1 but with node swapping this means it will swap in and out the active nodes from the list of know nodes stored in th DART database.

# Mode 4
This mode can run multiple networks like mode 3. Those networks are know as sub-DART's or hyper-networks.





