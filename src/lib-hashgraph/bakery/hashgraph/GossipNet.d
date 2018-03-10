module bakery.hashgraph.GossipNet;

import bakery.hashgraph.HashGraph;

interface GossipNet {
    alias HashGraph.EventPackage EventPackage;
    void receive(ref immutable(EventPackage) epack);
    void send(ref immutable(EventPackage) epack);
    // Request a missing event from the network
    void request(immutable(ubyte[]) event_hash);

}
