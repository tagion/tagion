module tagion.hashgraph.GossipNet;

import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event;
import tagion.utils.BSON : R_BSON=BSON, Document;
alias R_BSON!true GBSON;

@safe
interface GossipNet {
    alias immutable(ubyte)[] Pubkey;
    alias immutable(ubyte)[] Privkey;
    alias immutable(ubyte)[] HashPointer;
//    alias HashGraph.EventPackage EventPackage;
    void receive(immutable(ubyte[]) data);
    void send(immutable(ubyte[]) data);
    alias bool delegate(immutable(ubyte[])) Request;
    // Request a missing event from the network
    // add
    void request(HashGraph h, immutable(ubyte[]) event_hash);
    // This function is call by the HashGraph.whatIsNotKnowBy
    // and is use to collect node to be send to anotehr node
//    bool collect(Event e, immutable uint depth);
    HashPointer eventHashFromId(immutable uint id);
    HashPointer calcHash(immutable(HashPointer) hash_pointer) inout;

//    immutable(ubyte[]) evaPackage();

//    void buildPackage(HashGraph hashgraph, GBSON bson, Event event, immutable uint node_id);

    ulong time();


    bool verify(immutable(ubyte[]) message, immutable(ubyte[]) signature, Pubkey pubkey);

    // The private should be added implicite by the GossipNet
    // The message is a hash of the 'real' message
    immutable(ubyte[]) sign(immutable(ubyte[]) message);

    Pubkey pubkey() pure const nothrow;

//    HashPointer calcHash(const(Event) e);
}
