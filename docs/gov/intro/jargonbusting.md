---
sidebar_class_name: hidden
---
# Step-by-Step: How Tagion works 

:::tip[Jargon Bustin']

All technical terms will here be written in _italics_. Some of them are explained at the beginning, some only appear "in inverted commas" when first introduced (and then explained) in the text.

:::

## A bit of terminology up-front
______________________________________________________________
**User:** anybody making use of Decard Platform, without being a node operator

**Node:** instance of Decard's main software (also for Tagion Mainnet). Several nodes can run on one computer, but in a "distributed" system they will be on different computers connected via the internet

**Database:** large file with archived information that is maintained in/by the node software ("DART" is the name of our special kind of database)

**App:** user-interface to make changes to the database, sends info about changes to a node
Transaction: unit of database changes (add, edit, delete), content not necessarily currency related, but a currency transaction can also contain "payload" of any kind of information

**Subsystem:** a bespoke network of nodes for a particular use-case, independent of the Tagion Mainnet in terms of rules and setting, but sends regular hashed/encrypted status updates to the Mainnet (for validation and notary function). Because of this, Subsystems are here called "federated" with the Tagion Mainnet.
______________________________________________________________

## Let's start from the practicalities of a general use-case:


A user (s.a.) wants to enter some new pieces of information to the system. 
They do that via an app (s.a.), e.g. on their mobile phone. 
This information can be new (it will be added to the database, s.a.), or it can be a change to (or deletion of) existing data.


The app they use for that is built upon - and sometimes still called - a "wallet application", a term inherited from the Tagion Mainnet (s.a.) with it's principle use-cases centered around financial transactions (s.a.).
The application packages the information to be entered into the database in what is (figuratively) called an "envelope". Next to the basic data-input and possibly some conditional instructions, the envelope also includes additional required information (timestamp, user identity, references to other data, required permissions), and the whole message inside the envelope is then called a "contract" (a term inherited from "blockchain" and "DLT" concepts, which will be explained below).


These contracts are sent to a node (s.a.) via the internet or local communication networks. A contract is structured/written according to our custom "HiRPC" communication format, which in turn is based on our general data format called "HiBON". We felt compelled to design those new formats to achieve the utmost efficiency in terms of storage and computing requirements for the network.


The receiving node checks the information sent in the enveloped contract against the information already existing in its locally stored database (e.g. if user identities and permissions are valid and other data is referenced correctly). It will then execute the transaction and make the changes to its local database as specified.


Now, in a "distributed" system, all nodes in the network need to make sure that they know about what transactions other nodes have processed. If they do, all nodes will maintain the same (copy of the) database. But because changes to the database are constantly ongoing at different nodes, their individual version of the database will always be slightly different from the others'.


Thus it is important that nodes continuously communicate with each other about the changes they processed, and changes of other nodes that they heard about. This way, they will eventually know of all recent changes across the whole network, up to a certain point in the (not-so-distant) past.


At that point, a network-wide and retrospective agreement, called "consensus", about a correct and complete version of the database is reached, and all nodes write the same history of changes into their copy of the database and the network has reached a common "state" (as in "state of play" or "the current situation"). Until the next moment of consensus is reached, the individual databases will start to diverge while nodes are being sent different contracts. The period from one point of consensus to the next is called an "epoch", and for the Tagion network such an epoch only takes a few seconds.


How consensus on the state of the network is achieved is different from one distributed network to the next. So called "blockchains" offered the first popular solution for consensus without a central authority. And when the practical limitations of blockchains became obvious and new solutions were sought, the collective term DLTs - which stands for "distributed ledger technologies" - was introduced for such solutions. The term "ledger" was again inherited from the early use-cases of DLTs in currency transactions and accounting.


Common to all DLTs consensus mechanism is, that nodes constantly communicate with each other about their local versions of the distributed database. The scenario in which some nodes fail to do so (be it deliberate/maliciously, or because of lost connectivity), is described as the so called "Byzantine General Problem". Consequently, DLTs that solve that problem and can deal with a certain number of divergent nodes are called "byzantine fault tolerant".


For Decard's platform two innovative "protocols" (meaning sets of rules about the communication between different software entities) enable a fast, secure, reliable consensus (which is also most efficient in terms of required storage capacity, internet bandwidth and energy consumption). This consensus is highly byzantine fault tolerant, as it still functions with up to 1/3 of all nodes being out of sync or not playing by the rules.


The first of those two protocols, developed and patented by Decard, is called the "Wavefront" protocol. It swiftly conveys by how much two local versions of the database differ from each other, and then enables the two communicating nodes to efficiently synchronise their local versions. This includes contracts/transactions that were submitted to the communicating nodes since the last epoch, but also the contracts/transactions submitted to other nodes which the either of the communicating nodes has already heard about.


The second protocol then establishes consensus not by comparing the databases themselves, but by tracking the level of shared knowledge that nodes communicate about in the wavefront protocol. This consensus protocal was originally developed and patented by Leemon Baird (co-founder of Hedera), but released under an open-source license and called the "Hashgraph consensus algorithm".


Together, the two protocols ensure that the communication between nodes (about what contracts they received and what other contracts they have heard about) relates directly to the state of the shared database. From the communication history, each node can reconstruct by and for itself what others in the network have changed and what changes they were told about. Once information about new transactions (since the last epoch) has spread to enough (2/3+1) nodes in the network, an new epoch is concluded and each node makes it's final calculation of the new state of the database.


In this way, the wavefront and hashgraph protocols guarantee a shared and immutable agreement about new transactions to be added to all copies of the database. And the order of those new transactions is established by the means of the timestamps at which all nodes have first heard about a given transaction. We call this "fair ordering", as it cannot be manipulated by node operators or distorted by the amount of fees offered by users.


Finally, each node calculates a signet of the new version of their database. These signets are hashes of the whole database and here called "bullseyes". Comparing them across the network for any given epoch will quickly flag up nodes that had fallen out of sync. The subsystems will also send their bullseyes for each epoch to the Tagoin Mainnet, where it is recorded to form a continuous audit trail of the Subsystem's accurate operation. Because of Decard's patented database design (called "DART" which stands for Distributed Archive of Random Transactions), the calculation, sharing and storage of a bullseye requires only minimal computing resources.


Another unique design feature of Decard's database (maintained locally by nodes but synchronised across the network as described above), is that all entries and edits have an "owner", which the user who specified the contract that created the entry. Access rights to each data entry can be managed like the file permissions in a conventional computer system (e.g. read, write, own).
In this regard, rules concerning privacy, anonymity and security can be determined individually for each (type of) entry, or for each Subsystem database, depending on it's particular use-case. Only for transactions of "TGN", the native utility token on the Tagion Mainnet, the rules are fixed (always revealing the amounts of the transactions, but not the identity of the actors, e.g. payer and payee).


In a Subsystem, the actors can be made visible (only to the participants of that Subsystem or more widely), but the content kept in the Subsystem 's own database can be protected as appropriate for the use-case or industry. The level of data-protection here can be set to be compliant with any privacy and data-protection regulation or even up to government agency levels of classification - including but not limited to access-control, authentication and sharing services, or multi-signature requirements.


Each Subsystem thus benefits from having a distributed database, shared and synchronized across a freely defined set of participants (a "permissioned" networks). And each Subsystem can freely determine its own rules and governance as needed. The only mandatory information shared with the Tagion Mainnet is the regularly calculated bullseye-signet.


This is why the Mainnet is said to fulfill the function of a "public notary" to it's federated Subsystems. But "public" here goes beyond any nation states public institutions and power. The governance rules and protocols of the Tagion nodes make its Mainnet "decentralised", meaning no entity owns or controls the network and anybody can participate. Thus, the trust and reliability provided by the Decard's platform extends beyond the boundaries of public and private, nation states or industries.

[Last paragraph to come: something about scalability (number of transactions, speed of finality, energy consumption).]


