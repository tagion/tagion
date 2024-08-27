# HashGraph consensus

The Tagion hashgraph implementation is a variant of the [HashGraph](https://www.swirlds.com/downloads/SWIRLDS-TR-2016-01.pdf)


The hashgraph is a Directed Acyclic Graph(DAG) that recorder the history of communication events this means that the graph of events is connected to the previous communications events and makes up a DAG.
The hashgraph algorithm is built around virtual voting and the majority voting is defined when more than ⅔ has voted yes and hashgraph has a finite number of nodes N.

![Mother father](/figs/mother_father.svg)

The edges are uniquely identified by the cryptographical hash of the event to which it is connected. An event can only have two event connections: a mother-event, which is the previous event from the same node, the father-event created and sent from another node.
If an event does not have a mother, it’s defined as an Eva event; if an event only has mothers connected to it, it is defined as a father-less event.

![Event package](/figs/event_package.svg)

## Witness
An event is defined as a witness if you can strongly see the majority of previous witnesses and strongly seeing means that a witness is connected through the majority of other nodes meaning that it crosses the majority. 
A witness event also divides the round for new witnesses the round number is increased.


The voting is recorded in bit vectors/masks which makes it efficient for computer implementation.

Each node in the graph has a node_id which is specified from 0 to N-1 and the voting is done by setting the bit number at node_id to 1. 

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

## Intermediate Seen Mask
The intermediate_seen_mask is set when is set, when the witness_seen_mask are changed
```
intermediate_seen_mask = intermediate_seen_mask | mother.intermediate_seen_mask
if (witness_seen_mask add a bit) 
    intermediate_seen_mask[node_id] = 1
    intermediate_seen_mask = intermediate_seen_mask | father.intermediate_seen_mask

```
Each witness contains the following bit masks
```
    $d intermediate_voting_mask
	$s previous_strongly_seen_mask
	$v voted_yes_mask
```

## intermediate Voting mask
The intermediate_voting_mask accounts for the intermediate voting for the next round which helps to decide if an event is a witness.

The voting round that is used to account for the intermediate voting is the father round if the event does not have a father then the account round is the mother round.

Each newly added bit number witness_seen_mask will be selected to select the witness in the voting round

select all newly added witnesses in the selected round and set the intermediate_voting_mask a the event  node_id to 1.

The intermediate_voting_mask accounts for the new crossing of nodes which helps the decide the strongly seen.

The strongly-seen can be decided from this and this also means

## Strongly seen
The following conditions should be met to decide if an event is a witness.
The event should have the majority of intermediate_seen_mask 
This means that we have seen the majority of witnesses in the previous round.
Select and count all witnesses in the previous round and check if the intermediate_voting_mask is set to the event node_id.
If the count is the majority then the event is a witness and the event is now created as a witness.

When a witness is created then the following is done.
The previous_strogly_seen_mask is sent to the intermediate_seen_mask and the node_id bit of internedate_voting_mask is set to 1 (the event is self-intermediate).
All bits in intermediate_seen_mask are set to 0 and the node_id witness_seen_mask is set 1 (because the event is its own witness).

```
previous_stongly_seen_mask = intermediate_seen_mask
intermediate_voting_mask[node_id]  = 1
clear intermediate_seen_mask
witness_seen_mask[node_id] =1
```
![hashgraph](/figs/hashgraph.svg)

A witness is defined as weak if there is no witness in the previous round.
 
Vote for the previous round.
Select all the non-weak witnesses in the previous round and vote yes if the bit at node_id is in  previous_strongly_seen_mask.
```
Select all witnesses in the previous round and set the voted_yes_mask[node_id]  = 1
```

## Decided witness and round
A witness is decided if the majority of the witnesses vote yes or no or if the vote is a tie. 


A round is decided if all witnesses in a round are decided.

If the round is not decided then we wait D round until we have a decision and then we define the round to be decided. 
 
## Collection of events.
If a round is decided with the majority of witnesses having yes votes those events will collect the event for the epoch.

All the events which parents of collecting witnesses and are connected to the majority will be collected for the epoch and the received round of all the collected events will be set to the collection round.
  

![overview of network nodes](/figs/hashgraph_event_sample.svg)

