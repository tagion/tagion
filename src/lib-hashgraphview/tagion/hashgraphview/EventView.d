/// HashGraph basic support functions
module tagion.hashgraphview.EventView;

import tagion.hashgraph.Event;
import tagion.hibon.HiBONType;

/// EventView is used to store event has a
struct EventView {
    enum eventsName = "$events";
    uint id;
    @label("$m", true) @(filter.Initialized) uint mother;
    @label("$f", true) @(filter.Initialized) uint father;
    @label("$n") size_t node_id;
    @label("$a") int altitude;
    @label("$o") int order;
    @label("$r") int round;
    @label("$rec") int round_received;
    @label("$w", true) @(filter.Initialized) bool witness;
    @label("$famous", true) @(filter.Initialized) bool famous;
    @label("witness") uint[] witness_mask;
    @label("$strong") uint[] strongly_seeing_mask;
    @label("$seen") uint[] round_seen_mask;
    @label("$received") uint[] round_received_mask;
    bool father_less;

    mixin HiBONType!(
            q{
            this(const Event event, const size_t relocate_node_id=size_t.max) {
                import std.algorithm : each;
                id=event.id;
                if (event.isGrounded) {
                    mother=father=uint.max;
                }
                else {
                    if (event.mother) {
                        mother=event.mother.id;
                    }
                    if (event.father) {
                        father=event.father.id;
                    }
                }
                node_id=(relocate_node_id is size_t.max)?event.node_id:relocate_node_id;
                altitude=event.altitude;
                order=event.received_order;
                witness=event.witness !is null;
                event.witness_mask[].each!((n) => witness_mask~=cast(uint)(n));
                round=(event.hasRound)?event.round.number:event.round.number.min;
                father_less=event.isFatherLess;
                if (witness) {
                    event.witness.strong_seeing_mask[].each!((n) => strongly_seeing_mask~=cast(uint)(n));
                    event.witness.round_seen_mask[].each!((n) => round_seen_mask~=cast(uint)(n));
                    famous = event.witness.famous;
                }
                if (!event.round_received_mask[].empty) {
                    event.round_received_mask[].each!((n) => round_received_mask~=cast(uint)(n));
                }
                round_received=(event.round_received)?event.round_received.number:int.min;
            }
        });

}


