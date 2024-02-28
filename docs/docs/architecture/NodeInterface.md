# Node Interface Services

This service is responsible for handling and routing requests to and from the p2p node network.

All the package information is in **HiPRC** format.

The Node interface services relays the HiRPC between three  services (*EpochCreator, Replicator, DART*) depended on the HiRPC(Method) or the services deriven key.

All HiRPC should be signed and contain a pubkey.

```mermaid
sequenceDiagram
    participant EpochCreator 
    participant DART
    participant Replicator 
    participant NodeInterface
	EpochCreator ->> NodeInterface: HiRPC(Wavefront)
	NodeInterface ->> P2P: Document(Wavefront)
	P2P ->> NodeInterface: Documen(Wavefront)
	NodeInterface ->> EpochCreator: HiRPC(Wavefront)
	P2P ->> NodeInterface: HiRPC(Request-recorder)
	NodeInterface ->> Replicator: Request-recorder
	Replicator ->> NodeInterface: HiRPC(Response)
	NodeInterface ->> P2P: HiRPC(Response)
	P2P ->> NodeInterface: HiRPC(DART(ro))
	NodeInterface ->> DART: HiPRC(DART(ro))

	DART ->> NodeInterface : Response(DART)
	NodeInterface ->> P2P: Response(DART) 

```
