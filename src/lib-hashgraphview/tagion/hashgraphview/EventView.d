/// HashGraph basic support functions
module tagion.hashgraphview.EventView;

import std.exception;

import tagion.hashgraph.Event;
import tagion.hibon.HiBONRecord;

@recordType("node_amount")
struct NodeAmount {
    long nodes;
    mixin HiBONRecord!(q{
            this(long nodes) @safe pure nothrow {
                this.nodes = nodes;
            }
    });
}

/// EventView is used to store event has a
@recordType("event_view")
struct EventView {
    enum eventsName = "$events";
    uint id;
    @label("$m") @optional @(filter.Initialized) uint mother;
    @label("$f") @optional @(filter.Initialized) uint father;
    @label("$n") size_t node_id;
    @label("$a") int altitude;
    @label("$o") long order;
    @label("$r") long round;
    @label("$rec") long round_received;
    @label("$w") @optional @(filter.Initialized) bool witness;
    @label("$famous") @optional @(filter.Initialized) bool famous;
    @label("$received") uint[] round_received_mask;
    @label("$error") @optional bool error;
    bool father_less;

    mixin HiBONRecord!(q{
        this(const Event event, const size_t relocate_node_id=size_t.max) @safe pure nothrow {
            import std.algorithm : each;
            id=event.id;
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
            error=event.error;
            node_id=(relocate_node_id is size_t.max)?event.node_id:relocate_node_id;
            altitude=event.altitude;
            order=event.order;
            witness=event.isWitness;
            if (witness) {
                famous = event.isFamous;
            }

            round=(event.hasRound)?event.round.number:event.round.number.min;
            father_less=event.isFatherLess;
            if (!event.round_received_mask[].empty) {
                event.round_received_mask[].each!((n) => round_received_mask~=cast(uint)(n));
            }
            round_received=(event.round_received)?event.round_received.number:long.min;
        }
    });
}
