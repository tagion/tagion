---
sidebar_position: 2
---
# Genetics 

In Tagion, a new member is born through the mating of two existing members, mirroring biological reproduction, where parents contribute to the genetic identity of their offspring. Each new member receives a gene code, a unique cryptographic signature derived from the combined identifiers of both parents. This gene code determines the gene score, a measure of diversity that influences an identity’s ability to reproduce.  

Notably, before reproduction can occur, the offspring’s gene score must exceed a certain threshold, say 0.5. If it falls below this limit, the new identity is never instantiated, ensuring that only sufficiently diverse members are introduced into the system. 

To prevent a small group of interconnected entities from manipulating member creation, the system limits reproductive privileges based on gene score. Higher scores allow for greater reproductive capacity, encouraging decentralization, while lower scores reduce or entirely restrict reproduction, preventing identity farming and Sybil attacks. Though the gene score does not directly determine one’s influence in governance and consensus processes, it serves as a security mechanism, helping to prevent malicious actors from spawning multiple members.  

## Procreation Cycles 

Procreation cycles regulate the rate at which new members can be introduced into the network. Just as biological populations have natural constraints on reproduction, such as gestation periods, Tagion enforces controlled intervals between identity creation events. These intervals help regulate reproduction, blocking malicious entities from generating multiple identities to manipulate the network unfairly. 

One way to structure the reproduction model is by categorizing identities into three tiers, determining how frequently they can reproduce based on their gene scores: 

- Gene score > 2: Allowed to procreate twice per year, ensuring high-diversity identities contribute more to network growth. 

- Gene score between 1 and 2: Allowed to procreate once per year, maintaining a moderate but controlled expansion rate. 

- Gene score < 1: Procreation prohibited, preventing low-diversity identities from reproducing and reducing the risk of inbreeding and Sybil attacks. 

This is just one possible framework, but it illustrates how gene score can regulate identity creation in a structured and balanced manner. By weighting reproduction toward higher-diversity identities, the system naturally reinforces decentralization and Sybil resistance, preventing any small group from dominating the network through unchecked member creation. 

Notably, the length of the procreation interval directly impacts network security: 

- Shorter intervals accelerate expansion but increase vulnerability by allowing rapid member creation, which could be exploited for Sybil attacks. 

- Longer intervals enhance security by slowing identity creation, reducing the risk of centralization and manipulation but also moderating overall growth. 

To maintain optimal network balance, the length of these intervals may be dynamically adjusted by the [community](/gov/glossary#community) based on network conditions, such as community size and current security needs.  

## The Adam and Eve Cohort 

An initial group of ten pioneer members, akin to an 'Adam and Eve' cohort, will establish the community’s genetic foundation. These founding members will: 

- Set the genetic baseline for the network by forming the initial pool of cryptographic identities. 

- Act as the first "parents", enabling the creation of new members through controlled procreation cycles. 

As the network grows, the influence of these original members will naturally dilute through successive generations of identity creation, ensuring that no single entity or small group retains outsized control. Their primary role is to seed a diverse and resilient network, allowing the system’s genetic principles to naturally regulate decentralization and prevent manipulation. 

## Anti-Collusion Measures 

One potential vulnerability in the system is the possibility of a well-funded actor bypassing the intended decentralization safeguards by paying high-gene-score members to reproduce with its identities. While the procreation cycle already limits reproduction rates and encourages diversity, it does not fully prevent an attacker from strategically acquiring genetic influence over time. By continuously "buying" diversity, a malicious entity could maintain a strong reproductive presence in the network, ensuring that its influence remains intact across generations. Unlike traditional Sybil attacks, which rely on rapidly generating fake identities, this method takes a slower, more insidious approach—gradually consolidating control while appearing to comply with the system's rules. 

To address this, the system could introduce diminishing returns on genetic influence over generations. If two identities repeatedly reproduce, the genetic score of their offspring could be slightly degraded, reducing their reproductive potential. This would make it increasingly difficult for an attacker to maintain control through repeated strategic pairings, as their ability to sustain high gene scores would erode over time. Additionally, if an entity is suspected of orchestrating such a scheme through repeated suspicious pairings, the community itself could be given the authority to intervene. A decentralized governance mechanism could allow members to collectively vote to "kill" an identity—effectively revoking its membership—if there is strong evidence of collusion. This would introduce a social layer of security, ensuring that even if an attack is mathematically possible, it remains socially unacceptable and easily countered by the broader network. 
