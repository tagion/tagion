# Tagion Network Architecture

## Description of the services in a node
A node consist of the following services.


* [tagionwave](/src/bin-wave/README.md) is the main task responsible all the service
* [Logger](/documents/acrhitecture/Logger.md) takes care of handling the logger information for all the services.
* [LoggerSubscription]() The logger subscript take care of handling remote logger and event logging.
* [TagionFactory](/documents/architecture/TagionFactory.md) This services takes care of the *mode* in which the network is started.
* [Tagion](/documents/architecture/Tagion.md) is the service which handles the all the services related to the rest of the services (And run the HashGraph).
* [TVM](/documents/architecture/TVM.md) Virtual machine for executing the smart contract functions.
* [DART](/documents/architecture/DART.md) Takes care of the handling data-base instruction and read/write to the physical file system.
* [DARTSync](/documents/architecture/DARTSync.md) Handles the synchronization of the DART to other remote nodes.
* [Recorder](/documents/architecture/Recorder.md) Handles the recorder chain (A Recorder is the write/remove sequency to the DART).
* [Transaction](/documents/architecture/Transaction.md) Handles the validation of a smart contract before it is send to the HashGraph.
* [Consensus](/documents/architecture/Consensus.md) Executes transactions in the epoch produced by the HashGraph and generates a Recorder.
* [Transcript](/documents/architecture/Transcript.md) Executes transactions in the epoch produced by the HashGraph and generates a Recorder.
* [EpochDump](/documents/architecture/EpochDump.md) Write the Epoch to a file as a backup.
* [Monitor](/documents/architecture/Monitor.md) Monitor interface to display the state of the HashGraph.
* [Consensus](/documents/architecture/Consensus.md) HashGraph consensus services.
* [P2P](/documents/architecture/P2P.md) is used to connect the p2p network.
* [Register](/documents/architecture/Register.md) Register for the task and services.


The arrow indicates ownership is means of service-A points to service-B. Service-A has ownership of service-B.

This means that if Service-B fails service-A is responsible to handle and take-care of the action to restart or other action.
```graphviz
digraph G {
rankdir=UD;
  compound=true;
  labelangle=35;
   node [style=filled]
  node [ shape = "rect"];
  DART [shape = cylinder]
  Network, Extern [ style = rounded];
  Extern [ style=filled fillcolor=green ];
  Network [ style=filled fillcolor=red]
  Transaction [shape = signature]
  Transcript [shape = note]
  Consensus [label="Consensus\nHashgraph"]
  subgraph cluster_1 {
    peripheries=0;
    style = rounded;
    Extern -> Transaction [label="HiRPC(contract)" color=green];
 	Transaction -> Collector [label=contract color=green];
	Collector -> TVM [label=contract color=green];
	TVM -> Consensus [labelangle="45" label=contract color=green];
	Consensus -> Collector [label=contract color=darkgreen];
	Consensus -> Transcript [label=epoch color=green];
    Collector -> Transcript [label=archives color=red];
  };
  subgraph cluster_2 {
    peripheries=0;
	DART;
    style = rounded;
  };
  subgraph cluster_3 {
    peripheries=0;
    style = rounded;
	Recorder -> DARTSync [label=recorder color=blue dir=both];
	DARTSync -> P2P [label=dartcmd dir=both color=magenta];
	P2P -> Network [label=HiBON dir=both];
  };
  DART -> DARTSync [label=dartcmd dir=both color=magenta];
  DART -> Collector [label=archives color=red];
  Consensus -> P2P [label=gossip dir=both color=cyan4];
  Transcript -> DART [label=recorder color=blue];
}
```
```graphviz
digraph G {
    edge [lblstyle="above, sloped"];
    a -> b [label="ab"];
    b -> c [label="bc"];
    c -> a [label="ca"];
}
```

### Tagion Service Hierarchy

