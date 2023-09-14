module tagion.hashgraphview.Compare;

import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.HashGraphBasic : higher;
import std.algorithm.iteration : map;
import std.array : array;
import std.range : lockstep;

@safe
struct Compare {
    enum ErrorCode {
        NONE,
        NODES_DOES_NOT_MATCH,
        FINGERPRINT_NOT_THE_SAME,
        MOTHER_NOT_THE_SAME,
        FATHER_NOT_THE_SAME,
        ALTITUDE_NOT_THE_SAME,
        ORDER_NOT_THE_SAME,
        ROUND_NOT_THE_SAME,
        ROUND_RECEIVED_NOT_THE_SAME,
        WITNESS_CONFLICT,
    }

    alias ErrorCallback = bool delegate(const Event e1, const Event e2, const ErrorCode code) nothrow @safe;
    const HashGraph h1, h2;
    const ErrorCallback error_callback;
    int order_offset;
    int round_offset;
    uint count;
    this(const HashGraph h1, const HashGraph h2, const ErrorCallback error_callback) {
        this.h1 = h1;
        this.h2 = h2;
        this.error_callback = error_callback;
    }

    bool compare() @trusted {
        count = 0;
        auto h1_nodes = h1.nodes
            .byValue
            .map!((n) => n[])
            .array;
        typeof(h1_nodes) h2_nodes;
        try {
            h2_nodes = h1.nodes
                .byValue
                .map!((n) => h2.nodes[n.channel][])
                .array;
        }
        catch (Exception e) {
            if (error_callback) {
                error_callback(null, null, ErrorCode.NODES_DOES_NOT_MATCH);
            }
            return false;
        }
        bool ok = true;

        foreach (ref h1_events, ref h2_events; lockstep(h1_nodes, h2_nodes)) {
            while (!h1_events.empty && higher(h1_events.front.altitude, h2_events
                    .front.altitude)) {
                h1_events.popFront;
            }
            while (!h2_events.empty && higher(h2_events.front.altitude, h1_events
                    .front.altitude)) {
                h2_events.popFront;
            }
            bool check(bool ok, const ErrorCode code) {
                if (!ok && error_callback) {
                    return error_callback(h1_events.front, h2_events.front, code);
                }
                return ok;
            }

            if (!h1_events.empty && !h2_events.empty) {
                order_offset = h1_events.front.order - h2_events.front.order;
                if (!h1_events.front.hasRound || !h2_events.front.hasRound) {
                    return error_callback(null, null, ErrorCode.NODES_DOES_NOT_MATCH);
                }
                round_offset = h1_events.front.round.number - h2_events.front.round.number;
            }
            //error_callback(h1_events.front, h2_events.front, ErrorCode.NONE);
            while (!h1_events.empty && !h2_events.empty) {
                const e1 = h1_events.front;
                const e2 = h2_events.front;

                with (ErrorCode) {
                    ok &= check(e1.fingerprint == e2.fingerprint, FINGERPRINT_NOT_THE_SAME);
                    ok &= check(e1.event_body.mother == e2.event_body.mother, MOTHER_NOT_THE_SAME);
                    ok &= check(e1.event_body.father == e2.event_body.father, FATHER_NOT_THE_SAME);
                    ok &= check(e1.altitude == e2.altitude, ALTITUDE_NOT_THE_SAME);
                    ok &= check(e1.order - e2.order == order_offset, ORDER_NOT_THE_SAME);
                    ok &= check(e1.round.number - e2.round.number == round_offset, ROUND_NOT_THE_SAME);
                    if ((e1.round_received) && (e2.round_received)) {
                        ok &= check(e1.round_received.number - e2.round_received.number == round_offset,
                                ROUND_RECEIVED_NOT_THE_SAME);
                    }
                    ok &= check((e1.witness is null) == (e2.witness is null), WITNESS_CONFLICT);
                }
                // if (!ok) {
                //     return ok;
                // }
                count++;
                h1_events.popFront;
                h2_events.popFront;
            }
        }
        return ok;
    }
}
