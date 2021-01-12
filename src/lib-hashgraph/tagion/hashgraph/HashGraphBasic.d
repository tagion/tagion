module tagion.hashgraph.HashGraphBasic;

import std.bitmanip;

import tagion.basic.Basic : Buffer, Pubkey;
import tagion.hashgraph.Event;

enum minimum_nodes = 3;
/++
 + Calculates the majority votes
 + Params:
 +     voting    = Number of votes
 +     node_sizw = Total bumber of votes
 + Returns:
 +     Returns `true` if the votes are more thna 2/3
 +/
@safe @nogc
bool isMajority(const size_t voting, const size_t node_size) pure nothrow {
    return (node_size >= minimum_nodes) && (3*voting > 2*node_size);
}

@trusted
bool isMajority(scope const(BitArray) mask) pure nothrow {
    return isMajority(mask.count, mask.length);
}


@safe
interface HashGraphI {
    //  void request(scope immutable(Buffer) fingerprint);

    Event lookup(scope const(ubyte[]) fingerprint);

    void eliminate(scope const(ubyte[]) fingerprint);

    Event registerEvent(immutable(EventPackage*) event_pack);

    //   void register(scope immutable(Buffer) fingerprint, Event event);

    bool isRegistered(scope immutable(Buffer) fingerprint) pure;

    size_t number_of_registered_event() const pure nothrow;

    void register_wavefront();

    Round.Rounder rounds() pure nothrow;
    const(uint) nodeId(scope Pubkey pubkey) const pure;
    const(uint) node_size() const pure nothrow;

}
