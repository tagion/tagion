---
sidebar_position: 3
---

# Token Economy

This governance area covers everything to do with our native network taken, the TGN. Eventually it will describe everything from its purpose to its issuance and limitations. Quite a bit has already been published about that in our ["Tokenomics Paper"](https://www.tagion.org/resources/tagion-tokenomics.pdf), and until its content has been transferred and superseded by what you find here, please download and consult it at the link above. 

For now, read on below and find an overview of the elements of our token economy already covered in the menu on the right hand side. 

## Fees and Rewards 

Contributors ([see Glossary](/gov/glossary#contributors)) play a vital role in ensuring the sustainability and growth of the Tagion network. Their efforts span across maintaining and safeguarding the network’s security, efficiency, and reliability; driving its evolution by implementing upgrades, addressing vulnerabilities, and introducing new features; and fostering adoption by creating educational materials and onboarding users.

The Tagion network’s success depends on the ongoing participation of contributors. However, without an adequate reward model in place, there is a risk that participation could decline over time. Contributors typically invest significant time, expertise, and resources into maintaining and improving the network. If these efforts are not recognized and rewarded, contributors may reduce their involvement or disengage entirely, posing a threat to the network’s robustness, stability, and ability to evolve. 

While some individuals or entities may contribute out of goodwill, ideological alignment, or interest in supporting their own applications, these motivations may not be sufficient to ensure sustained long-term participation. To ensure the network's continued resilience and performance, it is essential to establish a framework that both acknowledges the value of contributors' work and incentivizes their long-term engagement. This framework should aim to compensate contributors fairly for their efforts, ensuring they remain motivated. 

A key tool for ensuring the continued participation of contributors is the use of the network’s native token, TGN, as a form of compensation. TGN can serve as both an incentive and a mechanism to align contributors’ interests with the network’s growth. By compensating contributors in TGN, their success becomes directly tied to the network's adoption and value appreciation, encouraging long-term engagement and ongoing contributions to the network. 

## The Treasury 

The Tagion Treasury will serve as the primary source of compensation for contributors, utilizing its holdings of TGN tokens to fund ongoing network operations. Initially, the Treasury will draw from its allocated TGN reserves to support the system and reward contributors. However, since these reserves are finite, the Treasury cannot sustain the network indefinitely through this allocation alone. 

In the event that the Treasury exhausts its initial holdings, the Community could opt to issue new TGN tokens to cover expenses. However, issuing additional tokens would dilute the existing supply, which may not be in the interest of the community. To avoid this outcome, a sustainable and balanced funding model should be established well before the Treasury’s reserves are depleted, ensuring the network's long-term sustainability. 

The proposed model assumes that users will ultimately cover the ongoing costs of compensating relevant contributors through usage fees, which will be paid into the Treasury and then distributed to node operators, developers, and other contributors. 

From the Treasury's perspective, fees will be accumulated through three primary channels, namely: 

+ Execution Fees ([see below](#execution-fees))

+ Storage Fees ([see below](#storage-fees))

+ Subsystem Taxes ([see below](#subsystem-tax))

Fees paid by users through one of the above four channels establish a direct link between the network's utility and the resources required to maintain and improve it. By aligning the cost of upkeep with the network's usage, this model ensures that those who derive value from the network contribute proportionally to its maintenance. 

In this way, the Tagion Treasury will transition from relying solely on its initial reserves to a more self-sustaining model, where ongoing operational costs are funded by the network’s users. This reduces dependency on finite reserves and avoids the need to dilute the token supply, promoting a healthier, long-term economic framework for the network. 

![flow](/img/Treasury_inflow_outflow.png)

## Administered Pricing 

In economics, it is commonly assumed that prices are determined through the dynamics of supply and demand, with imbalances between the two driving prices either upward or downward. While this theory may seem intuitively appealing and therefore has gained a strong foothold within the orthodoxy of economics, it often fails to hold up against empirical evidence. In reality, companies often administer prices by setting them deliberately and strategically, rather than passively responding to market forces. Many companies, said differently, are price-makers, not price-takers. 

Prices are typically adjusted through pre-determined policies that account for expected costs, desired mark-ups and profits, rather than fluctuating in response to immediate market conditions. In many cases, companies maintain price stability even in the face of temporary shifts in supply or demand, opting to absorb short-term losses or gains to preserve customer relationships and market share. 

In line with this reasoning, it is here proposed that prices — including both rewards and user fees — within the Tagion Network will be strategically administered — and universally applied — by the community to reflect its collective values and priorities, rather than left to fluctuate according to market forces.   

When it comes to user fees, this approach would offer clear benefits to users by reducing fee volatility. Unstable fees introduce uncertainty, which can deter participation and ultimately pose a threat to the network’s long-term usability and growth. 

Similarly, rewards will be subject to strategic administration, and for good reason. Allowing contributors to determine their own rates through open competition poses significant risks to the network’s stability and security. Take, for instance, the case of node operators. In a competitive environment, some node operators may consistently undercut smaller ones, leading to centralization of control over the network's consensus process. Over time, this dynamic can compromise the network’s security by increasing the influence of a few large entities and discouraging smaller operators from participating. The result would be reduced decentralization and security. 

Both user fees and rewards are accordingly assumed to be administered by the community through decision-making [link] processes. Therefore, it is neither feasible nor appropriate to impose rigid rules on their exact values or methods of determination. Nevertheless, we can put forward some ideas on how fees and rewards could be determined, offering a framework for setting appropriate pricing while suggesting an initial fee structure. 


## Determining Rewards 

Given that the core objective of this exercise is to ensure the network’s long-term viability, security, and accessibility through adequate compensation of contributors, it is prudent to begin by assessing the expected rewards to be paid out. The starting point for this calculation is for the community to align on both the number and types of contributors required to keep the network operational, as well as the appropriate amount of TGN to be allocated as compensation for each role. 

For our purposes, let us assume the community intends to maintain a network consisting of 100 Core Node Operators ([see Glossary](/gov/glossary#nodes)), 50 Relay Node Operators ([see Glossary](/gov/glossary#nodes)), 50 Mirror Node Operators ([see Glossary](/gov/glossary#nodes)), and 5 full-time Developers ([see Glossary](/gov/glossary/index.md#contributors)). With this setup in mind, it becomes essential to estimate the average compensation required for each of these roles to cover their expenses and ensure fair remuneration. In practice, the community may choose to estimate these costs by consulting directly with contributors to gather realistic insights into their compensation needs, or they may opt to set reward levels at amounts deemed collectively reasonable.  

For now, let us just assume that Core Node Operators are compensated with the equivalent of $300 in TGN per month to cover costs such as hardware, energy, and maintenance, while also ensuring a modest profit margin. Similarly, each Relay Node Operator is compensated with the equivalent of $150 in TGN per month, each Mirror Node Operator receives the equivalent of $100 in TGN per month, and each full-time Developer is paid the equivalent of $10,000 in TGN on average. 

Based on these assumptions, the total estimated monthly rewards would amount to $92,500 in TGN equivalent. This figure serves as a baseline for understanding the Treasury’s financial obligations and provides a foundation for setting user fees that will allow the Treasury to remain sustainable and well-funded over time. 

## Determining Fees 

Fees, collected through one of three defined channels ([see above](#the-treasury)), are deposited into the Treasury and subsequently distributed to compensate contributors, ensuring the network’s sustainability and growth. These fees must strike a balance, ensuring the network’s sustainability while maintaining its accessibility and security.  

Fees set too low risks leaving the Treasury underfunded, potentially depleting its resources over time and making it unable to fairly compensate contributors—or forcing the community to dilute the supply of TGN. They could also undermine the demand for TGN. If users are not required to pay meaningful fees, demand for the token may drop, creating a feedback loop of declining token value, reduced contributor incentives, and weakened network security and resilience, thereby threatening the network’s long-term sustainability. Finally, setting fees too low could inadvertently make it both easy and inexpensive to flood the network with spam. This could strain resources and compromise the overall efficiency of the network. 

Conversely, excessively high fees could deter users, reducing the adoption of the network. As usage costs rise, participation is expected to decline, lowering demand for the native token as individuals and entities refrain from using the network. 

Self-evidently, the user fee should therefore strike a balance, being neither too low nor too high. Additionally, the community must consider the Treasury’s financial health. If the goal is to ensure the Treasury remains sustainable and well-funded indefinitely, its inflow of TGN must, at a minimum, match or exceed its outflow, expressed as: 

![in-out](/img/Iflow-outflow.png)
 

Assuming that the Treasury’s primary outflow of TGN is allocated to compensating contributors, while its primary inflow consists of user fees, it follows that the total user fees collected over a given period must, at a minimum, match or exceed the rewards distributed to contributors if the Treasury is to run a surplus, expressed as: 

![reward](/img/Fees-rewards.png) 

Having established the rewards in our hypothetical scenario as $92,500 in TGN equivalent, and assuming the community decides to run a surplus, we can now conclude that: 

 ![total](/img/Fees-92.500.png)

To run a surplus, the Treasury must therefore acquire more than 92,500 TGN per month through the inflow of user fees. Naturally, and as previously mentioned, this approach would not be feasible in the initial stages, as execution volumes, storage usage, relay requests, and subsystem usage would be minimal. Consequently, the Treasury would need to rely on its pre-allocated TGN reserve to bridge the gap. 

For now, let us summarize by emphasizing that, in setting the fee, the community should carefully consider all relevant factors—namely, the financial health of the Treasury, accessibility for users, and the efficiency and security of the network. With these considerations in mind, the community should establish an appropriate fee structure for each of the four channels (link). 

While the Treasury primarily funds Mainnet contributors, it is assumed that node operators within Subsystems will also be compensated in TGN for their contributions. However, unlike Mainnet rewards, these payments will not need to pass through the Treasury, allowing for a more direct and independent reward structure for Subsystem operators. 

## Fee Channels 

In the Tagion ecosystem, users will initially have four channels through which they can contribute TGN to the treasury. Three of these channels—Execution Fees, Storage Fees, and Relay Fees—are tied to operations conducted on the Mainnet. The fourth, Subsystem Taxes, applies to operations within Subsystems and is designed to ensure that Subsystems fairly compensate Mainnet Nodes for the critical role they play in providing security to these Subsystems. 

### Execution Fees 

Execution Fees are charged when instructions are submitted for processing. Each execution consists of one or more instructions, and these instructions require computational power. The total cost depends on both the complexity of each instruction and the number of instructions included in the execution. Some instructions require very little processing power, while others are more demanding. Additionally, the number of instructions processed together can vary, which further impacts the total computational load. 

To account for this, Quarks [working title] are used as a unit to measure the computational resources consumed by each instruction, with a computational load counter keeping track of the total Quarks used across all instructions in an execution. The total execution fee is determined based on the number of Quarks recorded by the load counter, ensuring that users are charged according to the actual computational resources consumed. 

_The price will be administered but will initially be set at x TGN per unit of Quark._

### Storage Fees 

Storage Fees, which include fees for operations that allocate network storage resources, such as storing transaction histories, documents, or user data. To account for these ongoing and cumulative demands, a storage unit, referred to as Byte(s), will measure the volume of data being stored. Storage costs will also depend on the length of time the data remains on the network, reflecting the long-term burden it imposes. The storage unit ensures precise measurement of resource use, where smaller datasets incur lower initial costs, while larger files require greater fees. The length of storage adds an additional dimension, with periodic charges applied for data retention over time.  

Storage costs incentivize efficient use of storage space, such as compressing data or deleting unnecessary records, to avoid bloating the system. It ensures that those utilizing the network for persistent data storage contribute fairly to its maintenance and scalability. 

_The price will be administered but will initially be set at x TGN per Byte times x per month._

### Subsystem Tax 

As autonomous and self-governing entities, Federated Subsystems operate independently and are not subject to direct control by the mainnet. However, the mainnet will require them to provide fair compensation in exchange for the security services it offers. This fee, known as a Subsystem Tax, consists of two channels: 

+ **Ecosystem Tax** – A predetermined, fixed fee—paid weekly, monthly, or annually—for operating a Subsystem that is connected to and interacts with the Tagion Ecosystem, which includes both the Mainnet and other Subsystems. This tax is designed to account for the benefits and resources provided by the ecosystem, such as security, interoperability, software, and network infrastructure. 

_The Ecosystem Tax will be administered but will initially be set at x TGN per month.-

+ **Usage Tax** – A tax that is incurred for each execution. Notably, the tax rate should be a fraction of the execution fees on the mainnet. This reflects the reality that subsystems primarily depend on Mainnet nodes for security rather than full computational processing. In other words, while subsystems leverage the Mainnet’s security infrastructure, they do not place the same level of computational burden on it. As a result, the execution fees for subsystems are set lower to account for their reduced reliance on Mainnet resources. 

_The Execution Tax will be administered but will initially be set at x Ticket (link) per unit of Quark._

The community, as mentioned, is responsible for determining and administering the tax rates, ensuring they reflect the collective needs and preferences of its members. This includes both the ecosystem tax and the execution tax, which should be balanced to achieve two key objectives: 

1. **Fair Compensation of contributors** – The tax rates should be set high enough to adequately reward contributors for their efforts and resource contributions. 

2. **Encouraging Subsystem Adoption** – Tax rates must remain low enough to avoid discouraging individuals and businesses from creating or utilizing Subsystems. Excessively high rates could deter adoption and push more activity onto the Mainnet, leading to increased congestion, inefficiencies, and a heavier computational burden on the Mainnet.

### Tickets 

The Execution Tax is payable exclusively in what we call "Tickets". So, what is a Ticket? 

A Ticket is purchased through a smart contract managed by the Treasury. By paying 1 TGN into the smart contract, a Subsystem will receive 1 Ticket in return. So why use Tickets instead of TGN? 

Tickets are preferred for the simple reason that they enable execution taxes to be paid by subsystems without overburdening the Mainnet. If subsystems were required to settle execution taxes in TGN, each execution within a federated subsystem would need to be mirrored by a corresponding execution on the Mainnet. This duplication would increase the computational load on Mainnet nodes, driving up operational costs and reducing the overall efficiency of the network. 

With Tickets, we can implement a simple counter on each subsystem to measure the computational load of every execution, automatically burning the equivalent amount in Tickets stored within a smart contract. As such, users do not need to acquire Tickets themselves to transact within subsystems, as the process is fully automated. The subsystem, as a whole, however, would be required to store the necessary Tickets. 
