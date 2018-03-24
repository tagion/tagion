module bakery.hashgraph.GossipNet;

import bakery.hashgraph.HashGraph;
import bakery.hashgraph.Event;

@safe interface EventPackage {
}
@safe
interface GossipNet {
//    alias HashGraph.EventPackage EventPackage;
    void receive(ref immutable(EventPackage) epack);
    void send(ref immutable(EventPackage) epack);
    alias bool delegate(immutable(ubyte[])) Request;
    // Request a missing event from the network
    // add
    void request(HashGraph h, immutable(ubyte[]) event_hash);
    // This function is call by the HashGraph.whatIsNotKnowBy
    // and is use to collect node to be send to anotehr node
    bool collect(Event e, immutable uint depth);
    immutable(ubyte)[] eventHashFromId(immutable uint id);
}
