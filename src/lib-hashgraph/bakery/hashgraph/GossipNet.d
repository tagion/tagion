module bakery.hashgraph.GossipNet;

import bakery.hashgraph.HashGraph;

interface GossipNet {
    alias HashGraph.EventPackage EventPackage;
    void receive(ref immutable(EventPackage) epack);
    void send(ref immutable(EventPackage) epack);
    alias bool delegate(immutable(ubyte[])) Request;
    // Request a missing event from the network
    // add
    void request(immutable(ubyte[]) event_hash, Request add);

}
