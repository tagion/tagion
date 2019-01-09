module tagion.hashgraph.GossipNet;

import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event;
import tagion.utils.BSON : HBSON, Document;

import tagion.Base;

enum ExchangeState : uint {
    NON,
    INIT_TIDE,
    TIDE_WAVE,
    FIRST_WAVE,
    SECOND_WAVE,
    BREAK_WAVE
}

@safe
interface RequestNet {
    immutable(Buffer) calcHash(immutable(ubyte[]) data) inout;
    // Request a missing event from the network
    // add
    void request(HashGraph h, immutable(Buffer) event_hash);
//    void sendToScriptingEngine(immutable(Buffer) eventbody);
//    immutable(ubyte[]) pubkey()

//    Buffer eventHashFromId(immutable uint id);
}

@safe
interface SecureNet : RequestNet {
    Pubkey pubkey() pure const nothrow;
    bool verify(immutable(ubyte[]) message, immutable(ubyte[]) signature, Pubkey pubkey);

    // The private should be added implicite by the GossipNet
    // The message is a hash of the 'real' message
    immutable(ubyte[]) sign(immutable(ubyte[]) message);
}

@safe
interface GossipNet : SecureNet {

//    alias HashGraph.EventPackage EventPackage;
    Event receive(immutable(ubyte[]) data, Event delegate(immutable(ubyte)[] leading_event_fingerprint) @safe register_leading_event );
    void send(immutable(Pubkey) channel, immutable(ubyte[]) data);
    alias bool delegate(immutable(ubyte[])) Request;
    // This function is call by the HashGraph.whatIsNotKnowBy
    // and is use to collect node to be send to anotehr node
    ulong time();
}

@safe
interface DARTNet : SecureNet {
    immutable(ubyte[]) load(const(string[]) path, const(ubyte[]) key);
    void save(const(string[]) path, const(ubyte[]) key, immutable(ubyte[]) data);
    void erase(const(string[]) path, const(ubyte[]) key);

}
