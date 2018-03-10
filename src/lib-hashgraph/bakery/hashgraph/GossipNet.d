module bakery.hashgraph.GossipNet;

import bakery.hashgraph.HashGraph;

interface GossipNet {
    alias HashGraph.EventPackage EventPackage;
    void receive(ref immutable(EventPackage) epack);
    void send(ref immutable(EventPackage) epack);
}
