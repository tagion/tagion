---
sidebar_position: 3
---

# Glossary

## Administered Pricing 

Administered pricing is a concept introduced by the economist Gardiner Means, referring to the practice where prices are set deliberately by businesses, rather than being determined through atomistic competition — the orthodox economic model where numerous small players compete, and prices fluctuate according to supply and demand. 

Administered prices are set by corporations with significant market power, who can set and maintain stable prices over time, regardless of short-term fluctuations in demand or production costs. Means noted that such firms often use mark-up pricing, where prices are set by applying a predetermined mark-up over estimated production costs to achieve desired profit margins, rather than allowing market forces to dictate prices. 

## Anonymity

A lot of DLT systems list "anonymity" as one of their benefits in comparison to conventional systems. However, what that term means to them often difers - in theory as much as in practice. 
We here define it (in comparison to "privacy") according to what (action or actor) is identifiable to 3rd parties.

|Definition: | **Privacy** |**Anonymity**|
|--|:--:|:--:|
|**Action** <br />can be identified by 3rd party:|**No**|**Yes**|
|**Actor** <br />can be identified by 3rd party: |**Yes**|**No**|


For the two strucural levels of Tagion, [Mainnet](/gov/glossary#tagion-mainnet) and [federated Subsystem](/gov/glossary#federated-subsystem), this means repectively:


|In Tagion | **Full Privacy** |**Full Anonymity**|
|--|:--:|:--:|
|**Mainnet:**|**No** <br />because the amounts of all Txs are public|**Yes** <br />unless users decide to disclose their identity |
|**Subsystem:**  |**Yes**<br />if so desired – but the opposite is also possible (allowing for regulatory compliance)|**Yes**<br />if so desired – but the opposite is also possible (allowing for regulatory compliance)|
 

## Community 

The word "community" is derived from the Latin communitas, which comes from communis, meaning "common, public, or shared by all." Combining con- (together) and munis (relating to duties or services), it conveys the idea of people coming together to fulfill shared responsibilities or provide services.  

In the context of Tagion, the Community encompasses all verified [Community Members](/gov/glossary#community-member) actively participating in and contributing to the network, including [consensus](/gov/glossary#consensus) and [Governance](/gov/glossary#governance) processes.  

Notably, Community is a fluid term - a flexible and evolving entity - that may adapt to include new roles and contributors as the network develops and grows. 

## Community Member 

A community member is any individual or entity who has been verified by peers through the network’s [Social Scoring System](/gov/governance_areas/network_formation/tagion/poc). Once verified, community members gain the right to participate in both the consensus process and the governance of the network, contributing to its security, efficiency and decision-making. 

## Consensus 

Consensus refers to the process by which  [Nodes](/gov/glossary#nodes) agree on the validity and order of transactions recorded in the [Database](/gov/glossary#distributed_database). It ensures the integrity, security, and trustlessness of the Tagion Network by making sure that all participants maintain a consistent view of the database without relying on a central authority. 

In the Tagion Network, consensus is reached using an Asynchronous Byzantine Fault Tolerant (ABFT) consensus algorithm called Hashgraph. In this system: 

A Gossip Protocol connects nodes through information sharing. 

Timestamps and Ordering establish a chronological event sequence. 

Finality emerges as a supermajority consensus, confirming agreed-upon transactions. 

Through Hashgraph, Tagion attains decentralised consensus, enabling honest nodes to synchronise even in the face of potentially malicious participants. 

## Contributors 

The term "contributor" is fluid, encompassing a wide array of possible roles that may expand as the network matures and new opportunities for engagement emerge. For now, we consider our contributors a category that íncludes but also goes beyond out "community members" (see above). As such they encompass: node operator, developers and governance participants, as outlined [here](/gov/intro/network). 
 

## Currency 

An implementation/instantiation of the concept of [money](/gov/glossary#money).  

## De jure / de facto
We use these funny sounding terms to distinguish between the intention and the effect of certain terms, or what is elsewhere called "in theory" and "in practice". "De jure" has references to law, which seems approrpiate in the DLT space where coded rules are often apprised as if they were law. However, as we explain in the article about "[permissionlessness](/gov/governance_areas/network_formation/introductions/permission)", the real-world effect of certain rules (de facto) can run counter to its intention (de jure). 

## Distributed Database 

Tagion is a distributed database, not a ledger, designed to enable dynamic and flexible data management. Unlike ledgers that record data as a linear, immutable chain of transactions, Tagion allows for data to be queried, updated, and deleted. 

Tagion ensures data integrity and authenticity through an immutable audit trail. Each update to the database is cryptographically signed and verified, creating a traceable history of changes. This guarantees that users can validate the authenticity and integrity of data while avoiding the inefficiencies of sequential ledger systems, such as blockchain. 

## Federated Subsystem 

A Federated Subsystem is an independent network — either public or private — that operates separately from the Tagion [Mainnet](/gov/glossary#tagion-mainnet) but leverages the Mainnet for security and trust. These subsystems can be tailored to specific use cases, industries, or communities, providing flexibility in how they manage data and transactions while benefiting from the underlying security provided by Mainnet Nodes. 

In a Federated Subsystem, all data remains encrypted within the subsystem, ensuring privacy and confidentiality for users. However, transactional activity — the overall volume and frequency of transactions — is monitored by Mainnet Nodes. (Also see [Network Architecture](/gov/intro/network) in Governance Area "Network Formation".)

## Formation

In our governance area "network formation" we use this word analogous to its dual meaning in geology: the process of forming something AND the resulting structure (as in "rock formation").

## Governance 

At its root, the term "governance" comes from the Greek word kybernan, meaning to steer or guide. In the context of a decentralized network like Tagion, governance refers to the system and processes through which decisions are made, rules are set, and changes are implemented. It encompasses both [on-chain](/gov/glosary#on-chain-governance) processes—such as voting and proposal submission—and informal practices, including open discussions and deliberation on proposals. 

## Money 

Since it has many but no definitive meanings even in economics and law, we here operate with the most basic definition: a system of transferable units to facilitate collaboration within a certain constituency (compare [Bindewald 2021](https://www.mdpi.com/1911-8074/14/2/55)). 

## Network Services 

Network services refer to the functionalities provided by the Tagion Mainnet, enabling users to submit and process transactions, create and interact with smart contracts, manage and store data, and participate in governance processes. 

## Nodes 

A node is any device that connects to the network to help maintain the [database](/gov/glossary#distributed-database). Nodes perform various roles, such as storing a copy of the database, validating and propagating transactions, and participating in the [consensus process](/gov/glossary#consensus). The types of nodes in the Tagion network are outlined [here](/gov/intro/network). 


## On-chain Governance 

On-chain governance refers to formal processes—such as submitting proposals, casting votes, and executing decisions—carried out through smart contracts on the network itself. It ensures that decisions are not only transparent but also enforceable and resistant to manipulation. 

## Open/Closed 

Refers to networks being built on Tagion code and being connected (open) or unconnected (closed) to the mainnet. The latter is what we call “sub-systems”, the former need to comply with out licensing T&Cs.  

## Permission/Un-permissioned 

Refers to anybody being able to participate in a system, e.g. running a node, with or without permission. (See our in-depth analysis what this means for DLT systems - "de-jure and de-facto" - [here](https://docs.tagion.org/gov/governance_areas/network_formation/introductions/permission).)


## Public/Private

A public system or infrastrucre is open for everybody to use. Tagion aspires to provide that. Sub-systems however can choose to be set up there own rules and invite or preclude user as deem appropriate for the individual use-cases.    

## Tagion Mainnet 

The Tagion Mainnet serves as the foundation of the Tagion Ecosystem, operating as a Layer 0 that provides the settlement layer for TGN transactions, the infrastructure facilitating network governance, and the security and interoperability layer that connects and protects the broader network of [Federated Subsystems](/gov/glossary#tagion-mainnet). By allowing independent networks to batch and finalize transactions on its secure and immutable ledger, the Mainnet ensures that even private Subsystems remain anchored to the decentralized security of the ecosystem. 

Notably, to keep the Mainnet streamlined, applications are primarily run on Federated Sub-systems, reducing the risk of Mainnet bloating and ensuring that the core network remains slick, scalable, and high-performing. (Also see [Network Architecture](/gov/intro/network) in Governance Atrea "Network Formation")
