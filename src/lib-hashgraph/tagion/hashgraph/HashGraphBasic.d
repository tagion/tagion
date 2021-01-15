module tagion.hashgraph.HashGraphBasic;

import std.bitmanip;

import tagion.basic.Basic : Buffer, Pubkey, EnumText;
import tagion.hashgraph.Event;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.basic.ConsensusExceptions;

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

alias Tides=int[immutable(Pubkey)];


protected enum _params = [
    "type",
    "tidewave",
    "wavefront",
    "block"
    ];

mixin(EnumText!("Params", _params));

enum ExchangeState : uint {
    NONE,
        INIT_TIDE,
        TIDAL_WAVE,
        FIRST_WAVE,
        SECOND_WAVE,
        BREAKING_WAVE
        }


alias convertState=convertEnum!(ExchangeState, GossipConsensusException);

@safe
interface HashGraphI {
    enum int eva_altitude=-77;

    //  void request(scope immutable(Buffer) fingerprint);

    Event lookup(scope const(ubyte[]) fingerprint);

    void eliminate(scope const(ubyte[]) fingerprint);

    Event registerEvent(immutable(EventPackage*) event_pack);

    //   void register(scope immutable(Buffer) fingerprint, Event event);

    bool isRegistered(scope immutable(Buffer) fingerprint) pure;

    size_t number_of_registered_event() const pure nothrow;

    const(Document) buildPackage(const(HiBON) pack, const ExchangeState type);

    Tides tideWave(HiBON hibon, bool build_tides);

    void wavefront(Pubkey received_pubkey, Document doc, ref Tides tides);

    void register_wavefront();

    HiBON[] buildWavefront(Tides tides, bool is_tidewave) const;

    void wavefront_machine(const(Document) doc);

    Round.Rounder rounds() pure nothrow;
    const(uint) nodeId(scope Pubkey pubkey) const pure;
    const(uint) node_size() const pure nothrow;

}
