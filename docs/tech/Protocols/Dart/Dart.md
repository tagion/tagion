# DART

The "Distributed Archive of Random Transactions" is the consensus database used by tagion.
It stores [HiBON documents](/tech/protocols/hibon) in a key value fashion. Where the key is a [dartindex](/tech/protocols/dart/dartindex)
Each node continuously updates their copy of the database as consensus is reached.

Internally it is represented as a 'sparse-merkle-tree'. This allows efficiently calculating the consensus state of the database ([bullseye](/tech/protocols/dart/bullseye)).  
And makes synchronization with new nodes trivial.
The specific benefits of this structure is also described in the [DART Patent](/assets/DART_Patent_EP_3790224.pdf).

![DART structural layout](/assets/dart_structural_layout.png)
