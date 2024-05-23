# Epoch Chain

The Epoch Chain is a hash chain that is stored in the main DART. 
Each time an epoch has consensus the [Epoch](https://ddoc.tagion.org/tagion.script.common.Epoch.html) namerecord is stored with the epoch as the key.
The record stores the current consensus bullseye and the previous consensus bullseye and the signatures of from each node which voted on the epoch along with some metadata.
An this hash pointer to the previous bullseye creates the verifiable hashchain.
The very first epoch, the [GenesisEpoch](https://ddoc.tagion.org/tagion.script.common.GenesisEpoch.html) stores no previous epoch and no votes. Instead it stores the public key of each of the first active nodes.  

The additional data stored in the chain is the consensus time. This is the pseudo (average) time agreed on by the hashgraph.
The [TagionGlobals](https://ddoc.tagion.org/tagion.script.common.TagionGlobals.html), such that the currency supply can be tracked.
Any changed state of participating nodes is also stored.
