# Why Sybil Resistance Matter


In decentralized networks, security concerns arise not only from traditional attack vectors but also from threats unique to their structure. One such threat is the Sybil attack. A sybil attack, coined by John R. Douceur, refers to “an attack wherein a single entity masquerades as multiple entities or nodes within a network to gain a disproportionately high influence within the network or to subvert the network’s operation altogether.”  An illicit actor, accordingly, creates multiple pseudonymous identities to manipulate or control the network. If successful, Sybil attacks can disrupt consensus, manipulate governance decisions, and ultimately undermine the integrity of the system. 

To counter the threat of Sybil attacks, decentralized systems implement Sybil resistance mechanisms, which define who can participate in both the consensus protocol (link) and the governance protocol (link). The consensus protocol establishes how nodes achieve agreement, ensuring a unified view of the network. In the case of Tagion, this specifically pertains to how nodes reach consensus on the ordering of events and the state of the database. Meanwhile, the governance protocol dictates how community members collaborate and make decisions on the future of the network. 

The sybil-resistance mechanism of Tagion should address both vectors, safeguarding not only the operational integrity of the data but also the fairness and legitimacy of governance processes. Without addressing both, the network’s security and decentralization cannot be sustained. 

## Traditional Sybil Resistance Mechanisms 

Different networks adopt various strategies to mitigate the risks of Sybil attacks. Some, for instance, select validator nodes through a permissioned process, ensuring that each node is tied to a specific, verifiable identity and recognized by the network. These systems, known as permissioned networks (link), offer a controlled and secure environment where participation is restricted to trusted entities. A prime example of this approach is Proof-of-Authority (PoA), where pre-approved validators are responsible for securing the network. 

In contrast, permissionless networks (link) operate without pre-approved validators, allowing anyone to participate in the validation process without prior authorization. In these systems, validator nodes are not predetermined or tied to a known identity. While this enhances inclusivity and censorship resistance, it also necessitates robust Sybil resistance mechanisms, such as Proof-of-Work (PoW) or Proof-of-Stake (PoS), to prevent malicious actors from gaining undue influence over the network. 

To understand how these permissionless systems work, consider the most widely adopted and recognized public blockchain networks, namely Bitcoin and Ethereum. 

## Bitcoin

Bitcoin uses PoW as its sybil resistance mechanism where miners compete by solving cryptographic puzzles to propose the next block. The miner who solves the puzzle first earns this privilege, ensuring that block production is based on real-world resource expenditure. The mechanism works to prevent Sybil attacks by making it computationally expensive for any one entity to create and control a significant share of the network's nodes. The amount of computational power required would be prohibitively high for an attacker to dominate the network and rewrite history.  

## Ethereum

In contrast, Ethereum 2.0 uses proof-of-stake (PoS) to guard against Sybil attacks. PoS works by requiring participants to lock up a certain amount of the network’s native cryptocurrency as a "stake" to validate blocks. Specifically, Ethereum requires 32 ETH to become a validator, nothing more, nothing less. The idea is that the more currency a participant stakes, the more likely they are to be chosen to validate transactions. This method makes Sybil attacks financially costly, as an attacker would need to acquire a significant amount of cryptocurrency to control a large portion of the network. Additionally, validators risk losing their stake through slashing penalties if they act maliciously, further discouraging dishonest behavior. 

It is worth mentioning that many PoS systems may either gradually evolve into or be deliberately designed as a form of Delegated Proof of Stake (dPoS). In such systems, individuals who lack the capital, hardware or knowledge necessary to operate a validator node can stake their funds with a delegate. These delegates pool resources and actively participate in consensus and, potentially, governance processes on behalf of the stakers, making the consensus process more open and accessible. 