```graphviz
digraph tagion_hierarchy {
    rankdir=UD;
    size="8,5"
   node [style=filled]
Tagionwave [color=blue]
DART [shape = cylinder]
Transaction [shape = signature]
Transcript [shape = note]

p2p [shape = circle];
    node [shape = rect];
FileDiscovery [color=pink]
MDNSDiscovery [color=pink ]
ServerFileDiscovery [color=magenta]

Tagionwave -> Logger -> LoggerSubscription;
	Tagionwave -> TagionFactory;
	TagionFactory -> Tagion;
	Tagion -> DART;
	Tagion -> DARTSync;
	Tagion -> Recoder;
	Tagion -> Transaction;
	Tagion -> Transcript;
	Tagion -> EpochDump;
	Tagion -> Monitor;
	Tagion -> p2p ;
	p2p -> NetworkRecover;
	NetworkRecover -> FileDiscovery;
	NetworkRecover -> MDNSDiscovery;
	NetworkRecover -> ServerFileDiscovery;

}
```

### Information flow between the services.

The arrows should the most import communication between the services.

All services can send logger data to the Logger server, which is not shown on the figure.

```graphviz
digraph tagion_hierarchy {
    rankdir=UD;
    size="8,5"
   node [style=filled]

P2PNet [shape = ellipse color = blue]
DART [shape = cylinder]
Transaction [shape = signature]
Transcript [shape = note]
Extern [share = rarrow color = green pos ="-1,0!" ]
libp2p [shape = doublecircle];
Consensus [label = "Consensus\nHashGraph"]
Recoder [sharp = tab];
{ rank = min; Extern; Transaction; Consensus; Transcript }

	Extern -> Transaction -> Consensus [ color = green];
	Consensus->libp2p [label = "gossip(HiRPC)" dir = both]
    Consensus -> Transcript [ label = Epoch color = green]
	Transcript -> DART [ label = Recoder color = green];
	DARTSync -> libp2p [label = HiRPC dir =both];
	DARTSync -> DART  [ label = HiRPC]
	DART -> DARTSync [ label = HiBON ]
	DART -> Recoder [ label = Recorder];
    DART -> Transaction;
	libp2p -> Transcript;
	libp2p -> P2PNet [dir = both color =blue];
}
```


### Update Tagion Service Hierarchy
```graphviz
digraph tagion_hierarchy {
    rankdir=UD;
    size="8,5"
   node [style=filled]
Tagionwave [color=blue]
DART [shape = cylinder]
Transaction [shape = signature]
Transcript [shape = note]
Collector [color=red shape=rect]
Consensus [label="Consensus\nHashGraph"]
node [shape = rect];
	Tagionwave -> Logger -> LoggerSubscription;
	Tagionwave -> TagionFactory;
	TagionFactory -> Tagion;
	Tagion -> P2PNetwork ;
	DART -> Recoder;
	Tagion -> DART -> DARTSync;
    Tagion -> Consensus;
	Consensus -> Transaction;
	Consensus -> Transcript;
	Consensus -> Collector;
	Transcript -> EpochDump;
	Consensus -> Monitor;
}
```

### Update information flow between the services.
This communication includes the Collector services
```graphviz
digraph tagion_hierarchy {
    rankdir=UD;
    size="8,5"
   node [style=filled]

P2PNet [shape = ellipse color = blue]
DART [shape = cylinder]
Transaction [shape = signature]
Transcript [shape = note]
Extern [share = rarrow color = green pos ="-1,0!" ]
libp2p [shape = doublecircle];
Consensus [label = "Consensus\nHashGraph"]
Recoder [sharp = tab];
Collector [color = red shape=rect]
{ rank = min; Extern; Transaction; Collector }

	Extern -> Transaction -> Collector [ color = green];
	Consensus->libp2p [label = "gossip(HiRPC)" dir = both]
    Consensus -> Transcript [ label = Epoch color = magenta]
	Transcript -> DART [ label = Recoder color = green];
	DARTSync -> libp2p [ label = HiRPC dir =both ];
	DARTSync -> DART  [ label = HiRPC]
	DART -> DARTSync [ label = HiBON ]
	DART -> Recoder [ label = Recorder];
    Consensus -> Collector [dir=both];
	DART -> Collector [label = Archive];
	Collector -> Transcript [color = green label=Archives];
	libp2p -> Transcript;
	libp2p -> P2PNet [dir = both color =blue];
}
```



