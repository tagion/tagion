---
title: transactions
sidebar_position: 0
---

<!-- ![Contract](/figs/contract.excalidraw.svg) -->


<!-- Remember to update both the light and dark svg when you update the pictures -->
![Transaction flow](/figs/tx_flow_light.excalidraw.svg#gh-light-mode-only)
![Transaction flow](/figs/tx_flow_dark.excalidraw.svg#gh-dark-mode-only)

A general overview of how transactions are processed in the tagion network.
- A user generates a contract with their wallet application. 
    The contract contains a list of input that will be spent when the contract is processed.
    The inputs are [indices](/tech/protocols/dart/dartindex) to a UTXO in the [consensus database](/tech/protocols/dart).  
    To proof that the user actually owns the inputs, the contract includes a signature for each input that sign the contract.  
    Lastly the contract includes a function which produces the outputs which will be added to the the consensus database.
- The contract is sent to a node as a hirpc using the "submit" method
- The node reads the inputs from their own copy of the database.
- Inputs are then used the execute the contract. It's of course checked that the signatures are correct,
    that the fees are paid,
    and that the output does not exceed the value of the inputs, etc...
- The node then gossips the contract to other nodes and the process is repeated for all nodes until consensus is reached.
- At last all nodes apply the transaction by removing the contracts inputs and adding their outputs to the database.
    It is of course checked that no input is used by other transaction within the epoch round.
