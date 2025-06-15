---
sidebar_position: 5
sidebar_label: 101 - How Tagion works
---
# How Tagion works: step-by-step

_Written by [Decard](https://www.decard.io) - the initial stewardship company of the Tagion platform._

:::info[Final Version pending]
This is an advanced draft (last edit June 3rd 2025), final improvements of details and descriptions are pending. Once complete, this message will be removed.
:::

:::tip[Jargon Busting]

All technical terms will here be written in _italics_. Some of them are explained at the beginning, some first appear "in inverted commas" in the text and are explained there.  
If not mentioned specifically, links in the text go to the technical documentation pages of the Tagion project. There, full technical details and codes are provided but - in contrast to this introductory text - a high level of technical understanding is assumed.
There is also a complementary [Glossary](https://docs.tagion.org/gov/glossary) for terms which are here not touched upon. 

:::


## Up first: a bit of terminology
___
**User:** anybody making use of Tagion software, without being a _node_ operator

**Node:** instance of main Tagion software (for Tagion Mainnet and Subsystems). Several _nodes_ can run on one computer, but in a _"distributed"_ system they will be on different computers connected via the internet

**Subsystem:** a bespoke network of _nodes_ for a particular use-case, independent of the Tagion _Mainnet_ in terms of rules and settings. It hosts its own _database_ and sends regular hashed/encrypted status updates to the _Mainnet_ (for validation and notary functions, further explained below). Because of this, _Subsystems_ are here called _"federated"_ with the Tagion _Mainnet_.

**Database:** structured system to store, manage and retrieve data. Akin rather to a filing cabinet with labeled drawers - not the records in those drawers. 

_"DART"_ is the name of Tagion's custom-designed database system (further explained below) maintained in/by the Tagion _node_ software

**App:** _user_-interface to make changes to the _database_, it sends info about intended changes to a _node_

**Transaction:** unit of _database_-changes (add, edit, delete), including but not limited to currency related _transactions_

... that much said, we now have enough words to begin ...

***


## Starting from a general use-case

A _user_ (see above) wants to enter some new pieces of information to the system. Let's assume that this information is about a particular use-case for which a _federate Subsystem_ (see above) has been set up.

The _user_ submits the information via an _app_ (see above), e.g. on their mobile phone. 
This information can be new (it will be added to the _database_ - see above), or it can be a change to (or deletion of) existing data. Along with the information itself, the _user_ submits their electronic signature which will be linked to submitted information as a way to manage and authenticate access rights to the data. 

The _app_ they use for this is built upon  -  and sometimes still called -   a "wallet application", a term inherited from the Tagion _Mainnet_ with its principle use-cases centered around financial _transactions_ ("JustPay" is such a wallet application, more information about it on the [Decard website](https://www.decard.io/justpay)). The _application_ packages the information to be entered into the _database_. 

Next to the basic data-input and additional required information (timestamp, user identity, references to other data, required permissions) there can also be "payload" information sent to a _node_ which might contain conditional instructions that are far more complex than simply "add this information to the database". The whole information package is here called a "contract" - a term inherited from "blockchain" and "DLT" concepts, where the compound term "smart contracts" is used to imply "self-executing" when _payload_ contains (complex) conditional instructions.

Such _contracts_ are sent to a _node_ (see above, or [here for all details](https://docs.tagion.org/tech/architecture)) via the internet or local communication networks. To enable swift transmission under most bandwidth conditions, _[contracts](https://docs.tagion.org/tech/protocols/transactions/contract)_ are structured/written according to our custom "HiRPC" communication format, which in turn is based on our general data format called "[HiBON](https://docs.tagion.org/tech/protocols/hibon)". We felt compelled to design those new formats to achieve the highest level of security and flexibility for control of data at the record level. At the same time, these formats allow for the utmost efficiency in terms of storage and computing requirements for the network.


## Distribution: from one node to many

The receiving _node_ [checks the information](https://docs.tagion.org/tech/protocols/transactions) sent in the _contract_ against the information already existing in its locally stored _database_ (e.g. if user identities and permissions are valid and other data is referenced correctly). Results are preliminarily stored in the memory of the _node's_ "virtual machine"  - the computation and execution software interpreting the operations specified in a contract. The [Tagion Virtual Machine (TVM)](https://docs.tagion.org/tech/architecture/TVM) is built on the popular open WebAssembly standard. 

However, for the moment none of the results of _executing a contract_ is committed to the Tagion _database_. Because in a "distributed" system without central control, all _nodes_ need to make sure they maintain their individual copies of the _database_ in accurate synchronisation and don't make changes without coordination. Thus, the Tagion _nodes_ will first notify other _nodes_ in the network about the receipt of any new _contract_ and their contents. 

This continuous communication between _nodes_ does not only concern _contracts_ they received individually, but also  _contracts_ submitted to other nodes which they consequently heard about. This propagation of information is here called "gossip about gossip". And in this way, all _nodes_ will eventually know of all recent submissions to the whole network - at least up to a certain point in the (not-so-distant) past.    

For everything before that point, a network-wide agreement about everything to be changed in the _database_ will have been reached, thanks to the _gossiping_ between _nodes_. In _distributed_ systems, such a process of reaching agreement is called "consensus mechanism", and the time-span from one moment of consensus to the next is called an "epoch". 

In Tagion, only for _contracts_ submitted within a concluded _[epoch](https://docs.tagion.org/tech/protocols/consensus/EpochRules)_ will _nodes_ commit the new information to their database(s). Later submissions which, at this moment, have not been shared widely across the whole network will be dealt with in the next epoch. This way the information in the network is synchronised up to the recent moment of _consensus_, and the resulting shared version of all individual _database(s)_ is called their new "state" (as in "state of play" or "the current situation"). 

## Consensus: how nodes know what other know

How _consensus_ on the _state_ of the network is achieved is different from one distributed network to the next. So called "blockchains" offered the first popular solution for _consensus_ without a central authority. And when the practical limitations of _blockchains_ became obvious and new solutions were sought, the collective term "DLTs" was introduced - which stands for "distributed ledger technologies" . The "ledger" part of that term was again inherited from the early use-cases of _DLTs_ in currency transactions and accounting. Tagion, which is not a blockchain but a network of distributed databases, has utility far beyond ledger based accounting. But to understand the concept and implementation of its _consensus_ mechanism it remains useful to see it in context of its heritage. 

Common to all _consensus_ mechanisms is that _nodes_ constantly communicate with each other about how their local versions of their _shared database_ have evolved or should evolve. The scenario in which some _nodes_ fail to do so (be it [deliberate/maliciously](https://docs.tagion.org/gov/governance_areas/network_formation/introductions/sybil), or because of [lost connectivity](https://docs.tagion.org/tech/architecture/network_modes)), is described as the so-called "Byzantine Generals Problem". Consequently, _DLTs_ that solve that problem and can deal with a certain number of divergent _nodes_ are called "byzantine fault tolerant".

For Decard's platform two innovative "protocols" (meaning sets of rules about the communication between different software entities) enable a fast, secure and modular _consensus_, which is also most efficient in terms of required storage capacity, internet bandwidth and energy consumption. This consensus is highly _byzantine fault tolerant_, as it still functions with up to 1/3 of all _nodes_ being out of sync or not playing by the rules.

The first of those two _protocols_, developed and patented by Decard, is called the "[Wavefront](https://docs.tagion.org/tech/protocols/wavefront)" protocol and it manages the _gossip-about-gossip_ as introduced above. It swiftly conveys how many new _contracts_ each of the two _nodes_ have received (directly or indirectly) since the last _epoch_, and then enables them to efficiently synchronise their local knowledge. This includes _contracts/transactions_ that were submitted to the communicating _nodes_ since the last _epoch_, but also the _contracts/transactions_ submitted to other _nodes_ which either of the communicating _nodes_ has already heard about.

The second _protocol_ then establishes _consensus_ not by comparing the databases themselves (or counting the number of blocks in a chain) but by tracking the level of shared knowledge that _nodes_ have communicated about in the wavefront protocol. This _consensus protocol_ was originally developed by Leemon Baird (co-founder of the "Hedera" project), under the now well established term "[Hashgraph consensus algorithm](https://docs.tagion.org/tech/protocols/consensus/HashGraph)".

Together, the two _protocols_ ensure that nodes estebalish swiftly and securely which changes are to be introduced to the _database_. From the network-wide communication history, each _node_ can reconstruct by and for itself, and with mathematical certainty, what other _nodes_ in the network know. Once information about new _contracts/transactions_ (since the last epoch) has spread to enough  _nodes_ in the network (namely to [2/3+1 of all _nodes_](https://docs.tagion.org/tech/protocols/consensus/EpochRules)), _consensus_ about those _contracts_ is established. 


## DART: Smarter than blockchains

Everything before that recent _epoch_ is then fixed in the database and no competing versions (in _blockchain_ systems those are called "forks") can occur. That is what is called "finality" in DLTs and while traditionally blockchains rely on "probabilistic finality" (because there is always a slight chance that a fork can gain consensus), Tagion features the absolute certainty called "deterministic finality". 

Because, once the changes agreed on in the _hashgraph consensus mechanism_ have been submitted to the _database_, there is a final step to ensure all nodes have the same resulting copy: each node calculates a signet of the complete new version of their _database_, and sends it to the network for verification. These signets are mathematical fingerprints (called "hashes") of the database. For Decard's specially designed database called "DART" (which stands for "[Distributed Archive of Random Transactions](https://docs.tagion.org/tech/architecture/DART)"), this fingerprint is called the "bullseye" (of the metaphorical DART-board). And thanks to the patented architecture of the _DART database_, the calculation of a _bullseye_ requires only minimal computing resources. This way, the network will quickly flag up _nodes_ that had fallen out of sync because they will arrive at a different _bullseye_. And because all _bullseyes_ are stored and linked in what is here called a "[epoch chain](https://docs.tagion.org/tech/protocols/consensus/epoch_chain)", finality of the _DART database_ is absolute, without the need to retain the communication/_gossip_ history of past _epochs_.

In many _blockchains_ systems, where _consensus mechanism_ and storage of data both happen "on the blocks", _finality_ entails that information (included in earlier blocks) can never be altered or deleted. This is different with Tagion because its _hashgraph consensus_ relates to the submitted changes to it's _database_, but functions independent, or outside of it. In this modular system, where _consensus_ and _storage_ are separate, data can always be changed or deleted (given the correct permissions, of course), and _finality_ refers to reliability of each new _state_ of the _database_ without limiting data management and control.

Another effect of the way Tagion achieves _consensus_ is that the order of changes to the database is determined by the time in which most _nodes_ have received knowledge about _contracts_ affecting that change.  We call this "fair ordering", as it cannot be manipulated by individual _node_ operators or distorted by the amount of fees offered by _users_ (as in many popular _blockchain_ systems).


## Tagion: best of two worlds

Talking about accountability: another unique design feature of the _DART_ database is that all entries and edits have an "owner", typically the _user_ specified in the _contract_ that created the data entry. Access rights to each data point can be managed like the file permissions in a conventional computer system (e.g. read, write, own). In this regard, rules concerning privacy, anonymity and security can be determined individually for each (type of) entry, or for each _Subsystem database_, depending on its particular use-case. Only for _contracts/transactions_ of ["TGN", the native utility token](https://docs.tagion.org/gov/governance_areas/token_economy/utility_token) on the Tagion _Mainnet_, the rules are fixed: the amounts of the transactions are revealed, along with the identifiers of the payer and payee. But their actual identities are protected because, different from most _blockchains_, only the resulting balances of a _transaction/contract_ are stored in the new state of the database, not the contracts with the actors' information themselves.  

In a _Subsystem_, the actors can be made visible (only to the participants of that _Subsystem_ or more widely), while the content kept in the Subsystem's own database can be protected as appropriate for the use-case or industry. The level of data-protection available can be configured to be compliant with any privacy and data-protection regulation or even up to government agency levels of classification - including but not limited to access-control, authentication and sharing services, and multi-signature requirements.

Each _Subsystem_ thus benefits from having its own _distributed database_, shared and synchronized across its own network of nodes. The set of participants of that "sub-network" can be freely defined (e.g in a "permissioned" network) while also freely determining its own rules and governance as needed. The only mandatory information shared with the Tagion _Mainnet_ is the regularly calculated _bullseye_-signet.

For a _Subsystem_ the _bullseyes_ are of additional importance because they get submitted to and recorded in the Tagion _Mainnet_ providing a continuous quasi-public audit trail of the _Subsystem's_ accurate operation. 
This is why the _Mainnet_ is said to fulfill the function of a "public notary" to its _federated Subsystems_. But _public_ here goes beyond any nation state's public institutions and power. The [governance rules](https://docs.tagion.org/gov/governance_areas/network_formation/introductions) and protocols being developed for the Tagion _Mainnet_ make it "[decentralised](https://docs.tagion.org/gov/intro/manifesto)", meaning no entity owns or controls the network and anybody can participate. This is achieved by our "[proof of community](https://docs.tagion.org/gov/governance_areas/network_formation/tagion)" requirements for becoming a node operator on the Mainnet, and the randomised [rotation of validator nodes](https://docs.tagion.org/gov/intro/network#nodes) that participated in the hashgraph consensus.
Thus, the trust and reliability provided by the Tagion platform extends beyond the classical boundaries between _public_ and private, or nation states and industries.

This move away from central authority to an infrastructure that is run and governed by its _users_ and stakeholders had been one of the impulses for the development of _blockchain_ technologies. However, the particular way in which _DLTs_ manage data and achieve consensus has been riddled with inefficiencies from the beginning. No DLT solution has achieved scalability without compromising on [security](https://docs.tagion.org/gov/governance_areas/network_formation/introductions/sybil) or _[decentralization](https://docs.tagion.org/gov/governance_areas/network_formation/introductions/recentralisation)_. This is why Tagion as a database system that functions in a _distributed_ manner and designed to be _decentralized_ is such a novelty. 

Built from the ground up with efficiency as its foundational design principle, it achieves the speed, safety and energy efficiencies of traditional server based _databases_ - while staying true to the promises of _DLTs_ and providing the cooperative data infrastructure needed for multi-stakeholder industries and use-cases.

***
If you are now inspired to deploy Tagion for your business, project or community but do not have the expertise to set-up a _node_ and _Subsystem_ for yourself, contact [Decard](https://www.decard.io/): the stewardship entity to drive the development and adoption of Tagion.



