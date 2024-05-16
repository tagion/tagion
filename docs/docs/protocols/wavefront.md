# Wavefront

The wavefront protocol is an initiate exchange exchange protocol, used for gossip in the tagion hashgraph.

Node Alpha initiates a connections and sends it's initial height.  
Node Beta sends the difference between height and it's own height.  
Node Alpha sends the difference between calculated height Beta and it's own height.  

The ideas and goals of the wavefront protocol are better described in the Tagion whitepaper.
[tagion whitepaper](https://www.tagion.org/resources/tagion-whitepaper.pdf)*
![diagram explaining the wavefront from tagion whitepaper](/assets/wavefront.png)

The different wavefront exchange states are defined here.
[tagion.hashgraph.HashGraphBasic.ExchangeState](https://ddoc.tagion.org/tagion.hashgraph.HashGraphBasic.ExchangeState.html)

The wavefront record communicated between nodes is defined here.
[tagion.hashgraph.HashGraphBasic.Wavefront](https://ddoc.tagion.org/tagion.hashgraph.HashGraphBasic.Wavefront.html)

**Communication rules between a pair nodes**

*The nodes communicate over a single wire in a half-duplex style.*  
The priority of the rules are in the order they appear. A prior rule takes precedency over a later rule.  
The keywords MAY, SHOULD and MUST, indicate the severity of the rule.  
MAY means that the node is free to do this at will.  
SHOULD means that the node is strongly encouraged to do this, but the rule is NOT violated if not complied with.  
MUST means that the node is obliged to follow this rule.  

IF a node notices two simultaneous wavefront exchanges it MUST send a BREAKING WAVE.  
IF a BREAKING WAVE is exchanged the wavefront is reset.  
IF a BREAKING WAVE is exchanged the connection MUST be closed.  
IF a communication error or rule violation occurs the connection MUST be closed.  

A node MAY initiate a connection with any node.
A node which initiates a connection MUST send a message and it MUST sent the first message.  
A node MAY initiate a wavefront with any node which it does NOT already have an active wavefront exchange with  
The wavefront MUST be initiated by sending a TIDAL WAVE.  
The TIDAL WAVE MUST be responded with a FIRST WAVE.  
The FIRST WAVE MUST be responded with a SECOND WAVE.  
When a SECOND WAVE is exchanged the connection MUST be closed
A node SHOULD keep the connection open until a SECOND WAVE is exchanged.  
