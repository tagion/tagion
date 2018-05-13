module tagion.hashgraph.GossipNet;

import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event;
import tagion.utils.BSON : HBSON, Document;

enum ExchangeState : uint {
    NON,
    FIRST_WAVE,
        TIDE_WAVE,
        SECOND_WAVE
        }


@safe
interface RequestNet {
    alias HashPointer=immutable(ubyte)[];
    alias Pubkey=immutable(ubyte[]);
    alias immutable(ubyte)[] Privkey;
    immutable(HashPointer) calcHash(immutable(HashPointer) hash_pointer) inout;
    // Request a missing event from the network
    // add
    void request(HashGraph h, immutable(HashPointer) event_hash);
//    immutable(ubyte[]) pubkey()
    immutable(ubyte[]) pubkey() pure const nothrow;
    HashPointer eventHashFromId(immutable uint id);
}


@safe
interface GossipNet : RequestNet {

//    alias HashGraph.EventPackage EventPackage;
    void receive(immutable(ubyte[]) data);
    void send(immutable(ubyte[]) channel, immutable(ubyte[]) data);
    alias bool delegate(immutable(ubyte[])) Request;
    // This function is call by the HashGraph.whatIsNotKnowBy
    // and is use to collect node to be send to anotehr node
//    bool collect(Event e, immutable uint depth);

//    immutable(ubyte[]) evaPackage();

//    void buildPackage(HashGraph hashgraph, HBSON bson, Event event, immutable uint node_id);

    ulong time();


    bool verify(immutable(ubyte[]) message, immutable(ubyte[]) signature, Pubkey pubkey);

    // The private should be added implicite by the GossipNet
    // The message is a hash of the 'real' message
    immutable(ubyte[]) sign(immutable(ubyte[]) message);


//    HashPointer calcHash(const(Event) e);
}
