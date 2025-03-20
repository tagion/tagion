---
sidebar_position: 2
---
# Thoughts on "Recentralization" 

What we here call "re-centralisation" refers to the process of capital and power concentrating within decentralized networks, weakening DLT security by increasing fragility and susceptibility to exploitation. The accumulation of power makes networks prone to external pressures, manipulation, attacks, and censorship, undermining their trustless, decentralized nature and pushing them closer to the centralized models they were meant to replace.  

## Issues with Proof of Work 

While Proof of Work (PoW) might initially offer effective defenses against Sybil attacks by making it costly for a single entity to gain control over the network, it inadvertently leads to a form of centralization, where wealth and power accumulate among a small number of participants, the so-called Matthew effect, ultimately undermining the very principles of decentralization and security DLT systems are designed to uphold. 

In PoW systems like Bitcoin, the barrier to Sybil attacks is the need for immense computational power. However, this requirement tends to favor those with access to specialized mining hardware and cheap electricity. Large mining operations dominate the network by winning more block rewards due to their greater resources. Over time, these entities reinvest their earnings to further expand their mining capacity, creating a feedback loop that concentrates mining power in the hands of a few major players.  

As such, while anyone is free to mine Bitcoin, in practice, economies of scale create a de facto barrier to entry. Competitive mining requires the latest ASIC hardware, access to cheap electricity, and large-scale operations to remain profitable. Smaller miners struggle to compete, leading to the dominance of industrial-scale mining farms that concentrate hashing power in the hands of a few.  

This centralization of computational power weakens the decentralized nature of the network and shifts influence to a small group of miners, often clustered in regions with favorable electricity costs and regulatory conditions. As a result, these geographic concentrations create a new vulnerability—a state actor could exert control over mining pools, enforce compliance, or even seize mining facilities, effectively compromising the neutrality of the network. Beyond regulatory influence, there is also the risk that a state actor with sufficient financial resources could control enough hashrate in PoW to dominate consensus outright. 

 

## Issues with Proof of Stake

While PoS networks avoid the energy-intensive process of mining, and thereby the self-reinforcing dynamic of capital and power concentration, they remain susceptible to a form of centralization—one that disproportionately benefits capital-intensive participants. 

In most PoS systems, validators must stake a minimum amount of native tokens to participate in consensus. For example, if the required stake is €50,000 worth of tokens, a large portion of users would be priced out of the validation process, concentrating power in the hands of wealthy individuals and institutions. 

But while PoS does not increase wealth inequality in relative terms—since returns on staking scale proportionally to the amount invested—it widens the gap between stakers and non-stakers. Those who can afford to stake earn additional rewards, reinforcing their position within the network, while non-stakers miss out on these benefits. Over time, this dynamic creates a growing divide, making it increasingly difficult for non-stakers to participate on equal footing. 

Thus, PoS naturally centralizes capital and power over time. This, in extension, introduces another problem. As such, many large validators operate under regulatory oversight, which makes them susceptible to government pressure, enabling state actors to censor transactions, blacklist addresses, or manipulate governance decisions. 

Beyond regulatory influence, a state actor with sufficient financial resources could also accumulate enough stake to dominate consensus outright. 

## Issues with Delegated PoS 

To counteract this centralizing tendency, DPoS protocols introduce a solution that redistributes participation. In DPoS systems, small token holders can delegate their stake to a validator, pooling their resources with others to collectively participate in the consensus process. Instead of requiring every individual to meet a high staking threshold, delegators take on the role of representatives, validating transactions on behalf of those who stake with them. This lowers the barrier to entry, ensuring that even capital-constrained investors can engage in staking and earn rewards without directly operating a validator node. At the same time, stakers retain full control over their delegated stake, with the ability to reassign their tokens to a different validator if their chosen delegator acts against their interests. 

But while DPoS enhances accessibility, it also introduces a new layer of governance and consensus risks, as delegators amass significant influence and may collude to push through malicious decisions or transactions. In this regard, it is important to highlight that it is the staker, not the delegator, who ultimately bears the financial risk if a validator acts maliciously, what is commonly referred to as a principal-agent problem. Since validators operate on behalf of delegators, any misconduct can result in slashing penalties, where a portion of the staked funds is forfeited. 

To make matters worse, stakers often gravitate toward staking protocols that offer Liquid Staking Tokens (LSTs) in return for their staked assets. These LSTs act as tradeable, liquid representations of staked assets, allowing users to use DeFi services while still earning staking rewards. Stakers can for instance use LSTs as collateral in decentralized lending protocols or trade them on secondary markets, thus combining staking rewards with other yield-generating activities. 

However, while LSTs enhances capital efficiency, they also introduce a significant centralization risk. Since large staking protocols tend to attract the majority of stake—offering higher liquidity, better integrations, and thus greater convenience—they become increasingly dominant. Over time, this creates a concentration of power, as these protocols—rather than individual stakers—decide how staked assets are distributed among validators. 
