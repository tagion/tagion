# HashGraph consensus

The Tagion hashgraph is an implementation variant of the [HashGraph](https://www.swirlds.com/downloads/SWIRLDS-TR-2016-01.pdf)


The hashgraph is a Directed Acyclic Graph(DAG) that recorder the history of communication events this means that the graph of events is connected to the previous communications events and makes up a DAG.

The hashgraph is built around a gossip network where each node maintains a gossip history graph called a “hashgraph”.

The consensus between network nodes is archived by looking at the transaction history in the graph and updating the virtual voting.

The active nodes, which are tracked in the hashgraph are a fixed number of N nodes, and the majority voting is defined when more than 2/3 of nodes N have voted.

![Mother father](/figs/mother_father.svg)

The edges are uniquely identified by the cryptographical hash of the event to which it is connected. An event can only have two event connections: a mother-event, the previous event from the same node and a father-event which is created and sent from another node.
If an event does not have a mother, it’s defined as an Eva event; if an event only has mothers connected to it, it is defined as a father-less event.

![Event package](/figs/event_package.excalidraw.svg)


## Witness
An event is defined as a witness if you can strongly see the majority of previous witnesses and strongly seeing means that a witness is connected through the majority of other nodes meaning that it crosses the majority of the other events in the other nodes.
![Event package](/figs/strongly_seen.excalidraw.svg)

Each event has a round number which is the maximum of the mother and father round number.

A witness event also divides the witnesses into a new round by increasing the round number by one.
```
    if event is a witness
        number = max(mother.number, father.number)
    else 
        number = max(mother.number, father.number) + 1
```

The voting is recorded in bit vectors/masks which makes it efficient for computer implementation.

Each node in the graph has a node_id which is specified from 0 to N-1 and the voting is done by setting the bit number at node_id to 1. 

## Event voting masks
An event has two voting masks.
```
    $w witness_seen_mask
    $i intemediate_seen_mask
```

The witness_seen_mask is updated when the event connects to a father event the witness_seen_mask like
```
if the event has a father
    witness_seen_mask = mother.witness_seen_mask | father.witness_seen_mask
else
    witness_seen_mask = mother.witness_seen_mask
```

### Intermediate Seen Mask
The intermediate_seen_mask is set when the witness_seen_mask is changed.
This means the intermediate_seen_mask bit represents the current connections to a new node. 
```
intermediate_seen_mask = intermediate_seen_mask | mother.intermediate_seen_mask
if (witness_seen_mask has changed) 
    intermediate_seen_mask[node_id] = 1
    intermediate_seen_mask = intermediate_seen_mask | father.intermediate_seen_mask

```

## Witness voting masks
Each witness contains the following bit masks
```
    $d intermediate_voting_mask
    $s previous_strongly_seen_mask
    $v voted_yes_mask
```

### Intermediate Voting mask
The intermediate_voting_mask accounts for the intermediate voting for the next round which helps to decide if an event will become a witness.

The round used to account for the intermediate voting is the father round if the event does not have a father then the account round is the mother round.
### Strongly seen


The following conditions should be met to decide if an event is a witness.
The event should have the majority of intermediate_seen_mask,
this means that we have seen the majority of witnesses in the previous round.
Select and count all witnesses in the previous round and check if the intermediate_voting_mask is set to the event node_id.
If the count is the majority then the event is a witness and the event is now created as a witness.

When a witness is created the previous_strongly_seen_mask is created.
If the father round is leading the strongy_seen_mask is set to the previous_strongly_seen_mask of the mother and the father and if the mother is leading the strongy_seen_mask is set to the intermediate_seen_mask of the mother.

The father round is leading if a witness exists in the round of the father and if the father round number is higher than the mother round number.
```
    if father round is leading
	previous_strongly_seen_mask = father.intermediate_seen_mask | mother.previous_strongly_seen_mask
   else 
	previous_strongly_seen_masl = mother.intermediate_seen_mask

intermediate_voting_mask[node_id]  = 1
clear intermediate_seen_mask
```

When an event is changed to a witness the following is done.

![hashgraph](/figs/hashgraph.svg)

A witness is defined as weak if there is no witness in the previous round.
 
Vote for the previous round.
Select all the non-weak witnesses in the previous round and vote yes if the bit at node_id is in  previous_strongly_seen_mask.
```
Select all witnesses in the previous round and set the voted_yes_mask[node_id]  = 1
```

## Epoch Decision

### Decided Witness
A witness is decided if the majority of the witnesses vote yes or no or if the vote is a tie.

### Decided Round 

1. A round is decided if the number of witnesses in round is in the majority and
when all witnesses in a round are decided.

Or

2. If the round is not decided and after more than D rounds a round will be decided.
 
## Collection of events.
If a round is decided with the majority of witnesses having yes votes those events will collect the event for the epoch.

All events will be collected by voting witnesses which are the parent's events are connected to the majority of the witness collecting events the received round of the collected event with be set to the round of the collection witnesses.

An epoch is defined as a list of all the collected events.

![overview of network nodes](/figs/hashgraph_event_sample.svg)


