Feature: Add the genesis block

The genesis block include bootstrap information of the network
The genesis block should the boot strap nodes and should also be signed by an number of
unknown private keys. 

Scenario verification of the genesis block

Given a list genesis-public keys store in a genesis block

Given a list of signatures store in the '#tagion'.

When all signatures has been verified

Then the genesis block is considered to be valid

But if not all signature is correct then the block is not consider to be valid


