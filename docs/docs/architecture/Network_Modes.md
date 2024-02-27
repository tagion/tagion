---
sidebar_position: 2
---

# Network Modes

This document describes the different modes for the Tagion-network.

Mode 0:

This mode emulated the network via inter-process communication and run as a single program.

The network runs with fix number of nodes.

This mode make it easier to debug functions which are not related to the libp2p communications.

Mode 1:

This mode uses libp2p gossip protocol. The address of the nodes is loaded from a file and the number of nodes are fixed.

Mode 2:

This mode loads the network node address from the Name-Records store in the DART data-base and it also run a fixed number of nodes like mode 0 and mode 1

Mode 3:

This mode run as mode 2 but with node swapping this means it will swap in and out the active nodes from the list of know nodes stored in th DART data-base.

Mode 4:

This mode also includes the over all governance rules including the function in mode .

This is the "Real" main network.

Mode 5:

This mode can run multiple networks like mode 3. Those networks are know as sub-DART's or hyper-networks.





