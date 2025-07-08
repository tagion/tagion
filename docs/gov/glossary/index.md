---
sidebar_position: 3
---

# Glossary

Unless stated differently, links within the following entries go to other entries of the glossary. 


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


For the two strucural levels of Tagion, [Mainnet](/gov/glossary#tagion-mainnet) and [federated Subsystem](/gov/glossary#federated-subsystem), this means respectively:


|In Tagion | **Full Privacy** |**Full Anonymity**|
|--|:--:|:--:|
|**Mainnet:**|**No** <br />because the amounts of all Txs are public|**Yes** <br />unless users decide to disclose their identity |
|**Subsystem:**  |**Yes**<br />if so desired – but the opposite is also possible (allowing for regulatory compliance)|**Yes**<br />if so desired – but the opposite is also possible (allowing for regulatory compliance)|

## Appplication (mobile)

A user-interface to make changes to the [database](/gov/glossary#database), it sends info about intended changes to a [node](/gov/glossary#node).

## Burning (tokens)

Expression describing when tokens are destroyed permanently, typically to reduce the total supply. 

## Byzantine Fault Tolerance (BFT)

The network's ability to reach and maintain [consensus](/gov/glossary#consensus) and function correctly even in the presence of malicious, faulty, or non-cooperative actors/[nodes](/gov/glossary#node).

## Community 

The word "community" is derived from the Latin communitas, which comes from communis, meaning "common, public, or shared by all." Combining con- (together) and munis (relating to duties or services), it conveys the idea of people coming together to fulfill shared responsibilities or provide services.  

In the context of Tagion, the Community encompasses all verified [Community Members](/gov/glossary#community-member) actively participating in and contributing to the network, including [consensus](/gov/glossary#consensus) and [Governance](/gov/glossary#governance) processes.  

Notably, Community is a fluid term - a flexible and evolving entity - that may adapt to include new roles and contributors as the network develops and grows. 

## Community Member 

A community member is any individual or entity who has been verified by peers through the network’s [Social Scoring System](/gov/governance_areas/network_formation/tagion/poc). Once verified, community members gain the right to participate in both the consensus process and the governance of the network, contributing to its security, efficiency and decision-making. 

## Consensus 

Consensus refers to the process by which  [Nodes](/gov/glossary#nodes) agree on the transactions (and their order) to be recorded in the shared [Database](/gov/glossary#distributed-database). It ensures the integrity, security of the Tagion Network by making sure that all participating nodes maintain a consistent view of the current state of data without relying on a central authority.  
In the Tagion Network, consensus is reached using an Asynchronous Byzantine Fault Tolerant (ABFT) consensus algorithm called Hashgraph. 

## Consistency

A property that ensures all participants in a decentralized system see and agree on the same state of data at the same moment in time. (also see [consensus](/gov/glossary#consensus)

## Contract (smart)

Information package instructing [nodes](gov/glossary#node) about [transactions](gov/glossary#transaction) to be included in the [database](gov/glossay#database). The term is inherited from "blockchain" and "DLT)(gov/glossar#distributed-ledger-technology-dlt) concepts, where the compound term "smart contracts" is used to imply "self-execution" when the payload of the package contains (complex) conditional instructions.

## Contributors 

The term "contributor" is fluid, encompassing a wide array of possible roles that may expand as the network matures and new opportunities for engagement emerge. For now, we consider our contributors a category that íncludes but also goes beyond out "community members" (see above). As such they encompass: node operator, developers and governance participants, as outlined [here](/gov/intro/network). 
 

## Currency 

An implementation/instantiation of the concept of [money](/gov/glossary#money).  

## Database

A structured system to store, manage and retrieve data. Akin rather to a filing cabinet with labeled drawers - not the records in those drawers. 
"DART" is the name of Tagion's custom-designed database system maintained in/by the Tagion [node](/gov/glossary#node) software 

## Decentralization

The ambition and process of making online networks not reliant and dominated by central or priviliedged parties. Innovative protocols are a precondition for it, and blockchains and later other DLTs have been a trail-blazer in that direction. The ideal/aspirational version is often equated with the oversimplified statement "Anybody can run a node" - or complete ["permissionlessness"](/gov/glossary#permissioned--permissionless). 

However, at Tagion we are mindful of the fact that this ideal will only ever be achieved to a certain degree - making "decentralization" more like a spectrum than a binary category (as in "system is decentralzied: yes or no"). To mark this disctinction we use the terms ["de jure" / "de facto"](/gov/glossary#de-jure--de-facto). 

## De jure / de facto
We use these funny sounding terms to distinguish between the intention and the effect of certain terms, or what is elsewhere called "in theory" and "in practice". "De jure" has references to law, which seems approrpiate in the DLT space where coded rules are often apprised as if they were law. However, the real-world effect of certain rules (de facto) can run counter to its intention (de jure). This is an important distinction particularly in regards to ["permissionlessness"](/gov/glossary#permissioned--permissionless)) as a precondition for decentralization (which we explore in depth in the ["network formation" section](/gov/governance_areas/network_formation/introductions) of our governance documentation. 

## Distributed Database 

Tagion is a distributed database, not a ledger, designed to enable dynamic and flexible data management. Unlike ledgers that record data as a linear, immutable chain of transactions, Tagion allows for data to be queried, updated, and deleted. 

Tagion ensures data integrity and authenticity through an immutable audit trail. Each update to the database is cryptographically signed and verified, creating a traceable history of changes. This guarantees that users can validate the authenticity and integrity of data while avoiding the inefficiencies of sequential ledger systems, such as blockchain. 

## Distributed Hash Table (DHT)

A [database](/gov/glossary#database) structure that enables data retreival based on key-value pairs. Distributed hash tables are decentralised, so all [nodes](/gov/glossary#node) form the collective system without centralised coordination. They are generally resilient because data is replicated across multiple nodes. 
 

## Distributed Ledger Technology (DLT)

A system of record-keeping where financial data is shared, synchronized, and stored across multiple nodes in a network. A ledger is a collection of accounts in which accounting transactions are recorded. A ledger is a limited use-case for a [database](/gov/glossary#database)-system.

## Federated Subsystem 

A Federated Subsystem is an independent network — either public or private — that operates separately from the Tagion [Mainnet](/gov/glossary#tagion-mainnet) but leverages the Mainnet for security and trust. These subsystems can be tailored to specific use cases, industries, or communities, providing flexibility in how they manage data and transactions while benefiting from the underlying security provided by Mainnet Nodes. 

In a Federated Subsystem, all data remains encrypted within the subsystem, ensuring privacy and confidentiality for users. However, transactional activity — the overall volume and frequency of transactions — is monitored by Mainnet Nodes. (Also see [Network Architecture](/gov/intro/network) in Governance Area "Network Formation".)

## Finality (time to)

Time to finality is the duration required for a [transaction](/gov/glossary#transaction) to be considered irreversible or practically [immutable](/gov/glossary#deterministic-finality) in the  system, depending on the [consensus](/gov/glossary#consensus) mechanism used. 

## Finality: Deterministic

A property of a distributed system where, once a [transaction](/gov/glossary#transaction) or block is finalized, it is permanently irreversible unless overridden by external intervention, such as a hard fork.

## Finality: Probabilistic

An oxymoron used to describe the property of a system where the likelihood of a [transaction](/gov/glossary#transaction) or block being reverted decreases over time as more confirmations are added, but reversal remains theoretically possible. 

## Formation

In our governance area "network formation" we use this word analogous to its dual meaning in geology: the process of forming something AND the resulting structure (as in "rock formation").

## Governance 

At its root, the term "governance" comes from the Greek word kybernan, meaning to steer or guide. In the context of a decentralized network like Tagion, governance refers to the system and processes through which decisions are made, rules are set, and changes are implemented. It encompasses both [on-chain](#on-chain) processes—such as voting and proposal submission—and informal practices, including open discussions and deliberation on proposals. 

## Liveness

A property of decentralized systems that ensures the system continues to make progress by processing new transactions, requests, or messages without indefinite delays.

## Money 

Since it has many but no definitive meanings even in economics and law, we here operate with the most basic definition: a system of transferable units to facilitate collaboration within a certain constituency (compare [Bindewald 2021](https://www.mdpi.com/1911-8074/14/2/55)). 

## Network Services 

Network services refer to the functionalities provided by the Tagion Mainnet, enabling users to submit and process transactions, create and interact with smart contracts, manage and store data, and participate in governance processes. 

## Nodes 

A node is an instance of the main Tagion software (for Tagion Mainnet and Subsystems). Several nodes can run on one computer, but in a "distributed" system they will be on different computers connected via the internet or local networks. Nodes maintain a copy of the [database](/gov/glossary#distributed-database) and validate and propagate transactions, and participating in the [consensus process](/gov/glossary#consensus). The types of nodes in the Tagion network are outlined [here](/gov/intro/network). 


## On-chain Governance 

On-chain governance refers to formal processes—such as submitting proposals, casting votes, and executing decisions—carried out through smart contracts on the network itself. It ensures that decisions are not only transparent but also enforceable and resistant to manipulation. 

## Open/Closed 

Refers to networks being built on Tagion code and being connected (open) or unconnected (closed) to the mainnet. The latter is what we call “sub-systems”, the former need to comply with out licensing T&Cs.  

## Ordering (fair)

The order in which transactions sent to different nodes are committed to the(ir) database(s) is determined by the median time at which the [nodes participating in the consensus](https://docs.tagion.org/tech/protocols/consensus/HashGraph) of that epoch have received the transaction or knowledge of it (through the [wavefront protocol](https://docs.tagion.org/tech/protocols/wavefront)). 
In contrast to the order of transactions in conventional DLT systems - determined by the highest fee or by subjective preferences of node operators - we call Tagion's approach to ordering "fair", because every transaction has the same chance of being included in the next epoch, and manipulations such as frontrunning and sandwich attacks become impossible. 

## Permissioned/Permissionless

Different defintions of these term exist, in the context of Tagion we use them to refer to the governance of the network and thhe question who can operae a node.

In the Mainnet, both are to be possible without permission. They are In federated Subsystem, the rules concerning both can be set freely. 

(See also our in-depth analysis of "de-jure and de-facto" permissionlessness of DLT systems [here](https://docs.tagion.org/gov/governance_areas/network_formation/introductions/permission).)


## Public/Private

Different defintions of these term exist, in the context of Tagion we use them as follows: 

A public network, system or infrastrucre is open for everybody to use and its data (transaction history, state, smart-contract code, etc.) is openly readable without prior registration or approval. Tagion aspires to provide that. 

Sub-systems however can choose to be set up there own rules and invite or preclude user - as deemed appropriate for the individual use-cases - making them de-facto private. 

## Scalability

The ability of a DLT system to process and validate a growing number of [transactions](/gov/glossary#transaction) or operations efficiently without compromising other essential properties, such as decentralization, security, and [consistency](/gov/glossary#consistency). 

## Stateless System

A misnomer, because a consensus systems, by definition, has a state that the consensus agrees on. However, in this context, it often refers to a system where the amount of data that validators must store is minimized to a constant, manageable size, regardless of the system’s scale or transaction volume.

## Stateless Contract

[Contracts](/gov/glossary#contract-smart) that check [transaction](/gov/glossary#transaction) details, approve or reject and process them without storing balances or transaction history on the blockchain/database. Instead, any required transaction data or business logic is provided by the transaction itself. 

##Sybil Attack

A term coined by John R. Douceur, refering to “an attack wherein a single entity masquerades as multiple entities or nodes within a network to gain a disproportionately high influence within the network or to subvert the network’s operation altogether.” An illicit actor, accordingly, creates multiple pseudonymous identities to manipulate or control the network. If successful, Sybil attacks can disrupt [consensus](/gov/glossary#consensus), manipulate governance decisions, and ultimately undermine the integrity of the system.

## Sybil Resistance Mechanism

Defines who can participate (as in running a [node](/gov/glossary#node)) in the [consensus](/gov/glossary#consensus) protocol and, potentially, in governance, serving as a mechanism to prevent Sybil attacks. 

## Tagion Mainnet 

The Tagion Mainnet serves as the foundation of the Tagion Ecosystem, operating as a Layer 0 that provides the settlement layer for TGN transactions, the infrastructure facilitating network governance, and the security and interoperability layer that connects and protects the broader network of [Federated Subsystems](/gov/glossary#tagion-mainnet). By allowing independent networks to batch and finalize transactions on its secure and immutable ledger, the Mainnet ensures that even private Subsystems remain anchored to the decentralized security of the ecosystem. 

Notably, to keep the Mainnet streamlined, applications are primarily run on Federated Sub-systems, reducing the risk of Mainnet bloating and ensuring that the core network remains slick, scalable, and high-performing. (Also see [Network Architecture](/gov/intro/network) in Governance Atrea "Network Formation")

## Transaction

Unit of [database](/gov/glossary#database)-changes (add, edit, delete), including but not limited to currency related transactions.

## Wallet

A digital [application](/gov/glossary#application-mobile) or device that securely stores cryptographic keys used to access and manage cryptocurrencies. It enables users to send, receive, and store their digital assets, providing a convenient and secure way to interact with networks. 
