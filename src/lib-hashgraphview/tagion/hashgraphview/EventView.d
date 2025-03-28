/// HashGraph basic support functions
module tagion.hashgraphview.EventView;

import std.exception;

import tagion.hashgraph.Event;
import tagion.hibon.HiBONRecord;
import tagion.basic.Types : Buffer;
import tagion.hashgraph.HashGraphBasic : isMajority;

/// EventView is used to store event has a
@recordType("event_view")
struct EventView {
    enum eventsName = "$events";
    uint id;
    @label("$m") @optional @(filter.Initialized) uint mother;
    @label("$f") @optional @(filter.Initialized) uint father;
    @label("$n") uint node_id;
    @label("$a") int altitude;
    @label("$o") int order;
    @label("$r") int round;
    @label("$R") int round_received;
    @label("$w") @optional @(filter.Initialized) bool witness;
    @label("$i") @optional @(filter.Initialized) bool intermediate;
    //    @label("$seen") @optional Buffer seen; /// Event seeing witness  
    @label("$strong") @optional Buffer strongly_seen; /// Witness seen strongly in previous round
    @label("$intermediate") @optional Buffer intermediate_seen;
    @label("$W") @optional Buffer witness_seen;
    @label("$I") @optional Buffer intermediate_votes;
    @label("$voted") @optional Buffer voted; /// Witness which has voted yes   
    @label("$yes") @optional uint yes_votes; /// Famous yes votes    
    @label("$weak") @optional bool weak;
    @label("$decided") @optional @(filter.Initialized) bool decided; /// Witness decided
    long nodes_amount;
    @optional @(filter.Initialized) bool collector;
    bool father_less;

    mixin HiBONRecord!(q{
        this(const Event event, long nodes_amount, const uint relocate_node_id=uint.max) @safe pure nothrow {
            import std.algorithm : each;
            id=event.id;
            this.nodes_amount = nodes_amount;
            if (event.isGrounded) {
                mother = father = uint.max;
            }
            else {
                if (assumeWontThrow(event.mother)) {
                    mother=assumeWontThrow(event.mother).id;
                }
                if (assumeWontThrow(event.father)) {
                    father=assumeWontThrow(event.father).id;
                }
            }
            node_id=(relocate_node_id is size_t.max)?event.node_id:relocate_node_id;
            altitude=event.altitude;
            order=event.order;
            witness=event.isWitness;
            round=(event.hasRound)?event.round.number:event.round.number.min;
            father_less=event.isFatherLess;
            round_received=(event.round_received)?event.round_received.number:int.min;
            collector=event.collector;

            intermediate=event._intermediate_event;
            witness_seen=event.witness_seen_mask.bytes;   
            intermediate_seen=event.intermediate_seen_mask.bytes;
            if (event.isWitness) {
               auto witness=event.witness;
               strongly_seen=witness.previous_strongly_seen_mask.bytes;
               yes_votes = witness.yes_votes;
               voted = witness.voted_yes_mask.bytes;
               intermediate_votes = witness.intermediate_voting_mask.bytes;
               //witness_seen = witness.previous_witness_seen_mask.bytes;
                decided = event.round.valid_witness[event.node_id];
                weak = witness.weak;
            }
        }
    });
}

import tagion.hashgraph.HashGraph;
import tagion.crypto.Types : Pubkey;

@safe
void fwrite(ref const(HashGraph) hashgraph, string filename, Pubkey[string] node_labels = null) {
    import std.algorithm : sort, filter, each;
    import std.stdio;
    import tagion.hashgraphview.EventView;
    import tagion.hibon.HiBONFile : fwrite;

    File graphfile = File(filename, "w");
    scope (exit) {
        graphfile.close;
    }
    uint[Pubkey] node_id_relocation;
    if (node_labels.length) {
        // assert(node_labels.length is _nodes.length);
        auto names = node_labels.keys;
        names.sort;
        foreach (i, name; names) {
            node_id_relocation[node_labels[name]] = cast(uint) i;
        }

    }

    EventView[uint] events;
    (() @trusted {
        foreach (n; hashgraph.nodes) {
            const node_id = (node_id_relocation.length is 0) ? uint.max : node_id_relocation[n.channel];
            n[]
                .filter!((e) => !e.isGrounded)
                .each!((e) => events[e.id] = EventView(e, hashgraph.node_size, node_id));
        }
    })();

    foreach (e; events) {
        graphfile.fwrite(e);
    }
}
