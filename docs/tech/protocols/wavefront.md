# Wavefront

The wavefront protocol is an initiate exchange exchange protocol, used for gossip in the tagion hashgraph.

Node Alpha initiates a connections and sends it's initial known altitudes.  
Node Beta sends the difference between altitudes Alpha and it's own known altitudes.  
Node Alpha sends the difference between Betas calculated altitudes and it's own altitudes.  

The ideas and goals of the wavefront protocol are better described in the Tagion whitepaper.
[tagion whitepaper](https://www.tagion.org/resources/tagion-whitepaper.pdf)*
![diagram explaining the wavefront from tagion whitepaper](/assets/wavefront.png)

The different wavefront exchange states are defined here.
[tagion.hashgraph.HashGraphBasic.ExchangeState](https://ddoc.tagion.org/tagion.hashgraph.HashGraphBasic.ExchangeState.html)

The wavefront record communicated between nodes is defined here.
[tagion.hashgraph.HashGraphBasic.Wavefront](https://ddoc.tagion.org/tagion.hashgraph.HashGraphBasic.Wavefront.html)

The hirpc protocol is described here https://hibon.org/posts/hirpc

Each hirpc package is put in an [Envelope](/tech/protocols/envelope) which takes care of compression and encryption.

**Communication rules between a pair nodes**

*The nodes communicate over a single wire in a half-duplex style.*  
The priority of the rules are in the order they appear. A prior rule takes precedency over a later rule.  
The keywords MAY, SHOULD and MUST, indicate the requirement levels of the rule.
In accordance to https://datatracker.ietf.org/doc/html/rfc2119  
MAY means that the node is free to do this at will.  
SHOULD means that the node is strongly encouraged to do this, but the rule is NOT violated if not complied with.  
MUST means that the node is obliged to follow this rule.  

```
IF a communication error or rule violation occurs the connection MUST be closed.  
A node SHOULD keep the connection open until a hirpc result or an hirpc error is exchanged,
then the connection MUST be closed.  

A node MAY initiate a connection with any node.
A node which initiates a connection MUST send a message and it MUST sent the first message.  
The first message MUST be a hirpc method.  
Any hirpc method MUST be answered with another hirpc method OR a hirpc result OR a hirpc error.
```


**Wavefront response patterns**

```
method SHARP -> result COHERRENT | result RIPPLE
method TIDAL WAVE -> error | method FIRST WAVE
method FIRST WAVE -> error | result SECOND WAVE
* -> error  
```
