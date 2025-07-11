---
sidebar_position: 2
sidebar_label: Pricing
---

# Administered Pricing 

In economics, it is commonly assumed that prices are determined through the dynamics of supply and demand, with imbalances between the two driving prices either upward or downward. While this theory may seem intuitively appealing and therefore has gained a strong foothold within the orthodoxy of economics, it often fails to hold up against empirical evidence. In reality, companies often administer prices by setting them deliberately and strategically, rather than passively responding to market forces. Many companies, said differently, are price-makers, not price-takers. 

Prices are typically adjusted through pre-determined policies that account for expected costs, desired mark-ups and profits, rather than fluctuating in response to immediate market conditions. In many cases, companies maintain price stability even in the face of temporary shifts in supply or demand, opting to absorb short-term losses or gains to preserve customer relationships and market share. 

In line with this reasoning, it is here proposed that prices — including both rewards and user fees — within the Tagion Network will be strategically administered — and universally applied — by the community to reflect its collective values and priorities, rather than left to fluctuate according to market forces.   

When it comes to user fees, this approach would offer clear benefits to users by reducing fee volatility. Unstable fees introduce uncertainty, which can deter participation and ultimately pose a threat to the network’s long-term usability and growth. 

Similarly, rewards will be subject to strategic administration, and for good reason. Allowing contributors to determine their own rates through open competition poses significant risks to the network’s stability and security. Take, for instance, the case of node operators. In a competitive environment, some node operators may consistently undercut smaller ones, leading to centralization of control over the network's consensus process. Over time, this dynamic can compromise the network’s security by increasing the influence of a few large entities and discouraging smaller operators from participating. The result would be reduced decentralization and security. 

Both user fees and rewards are accordingly assumed to be administered by the community through [decision-making](https://docs.tagion.org/gov/governance_areas/decision_making) processes. Therefore, it is neither feasible nor appropriate to impose rigid rules on their exact values or methods of determination. Nevertheless, we can put forward some ideas on how fees and rewards could be determined, offering a framework for setting appropriate pricing while suggesting an initial fee structure. 


## Determining Rewards 

Given that the core objective of this exercise is to ensure the network’s long-term viability, security, and accessibility through adequate compensation of contributors, it is prudent to begin by assessing the expected rewards to be paid out. The starting point for this calculation is for the community to align on both the number and types of contributors required to keep the network operational, as well as the appropriate amount of TGN to be allocated as compensation for each role. 

For our purposes, let us assume the community intends to maintain a network consisting of 100 Core Node Operators ([see Glossary](/gov/glossary#node)), 50 Relay Node Operators, 50 Mirror Node Operators (see here for different forseen [kinds of nodes](https://docs.tagion.org/gov/intro/network#nodes)), and 5 full-time Developers. With this setup in mind, it becomes essential to estimate the average compensation required for each of these roles to cover their expenses and ensure fair remuneration. In practice, the community may choose to estimate these costs by consulting directly with contributors to gather realistic insights into their compensation needs, or they may opt to set reward levels at amounts deemed collectively reasonable.  

For now, let us just assume that Core Node Operators are compensated with the equivalent of \$300 in TGN per month to cover costs such as hardware, energy, and maintenance, while also ensuring a modest profit margin. Similarly, each Relay Node Operator is compensated with the equivalent of \$150 in TGN per month, each Mirror Node Operator receives the equivalent of \$100 in TGN per month, and each full-time Developer is paid the equivalent of \$10,000 in TGN on average. 

Based on these assumptions, the total estimated monthly rewards would amount to \$92,500 in TGN equivalent. This figure serves as a baseline for understanding the Treasury’s financial obligations and provides a foundation for setting user fees that will allow the Treasury to remain sustainable and well-funded over time. 

## Determining Fees 

Fees, collected through one of the [defined channels](https://docs.tagion.org/gov/governance_areas/token_economy/fee_channels), are deposited into the Treasury and subsequently distributed to compensate contributors, ensuring the network’s sustainability and growth. These fees must strike a balance, ensuring the network’s sustainability while maintaining its accessibility and security.  

Fees set too low risks leaving the Treasury underfunded, potentially depleting its resources over time and making it unable to fairly compensate contributors—or forcing the community to dilute the supply of TGN. They could also undermine the demand for TGN. If users are not required to pay meaningful fees, demand for the token may drop, creating a feedback loop of declining token value, reduced contributor incentives, and weakened network security and resilience, thereby threatening the network’s long-term sustainability. Finally, setting fees too low could inadvertently make it both easy and inexpensive to flood the network with spam. This could strain resources and compromise the overall efficiency of the network. 

Conversely, excessively high fees could deter users, reducing the adoption of the network. As usage costs rise, participation is expected to decline, lowering demand for the native token as individuals and entities refrain from using the network. 

Self-evidently, the user fee should therefore strike a balance, being neither too low nor too high. Additionally, the community must consider the Treasury’s financial health. If the goal is to ensure the Treasury remains sustainable and well-funded indefinitely, its inflow of TGN must, at a minimum, match or exceed its outflow, expressed as: 

$$
Inflow \ge Outflow
$$
 

Assuming that the Treasury’s primary outflow of TGN is allocated to compensating contributors, while its primary inflow consists of user fees, it follows that the total user fees collected over a given period must, at a minimum, match or exceed the rewards distributed to contributors if the Treasury is to run a surplus, expressed as: 

$$
\sum{}Fees_t \ge \sum{}Rewards_t
$$

Having established the rewards in our hypothetical scenario as \$92,500 in TGN equivalent, and assuming the community decides to run a surplus, we can now conclude that: 

$$
\sum{}Fees_t \ge 92,500\ TGN_t
$$

To run a surplus, the Treasury must therefore acquire more than 92,500 TGN per month through the inflow of user fees. Naturally, and as previously mentioned, this approach would not be feasible in the initial stages, as execution volumes, storage usage, relay requests, and subsystem usage would be minimal. Consequently, the Treasury would need to rely on its pre-allocated TGN reserve to bridge the gap. 

For now, let us summarize by emphasizing that, in setting the fee, the community should carefully consider all relevant factors—namely, the financial health of the Treasury, accessibility for users, and the efficiency and security of the network. With these considerations in mind, the community should establish an appropriate fee structure for each of the four [fee channels](https://docs.tagion.org/gov/governance_areas/token_economy/fee_channels). 

While the Treasury primarily funds Mainnet contributors, it is assumed that node operators within Subsystems will also be compensated in TGN for their contributions. However, unlike Mainnet rewards, these payments will not need to pass through the Treasury, allowing for a more direct and independent reward structure for Subsystem operators. 

