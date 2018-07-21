module tagion.hashgraph.GossipNet;

import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event;
import tagion.utils.BSON : HBSON, Document;

enum ExchangeState : uint {
    NON,
    INIT_TIDE,
    TIDE_WAVE,
    FIRST_WAVE,
    SECOND_WAVE,
    BREAK_WAVE
}

import std.typecons : Typedef, TypedefType;

enum BufferType {
    PUBKEY,
    PRIVKEY,
    SIGNATURE,
    HASHPOINTER,
    MESSAGE
}


alias Buffer=immutable(ubyte)[];
alias Pubkey     =Typedef!(Buffer, null, BufferType.PUBKEY.stringof);
version(none) {
alias Privkey    =Typedef!(Buffer, null, BufferType.PRIVKEY.stringof);
alias Signature  =Typedef!(Buffer, null, BufferType.SIGNATURE.stringof);
alias Message    =Typedef!(Buffer, null, BufferType.SIGNATURE.stringof);
alias HashPointer=Typedef!(Buffer, null, BufferType.HASHPOINTER.stringof);

}
//template isBufferType(T) {
//    alias isBuffer=true;
enum isBufferType(T)=is(T : immutable(ubyte[]) ) || is(TypedefType!T : immutable(ubyte[]) );

static unittest {
    static assert(isBufferType!(immutable(ubyte[])));
    static assert(isBufferType!(immutable(ubyte)[]));
    static assert(isBufferType!(Pubkey));
    pragma(msg, TypedefType!int);
}

unittest {
    immutable buf=cast(Buffer)"Hello";
    immutable pkey=Pubkey(buf);
}

BUF buf_idup(BUF)(immutable(Buffer) buffer) {
    return cast(BUF)(buffer.idup);
}

@safe
interface RequestNet {
    immutable(Buffer) calcHash(immutable(ubyte[]) hash_pointer) inout;
    // Request a missing event from the network
    // add
    void request(HashGraph h, immutable(Buffer) event_hash);
//    immutable(ubyte[]) pubkey()

    Buffer eventHashFromId(immutable uint id);
}

@safe
interface SecureNet : RequestNet {
    immutable(Pubkey) pubkey() pure const nothrow;
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
