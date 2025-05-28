---
sidebar_position: 3
sidebar_label: Network Overview
---

# The Tagion network

The system architecture is composed of a [**Mainnet**](/gov/glossary#tagion-mainnet) and a series of [**Federated Sub-Systems**](/gov/glossary#federated-subsystem). As per the Tagion manifesto, the intention is to have the mainnet decentralized and allowing the greatest number of entities to run federated subsystems for their use-cases. In contrast to traditional centralized systems, where a single entity oversees operations and engages with "clients", decentralised networks thrive on a large number of different entities that need to be involved, actively or passively. 

![Federated](/img/Federated.png)

## Stakeholders

The main distinction we draw for the time being is between "stakeholders" and "community members". The difference being, that community members are entities that hold a name record on the Tagion system (see ["tech-documentation"](https://docs.tagion.org/tech/protocols/dart/dartindex#dart-namerecords--hashkeys) for more info) and have been endorsed by their peers. As such, only community members can run a node (see below) and participate in governance. 
Becoming a member is not necessary for stakeholders that simply want to use TGN tokens or other Tagion services, contribute to the network as a developer or service provider or in any other capacity. But we are striving to design the decentralization of the network in such a way that becoming a member remains open to the greatest number of people globally.  


## Nodes

In Tagion there are currently three types of nodes: 

### Core Nodes
At the heart of the system, core nodes are tasked with maintaining the database and reaching agreement on the data submitted and stored—a process referred to as [consensus](/gov/glossary#consensus). But not all nodes of this category actively particiapte in the consensus mechanism at any one time. Those that do uphold the integrity and security of the system, ensuring that the data stored is accurate and protected.  
Swapping nodes in and out from this function is one of Tagion's unqiue features achieve a [high level of decentralisation](https://docs.tagion.org/gov/governance_areas/network_formation/introductions). 

### Relay Nodes
These nodes act as intermediaries, collecting, collating, and managing user requests to submit or retrieve data. Because they also filter out spam and unnecessary requests, they significantly reduce the load on core nodes, enhancing the overall efficiency of the system. 

### Mirror Nodes
Mirror nodes maintain a full or partial snapshot of the database and update that at given self-selected intervals. Their primary function is to facilitate easy and efficient data retrieval for users while also alleviating the demand on core nodes. 


## Governance Participants

Governance Participants play a critical role in shaping the network's future. Through proposals, debates, and voting, they decide, among other things, on protocol upgrades and treasury finances, including fees and rewards. They ensure that the network remains adaptive and aligns with the Manifesto and the interests of its users. 

### Preliminary roles

At the time of writing, Tagion is not decentralised. The phases of this ongoing process are explained on the next page. 
Consequently, the category "community members" is only loosely defined in practice, meaning anybody engaging with us on Tagion's development through our [Discord channel](https://discord.gg/wE4AA64a). 
In due time, an organisational structure will be established (e.g. a foundation, association, cooperative, or DOA...) to take the responsibility for governance development over from the current stewardship entity [Decard](https://www.tagion.org/about/).
