# Tagionwallet CLI

> 🚧 This document is still in development.

Wallet - this full-fledged network wallet generates invoices and contracts, pays for invoices, updates the user's plan, sends requests to network nodes, etc.

## The modes for the network running

When the node starts, it has to:

- Find other nodes (with their address) in the network.
- Synchronize the database to the actual state.

There are the following modes for the network running:

- **Internal** - It runs as one program, where each node is a separate thread communicating with other ones as between threads simulating a network.
- **Local** - It runs the network on several nodes, but the service searches for nodes only in the local network. It will not detect itself or someone else in the public network.
- **Public** - fully distributed.
