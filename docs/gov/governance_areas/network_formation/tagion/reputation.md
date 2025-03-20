# Reputation 

A high Gene Score (link) may grant a member the ability to reproduce more frequently, but it does not directly determine influence within the network. Influence is governed by reputation, which is built over time through peer endorsements. Members with higher reputation scores gain greater influence in consensus and decision-making processes, while those with low reputation remain less influential, regardless of their genetic diversity.  

Unlike the gene score, which is a fixed measure of diversity based on inherited attributes, reputation is dynamic and evolves over time. It is built through peer endorsements, where existing members validate and vouch for other members’ credibility. 

## Endorsement Power 

The more endorsements a member receives, the more trusted they become, increasing their reputation score. However, not all endorsements carry the same weight—the credibility of the endorser determines the impact of their endorsement. Endorsements from high-reputation members have higher impact, while those from low-reputation members have less impact. As such, reputation is not simply a numbers game, where many low-reputation accounts could collude to inflate someone's score, but rather a quality-driven metric. 

Whenever a member endorses another, they socially verify that identity, signaling their trust and confidence in them. The strength of this endorsement, known as endorsement power, is calculated as a percentage of the endorser’s own reputation score, determining how much influence their endorsement contributes to the recipient’s reputation.   

For example, if a member with a reputation score of 10 endorses another and the endorsement transfer factor is set at 10%, the recipient gains 1 reputation point from that endorsement. Similarly, if the endorser’s reputation score is 5, the endorsed member receives 0.5 reputation points. 

## Endorsement Rights 

To prevent reputation from being easily manipulated, each member is granted a fixed number of endorsement rights annually. This prevents members from freely endorsing an unlimited number of others, which could lead to inflation of reputation scores or coordinated manipulation.  

Furthermore, these rights are non-transferable and cannot be given to other members, preventing them from becoming a tradable commodity that could lead to corruption. Once a member uses an endorsement right, it is consumed and immediately reflected as an endorsement for the recipient, ensuring that endorsements remain meaningful and cannot be hoarded or exploited. 

## Diminishing Reputation 

To prevent excessive reputation accumulation, a cap on reputation scores may be introduced. Without limits, early members or highly endorsed individuals could continue growing their reputation indefinitely, making it difficult for new participants to gain influence. 

A reputation cap can take different forms. A fixed limit prevents members from exceeding a certain reputation score, ensuring influence remains distributed. Alternatively, a diminishing reputation model gradually reduces the impact of endorsements, making further growth increasingly difficult but not impossible. Rather than imposing a hard ceiling, a diminishing model allows highly reputable members to continue increasing their reputation while progressively limiting their influence over governance, consensus processes, and endorsement power. By curbing both their decision-making weight and their ability to amplify others' reputations, this would prevent concentrated control while still recognizing long-term contributions. 

## Erosion 

The reputation score easily risks becoming a static asset, enabling early members to retain power even if they become inactive or disengaged from the community. Over time, this could lead to entrenched hierarchies, where influence is based on past recognition rather than current contributions, undermining the system’s goal of maintaining a dynamic and merit-based reputation model. 

To prevent this, endorsements naturally erode over time unless they are actively renewed. This ensures that reputation remains a reflection of ongoing trust and participation rather than a legacy status. Members who remain active and continue to receive endorsements will sustain their reputation, while those who disengage will see their influence diminish. 

## Endorsement Renewals 

Endorsement renewals differ from endorsement rights—while endorsement rights govern the ability to endorse others, renewals serve as a counterforce to erosion, allowing community members to preserve and reaffirm trust in peers. 

As endorsements naturally decay over time, renewals allow members to reaffirm trust, preventing reputation from deteriorating purely due to the passage of time.  

Beyond merely maintaining reputation, it may also be considered if continued renewals can gradually strengthen the power of an endorsement. This can be used to acknowledge and reward sustained trust rather than fleeting interactions. A member who has consistently vouched for another over time will thus contribute more significantly to their reputation than one who offers only short-term validation.  

## Endorsement Incentives 

