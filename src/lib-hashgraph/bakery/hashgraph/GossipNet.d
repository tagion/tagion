module bakery.hashgraph.GossipNet.

import bakery.hashgraph.Event;

interface GossipNet {
    void receive(ref immutable(EventPackage) epack);
    void send(ref immutable(EventPackage) epack);
}
