# Recorder Chain

The recorder chain is an out of consensus hash chain, which acts much like a blockchain.
In the sense that all of the outputs for an epoch are stored in each link.
The purpose of the recorder chain is to acts as backup mechanism that can be used to replay the database transactions.

A node is not required to store the entire recorder chain, but it's recommended that it stores and publishes the most recent recorders.
This is to make it easier for new nodes to synchronize the database. And can also help for explorers, proving transactions and wallet updates.

Since the recorder chain is not a part of the consensus data there is no guarantee that anyone will have the recorder chain on hand. But if one does have a piece the chain it can be proven against bullseyes in the epoch chain.