Members may be reluctant to use their endorsement rights, leading to stagnation in reputation distribution. Some may refrain from endorsing others due to a lack of engagement, similar to voter apathy, where individuals feel their participation has little impact or see no direct benefit. Others may strategically withhold endorsements, fearing that recognizing others will dilute their own influence, preferring to maintain an exclusive circle of reputable members rather than fostering a broader, more distributed reputation network. 

To counter this tendency, endorsing others should not only benefit the recipient but also contribute to the endorser’s own reputation score. Since endorsements signal trust and engagement, actively participating in the reputation-building process should be rewarded rather than treated as a zero-sum action. This can be achieved by granting endorsers a fractional increase to their own reputation when they use their endorsement rights, reinforcing the idea that strengthening the network strengthens their own standing within it.  

## Reputation Loss 

Reputation is built on trust, but it must also be subject to scrutiny. If a member is found to be engaging in malicious activities—whether through coordinated manipulation, endorsement fraud, or other forms of abuse—they risk having their membership suspended (link). However, accountability should not be limited to the individual alone. Since reputation is built through endorsements, those who vouched for a malicious actor may also face consequences if their endorsements contributed to an abuse of trust. Hence, a proportional penalty may also be applied to those who endorse malicious actors, discouraging reckless or fraudulent endorsements. This introduces a layer of social responsibility, where members must consider the credibility of those they vouch for rather than endorsing indiscriminately. 

However, while an endorser may face penalties for supporting a bad actor, this does not extend to others who it has endorsed. As such, a member losing reputation or being suspended does not impact the reputation scores of those they previously endorsed, as this could create a domino effect where the mistakes or misconduct of one individual ripple across the entire network. 

## Graph Analysis 

By analyzing the graph structure and identifying clusters, what is commonly referred to as cluster analysis, it becomes possible to detect patterns of collusion and Sybil attacks within the network. Clusters of nodes that exhibit unusually high internal connectivity but limited external endorsements may indicate coordinated manipulation, as genuine reputation networks tend to form more distributed and organic structures. 

The Security Council (link) is responsible for monitoring the network and investigating potential Sybil attacks or collusion. They can intervene when manipulation threatens the integrity of the reputation system. However, before taking any action, the Council must first verify that the detected anomaly is indeed an attempt to exploit the system. This, we envision, may include communicating with the suspected members, ensuring that interventions are based on strong evidence rather than algorithmic suspicion alone. 

 

## Weighted Participation Rights 

Participation in both the consensus process (link) and governance (link) requires verified community membership, meeting the criteria outlined in the Proof-of-Community section(link). Importantly, for both processes it follows that they are not governed by strictly egalitarian principles, meaning people do not participate on equal terms. Rather, participation rights are weighted based on the reputation score along with a set of metrics, as we define below: 

 

## Consensus 

Verified members can join the consensus process as active nodes, but they don't automatically become active. Instead, they need to be selected as active nodes. The likelihood of being selected depends on three factors: 

1. Reputation Score: A measure of how reliable or trustworthy the node is in the community, determined by its reputation score.<br />By factoring in reputation, the network ensures that nodes contributing positively to the community are more likely to be selected, preventing manipulation by newly created or colluding members.
2. Up-time: How long the node has been running without interruptions. Only nodes with an up-time of more than x% are even considered for selection, meaning the node must be consistently online and reliable.<br />High up-time ensures that only reliable and stable nodes participate in the consensus process, improving the network's overall performance and resilience.
3. Seniority: The amount of time the member has been part of the network.<br />This ensures that the network values long-term commitment. It helps mitigate the risk of newcomers with limited history quickly gaining influence, instead prioritizing experienced node operators who have proven their reliability over time.
4. Recent Participation: The amount of time that has passed since the node was last part of the active pool. This ensures that recently active validators undergo a mandatory timeout period before becoming eligible for selection again. By temporarily preventing nodes from immediately re-entering the active pool after serving as validators, the network promotes fair rotation and prevents the same nodes from continuously dominating consensus. 

Notably, the likelihood of being picked as an active node is determined by the combined weight of these four factors, which the community can adjust based on governance priorities. Greater emphasis on up-time favors stability, reputation strengthens trust-based selection, and seniority can either reinforce the status of long-time members or promote faster integration of new members. 

## Governance 

Members can join the governance process, but they don't participate on equal terms. Instead, the weight of their vote is reflective of their Reputation Scores. 
