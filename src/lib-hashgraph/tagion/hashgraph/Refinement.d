/// Module for handling callbacks from the hashgraph
module tagion.hashgraph.Refinement;

import tagion.hashgraph.RefinementInterface;
import tagion.crypto.Types : Pubkey;
import tagion.basic.Types : Buffer;
import tagion.hashgraph.Event;
import tagion.hashgraph.Round;
import tagion.utils.BitMask;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.HashGraphBasic;
import tagion.utils.StdTime;
import tagion.logger.Logger;
import tagion.hibon.HiBONRecord;
// std
import std.stdio;
import std.algorithm;
import std.array;


@safe
class StdRefinement : Refinement {

    enum MAX_ORDER_COUNT = 10; /// Max recursion count for order_less function
    protected {
        HashGraph hashgraph;
    }

    void setOwner(HashGraph hashgraph)
    in (this.hashgraph is null)
    do {
        this.hashgraph = hashgraph;
    }

    void finishedEpoch(const(Event[]) events, const sdt_t epoch_time, const Round decided_round) {
        assert(0, "not implemented");
    }

    void excludedNodes(ref BitMask excluded_mask) {
        // should be implemented
    }

    void epack(immutable(EventPackage*) epack) {
        // log.trace("epack.event_body.payload.empty %s", epack.event_body.payload.empty);
    }


    void epoch(Event[] event_collection, const(Round) decided_round) {

        import std.algorithm;
        import std.range;

        bool order_less(const Event a, const Event b, const(int) order_count) @safe {
            bool rare_less(Buffer a_print, Buffer b_print) {
                // rare_order_compare_count++;
                pragma(msg, "review(cbr): Concensus order changed");
                return a_print < b_print;
            }

            // order_compare_iteration_count++;
            // writefln("order compare: %d, rare: %d", order_compare_iteration_count, rare_order_compare_count);

            if (order_count < 0) {
                return rare_less(a.fingerprint, b.fingerprint);
            }
            if (a.received_order is b.received_order) {
                if (a.father && b.father) {
                    return order_less(a.father, b.father, order_count - 1);
                }
                if (a.father) {
                    return true;
                }
                if (b.father) {
                    return false;
                }

                if (!a.isFatherLess && !b.isFatherLess) {
                    return order_less(a.mother, b.mother, order_count - 1);
                }

                return rare_less(a.fingerprint, b.fingerprint);
            }
            return a.received_order < b.received_order;
        }

        import tagion.basic.Debug;

        auto offline = ~BitMask(decided_round.events
                .filter!((e) => e !is null && e.isFamous)
                .map!(e => e.node_id));
        offline.chunk(hashgraph.node_size);


        offline[].each!((node_id) => hashgraph.mark_offline(node_id));
        
        hashgraph._excluded_nodes_mask |= offline;
        // __write("Epoch exclude = %s", hashgraph.excluded_nodes_mask);


        // __write("Epoch ONLINE=%s", online);

        // online.chunk(hashgraph.node_size);
        // hashgraph._excluded_nodes_mask |= ~online;
        // __write(" wowo excluded nodes after=%s", hashgraph.excluded_nodes_mask);

        import tagion.basic.Debug;

        sdt_t[] times;
        auto events = event_collection
            .filter!((e) => e !is null)
            .tee!((e) => times ~= e.event_body.time)
            .filter!((e) => !e.event_body.payload.empty)
            .array
            .sort!((a, b) => order_less(a, b, MAX_ORDER_COUNT))
            .release;
        times.sort;
        const mid = times.length / 2 + (times.length % 1);
        const epoch_time = times[mid];

        log.trace("%s Epoch round %d event.count=%d witness.count=%d event in epoch=%d time=%s",
                hashgraph.name, decided_round.number,
                Event.count, Event.Witness.count, events.length, epoch_time);

        finishedEpoch(events, epoch_time, decided_round);

        excludedNodes(hashgraph._excluded_nodes_mask);
    }

}

@safe
struct RoundFingerprint {
    Buffer[] fingerprints;
    mixin HiBONRecord;
}

@safe
const(RoundFingerprint) hashLastDecidedRound(const Round last_decided_round) pure nothrow
{
    import std.algorithm:filter;

    RoundFingerprint round_fingerprint;
    round_fingerprint.fingerprints = last_decided_round.events
        .filter!(e => e !is null)
        .map!(e => cast (Buffer)e.event_package.fingerprint)
        .array
        .sort
        .array;
    return round_fingerprint;
}
