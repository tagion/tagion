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
import tagion.hibon.Document;
import tagion.hibon.HiBON;

import tagion.basic.Debug;

// std
import std.stdio;
import std.algorithm : map, filter, sort, reduce, until;
import std.array;
import tagion.utils.pretend_safe_concurrency;

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

    Tid collector_service;
    void payload(immutable(EventPackage*) epack) {
        if (!epack.event_body.payload.empty) {
            // send to collector payload.

        }
    }

    void finishedEpoch(const(Event[]) events, const sdt_t epoch_time, const Round decided_round) {
        auto epoch_created = submask.register("epoch_creator/epoch_created");

        immutable epoch_events = events
            .map!((e) => e.event_package)
            .array;

        log(epoch_created, "epoch succesful", epoch_events);

    }

    void excludedNodes(ref BitMask excluded_mask) {
        // should be implemented
    }

    void epack(immutable(EventPackage*) epack) {
        // log.trace("epack.event_body.payload.empty %s", epack.event_body.payload.empty);
    }


    
    void epoch(Event[] event_collection, const(Round) decided_round) {

        import std.bigint;
        import std.range: retro, back, tee;
        import std.numeric: gcd;
        
        struct PseudoTime {
            BigInt num;
            BigInt denom;
            BigInt order_num;
            BigInt order_denum;
            sdt_t t_num;
            sdt_t t_denom;

            this(BigInt num, BigInt denom) {
                this.num = num;
                this.denom = denom;
            }
            this(int num, int denom, int int_part) {
                this.num = BigInt(num+denom*int_part);
                this.denom = BigInt(denom);
            }

            PseudoTime opBinary(string op)(PseudoTime other) if (op == "+") {
                BigInt d = gcd(denom, other.denom);
                return PseudoTime(other.denom/d*num + denom/d*other.num, denom/d*other.denom);
            }
        }
        const famous_witnesses = decided_round
                                        ._events
                                        .filter!(e => e !is null)
                                        .filter!(e => decided_round.famous_mask[e.node_id]);

        PseudoTime calc_pseudo_time(Event event, bool tie_breaker) {

            auto receivers = famous_witnesses
                                    .map!(e => e[].until!(e => !e.sees(event))
                                                  .array.back);
            
            PseudoTime[] times;
            
            if (tie_breaker) {
                times = receivers.map!(e => PseudoTime(e.order, e[].retro.filter!(e => e._witness).front._mother.order+1, 0)).array;
            } else {
                times = receivers.map!(e => PseudoTime(e.pseudo_time_counter, e[].retro.filter!(e => e._witness).front._mother.pseudo_time_counter+1, e.round.number)).array;
            }
            auto av_time = times.reduce!((t1, t2) => t1 + t2);
            return av_time;
        }
        
        bool order_less(Event a, Event b) {
            PseudoTime at = calc_pseudo_time(a, false);
            PseudoTime bt = calc_pseudo_time(b, false);

            if (at.num*bt.denom == at.denom*bt.num)
            {
                PseudoTime ast = calc_pseudo_time(a, true);
                PseudoTime bst = calc_pseudo_time(b, true);
                
                if (ast.num*bst.denom == ast.denom*bst.num)
                {
                    if (a.order == b.order) {
                        return a.fingerprint < b.fingerprint;
                    }
                    return a.order < b.order;
                }
                return ast.num*bst.denom < ast.denom*bst.num;
            }
            return at.num*bt.denom < at.denom*bt.num;
        }

        
        auto events = event_collection
            .filter!((e) => !e.event_body.payload.empty)
            .array
            .sort!((a, b) => order_less(a, b))
            .release;

        sdt_t[] times;
        auto events2 = event_collection
            .filter!((e) => e !is null)
            .tee!((e) => times ~= e.event_body.time)
            .filter!((e) => !e.event_body.payload.empty)
            .array
            .sort!((a, b) => order_less(a, b))
            .release;
        times.sort;
        const mid = times.length / 2 + (times.length % 1);
        const epoch_time = times[mid];

        log.trace("%s Epoch round %d event.count=%d witness.count=%d event in epoch=%d time=%s",
                hashgraph.name, decided_round.number,
                Event.count, Event.Witness.count, events.length, epoch_time);

        finishedEpoch(events, epoch_time, decided_round);

        excludedNodes(hashgraph._excluded_nodes_mask);
        if (hashgraph.__debug_print) {
            __write("ORDER: %s", events.map!(e => e.id));
        }
    }

    version(none) //SHOULD NOT BE DELETED SO WE CAN REVERT TO OLD ORDERING IF NEEDED
    void epoch(Event[] event_collection, const(Round) decided_round) {
        import std.algorithm;
        import std.range;

        bool order_less(const Event a, const Event b, const(int) order_count) @safe {
            bool rare_less(Buffer a_print, Buffer b_print) {
                // rare_order_compare_count++;
                pragma(msg, "review(cbr): Concensus order changed");
                return a_print < b_print;
            }

            if (order_count < 0) {
                return rare_less(a.fingerprint, b.fingerprint);
            }
            if (a.order is b.order) {
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
            return a.order < b.order;
        }

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
const(RoundFingerprint) hashLastDecidedRound(const Round last_decided_round) pure nothrow {
    import std.algorithm : filter;

    RoundFingerprint round_fingerprint;
    round_fingerprint.fingerprints = last_decided_round.events
        .filter!(e => e !is null)
        .map!(e => cast(Buffer) e.event_package.fingerprint)
        .array
        .sort
        .array;
    return round_fingerprint;
}
