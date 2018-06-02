module tagion.hashgraph.GossipNet;

import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event;
import tagion.utils.BSON : HBSON, Document;

enum ExchangeState : uint {
    NON,
    INIT_TIDE,
    TIDE_WAVE,
    FIRST_WAVE,
    SECOND_WAVE
}


@safe
interface RequestNet {
    alias HashPointer=immutable(ubyte)[];
    immutable(HashPointer) calcHash(immutable(HashPointer) hash_pointer) inout;
    // Request a missing event from the network
    // add
    void request(HashGraph h, immutable(HashPointer) event_hash);
//    immutable(ubyte[]) pubkey()

    HashPointer eventHashFromId(immutable uint id);
}

@safe
interface SecureNet : RequestNet {
    alias Pubkey=immutable(ubyte[]);
    alias Privkey=immutable(ubyte)[];
    immutable(ubyte[]) pubkey() pure const nothrow;
    bool verify(immutable(ubyte[]) message, immutable(ubyte[]) signature, Pubkey pubkey);

    // The private should be added implicite by the GossipNet
    // The message is a hash of the 'real' message
    immutable(ubyte[]) sign(immutable(ubyte[]) message);
}

@safe
interface GossipNet : SecureNet {

//    alias HashGraph.EventPackage EventPackage;
    Event receive(immutable(ubyte[]) data, Event delegate(immutable(ubyte)[] leading_event_fingerprint) @safe register_leading_event );
    void send(immutable(ubyte[]) channel, immutable(ubyte[]) data);
    alias bool delegate(immutable(ubyte[])) Request;
    // This function is call by the HashGraph.whatIsNotKnowBy
    // and is use to collect node to be send to anotehr node
    ulong time();
}
