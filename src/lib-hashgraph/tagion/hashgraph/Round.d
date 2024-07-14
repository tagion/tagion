/// HashGraph Round
module tagion.hashgraph.Round;

//import std.stdio;

import std.datetime; // Date, DateTime
import std.algorithm;
import std.array : array;
import std.conv;
import std.format;
import std.range;
import std.range : enumerate, tee;
import std.range.primitives : isBidirectionalRange, isForwardRange, isInputRange, walkLength;
import std.stdio;
import std.traits : ReturnType, Unqual;
import std.traits;
import std.typecons;
import std.typecons : No;
import tagion.basic.Types : Buffer;
import tagion.basic.basic : EnumText, basename, buf_idup, this_dot;
import tagion.crypto.Types : Pubkey;
import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.HashGraphBasic : EvaPayload, EventBody, EventPackage, Tides, higher, isAllVotes, isMajority;
import tagion.monitor.Monitor : EventMonitorCallbacks;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : HiBONRecord;
import tagion.logger.Logger;
import tagion.utils.BitMask : BitMask;
import tagion.utils.Miscellaneous;
import tagion.utils.StdTime;
import tagion.basic.Debug;

debug {
    import std.array;
}
/// Handles the round information for the events in the Hashgraph
@safe
class Round {
    //    bool erased;
    enum uint total_limit = 3;
    enum int coin_round_limit = 10;
    protected {
        Round _previous;
        Round _next;
        Round _voting; /// This is the voting round
        BitMask _common_previous_seen_witness_mask;
    }
    immutable int number;

    final int voting_number() const pure nothrow @nogc {
        return (_voting) ? _voting.number : -1;
    }

    final const(Round) voting() const pure nothrow @nogc {
        return _voting;
    }

    package Event[] _events;
    protected bool _decided;
    BitMask _valid_witness;
    private void decide() pure nothrow @nogc
    in (!_decided)
    do {
        _decided = true;
    }

    final bool decided() const pure nothrow @nogc {
        return _decided;
    }

    enum Completed {
        none,
        majority_none,
        too_few,
        undecided,
        all_witness,
        next_witness,
        higher,
        missing,
        last_witness,
        valid_witness,
        double_witness,
        tripple_none_witness,
        witness_gap,
        witness_4,
        witness_5,
        witness_6,
    }

    final Completed completed(const HashGraph hashgraph, ref BitMask __valid_witness) const pure nothrow {
        import tagion.utils.Term;

        if (majority) {
            Completed ret;
            BitMask null_mask;
            BitMask all_mask = BitMask.init.invert(node_size);
            BitMask completed_mask;
            BitMask included_mask;
            BitMask completed_mask_2;
            BitMask included_mask_2;
            version(none)
            completed_mask = BitMask(node_size.iota
                    .filter!(n => (_events[n]!is null) && (_events[n].witness.separation < 3)));

            version(none)
            completed_mask_2 = BitMask(node_size.iota
                    .filter!(n => (_events[n] is null) || (_events[n].witness.weak)));
            auto list_majority_rounds =
                this[].retro
                    .until!(r => !r.majority);
            auto future_witness_masks = list_majority_rounds
                .map!(r => BitMask(r.node_size.iota.filter!(n => r.events[n]!is null)));
            auto future_witness_masks_2 = list_majority_rounds
                .map!(r => BitMask(r.node_size.iota.filter!(n => (r.events[n]!is null) )));
            __valid_witness = BitMask(node_size.iota
                    .filter!(n => (_events[n]!is null) ));

            if (!completed_mask.empty) {
                __write("%12s Round %d completed=%#s separation=%(%d %)".replace("#", node_size.to!string),
                        hashgraph.name,
                        number,
                        completed_mask,
                        _events.map!(e => ((e is null) ? -1 : e.witness.separation))
                );
            }
            uint count;
            auto show_witness_masks = future_witness_masks;
            scope (exit) {
                __write(
                        "%12s Round %d completed=%#s included_mask=%#s witness=%#s| %(%#s %) count=%d ret=%s%s%s".replace(
                        "#", node_size.to!string),
                        hashgraph.name, number, completed_mask, included_mask,
                        __valid_witness,
                        show_witness_masks.take(10),
                        count,
                        (ret <= Completed.undecided) ? RED : GREEN, ret, RESET
                );
                __write("%12s Round %d seen %(%#s %)".replace("#", node_size.to!string),
                        hashgraph.name,
                        number,
                        list_majority_rounds
                        .take(8)
                        .map!(r => r._events
                            .filter!(e => e !is null)
                            .map!(e => e.witness.previous_witness_seen_mask)
                            .fold!((a, b) => a | b)(null_mask))
                );
                if (ret > Completed.undecided) {
                    auto _color = (completed_mask == completed_mask_2) ? "good " ~ GREEN : "badc  " ~ RED;
                    __write("%12s Round %d %scompleted=%#s completed_1=%#s%s ret=%s".replace("#", node_size.to!string),
                            hashgraph.name,
                            number,
                            _color,
                            completed_mask,
                            completed_mask_2,
                            RESET,
                            ret);
                    _color = (included_mask == included_mask_2) ? "good " ~ GREEN : "badi " ~ RED;
                    __write("%12s Round %d %sincluded=%#s included_1=%#s%s ret=%s".replace("#", node_size.to!string),
                            hashgraph.name,
                            number,
                            _color,
                            included_mask,
                            included_mask_2,
                            RESET,
                            ret);

                }
            }
            scope (exit) {
                __valid_witness &= included_mask_2;
            }
            if (list_majority_rounds.empty) {
                return Completed.none;
            }
            const number_of_future_rounds = cast(int) list_majority_rounds.walkLength;
            if (number_of_future_rounds < 3) {
                return ret = Completed.too_few;
            }
            const no_witness_gap_1 = (() => future_witness_masks
                    .takeExactly(3)
                    .fold!((a, b) => a & b)(all_mask));
            const some_witnesses_1 = (() => future_witness_masks
                    .takeExactly(3)
                    .fold!((a, b) => a | b)(null_mask));

            const no_witness_gap = no_witness_gap_1();
            const some_witnesses = some_witnesses_1();
            completed_mask |= no_witness_gap;
            included_mask |= no_witness_gap;
            //completed_mask_2 |= no_witness_gap;
            //included_mask_2 |= no_witness_gap;


            BitMask no_witnesses = some_witnesses.invert(node_size);
            __write("%12s %s%sRound %d%s complete=%#s  included=%#s no_gap=%#s some=%#s no_witness=%#s".replace("#", node_size.to!string),
                    hashgraph.name,
                    BOLD, YELLOW,
                    number,
                    RESET,
                    completed_mask,
                    included_mask,
                    no_witness_gap,
                    some_witnesses,
                    no_witnesses,
            );
            __write("%12s %sRound %d%s complete=%#s  included=%#s no_witness=%#s %#s | %(%#s %)".replace("#", node_size.to!string),
                    hashgraph.name,
                    YELLOW,
                    number,
                    RESET,
                    completed_mask,
                    included_mask,
                    __valid_witness,
                    no_witnesses,
                    future_witness_masks.take(6)
            );
            version(none)
            const no_witness_gap_2 = (() => future_witness_masks_2
                    .takeExactly(3)
                    .fold!((a, b) => a & b)(all_mask));
            version(none)
            const some_witnesses_2 = (() => future_witness_masks_2
                    .takeExactly(3)
                    .fold!((a, b) => a | b)(null_mask));

            const len=
                    max(number_of_future_rounds - 2, 0);
            __write("%12s %sRound %d%s n=%d len=%d %(%#s %)".replace("#", node_size.to!string),
                    hashgraph.name,
                    CYAN,
                    number,
                    RESET,
                    number_of_future_rounds,
                    len,
                    future_witness_masks
            );
            
          
            int[] vote_count;
            vote_count.length=node_size;
            future_witness_masks_2
            .map!(mask => mask[])
            .joiner
            .each!(n => vote_count[n]++);

            //included_mask_2 = BitMask(node_size.iota.filter!(n => vote_count[n] >= 3));
            
           // completed_mask_2 |= BitMask(node_size.iota.filter!(n => vote_count[n] <= number_of_future_rounds-3));
            const min_span=vote_count.filter!(v => v <= 3).maxElement(0);
            const max_span=vote_count.filter!(v => v > 3).minElement(number_of_future_rounds);
        
            __write("%12s %sRound %d%s votes=%(%2d %) [%d:%d] %s %#s | %(%#s %)".replace("#", node_size.to!string),
                        hashgraph.name,
                        CYAN,
                        number,
                        RESET,
                        vote_count,
                        min_span,
                        max_span,
                        ((max_span-min_span >= 3)?GREEN~"ok":RED~"not")~RESET,
                        
                        _valid_witness,
                        show_witness_masks.drop(1).take(6));
          
           
        
            //future_witness_masks_2.popFront;
            BitMask more_some_witnesses;
            BitMask no_witness_gap_2;
            BitMask some_witnesses_2;
            BitMask no_witness_void_2;
            BitMask first_gap;
            auto list_seen_witness =
                        list_majority_rounds
                        .drop(1)
                        .map!(r => r._events
                            .filter!(e => e !is null)
                            .map!(e => e.witness.previous_witness_seen_mask)
                            .fold!((a, b) => a | b)(null_mask));

            //included_mask_2 = future_witness_masks_2.front;
            int[] count_zeros;
            int[] count_ones;
            BitMask zeros_mask;
            BitMask ones_mask;
            count_ones.length=count_zeros.length = node_size;
            included_mask_2 = __valid_witness;
            foreach(i, witness_mask; future_witness_masks_2.drop(1).enumerate) {
                witness_mask[]
                .each!(n => count_zeros[n]=0);
                witness_mask.invert(node_size)[]
                .each!(n => count_zeros[n]++);
                witness_mask[]
                .each!(n => count_ones[n]++);
                witness_mask.invert(node_size)[]
                .each!(n => count_ones[n]=0);
                zeros_mask|=BitMask(node_size
                .iota
                .filter!(n => count_zeros[n] > 3));
                ones_mask|=BitMask(node_size
                .iota
                .filter!(n => count_ones[n] > 3));
                some_witnesses_2 |= witness_mask; 
                if (i == 0) {
                    no_witness_void_2 = witness_mask;
                    //completed_mask_2 |= witness_mask;
//                    included_mask_2 = witness_mask;
                     
                }
                else {
                    no_witness_void_2 |= witness_mask;
                }
                if (i == 4) {
                    included_mask_2 -= some_witnesses_2.invert(node_size);
                    completed_mask_2 |= some_witnesses_2.invert(node_size);
                }
                //some_witnesses_2 &= witness_mask;
                if ( i > 2) {
                    completed_mask_2 |= witness_mask;
                }
                //included_mask_2 = ones_mask;
            //    completed_mask_2 = zeros_mask | ones_mask;
                __write(
                        "%12s %sRound %d%s %d]:%d complete=%#s included=%#s no_gap=%#s some=%#s zeros=%#s ones=%#s %#s | %(%#s %) 0->%(%d %) 1->%(%d %)"
                        .replace("#", node_size.to!string),
                        hashgraph.name,
                        CYAN,
                        number,
                        RESET,
                        i,
                        number,
                        completed_mask_2,
                        included_mask_2,
                        no_witness_gap_2,
                        some_witnesses_2,
                        zeros_mask,
                        ones_mask,
                        _valid_witness,
                        show_witness_masks.drop(1).take(6),
                        count_zeros,
                        count_ones);
                if ( completed_mask_2.count == node_size) {
                    return ret = Completed.all_witness;

                }
            }
            return ret = Completed.undecided;
            version(none)
            foreach (i; 0 .. len-1) {

                const _no_witness_gap = future_witness_masks_2
                .takeExactly(3)
                .fold!((a,b) => a & b)(all_mask);
                const _some_witnesses = future_witness_masks_2
                .takeExactly(3)
                .fold!((a,b) => a | b)(null_mask);
                completed_mask_2 |= _no_witness_gap;
       //         included_mask_2 |= _no_witness_gap;
                
                //completed_mask_2 |= _no_witness_gap;
                
                //included_mask_2 |= _no_witness_gap;
                __write(
                        "%12s %sRound %d%s %d]:%d complete=%#s  included=%#s no_gap=%#s some=%#s more=%#s %#s | %(%#s %)"
                        .replace("#", node_size.to!string),
                        hashgraph.name,
                        CYAN,
                        number,
                        RESET,
                        i,
                        number,
                        completed_mask_2,
                        included_mask_2,
                        _no_witness_gap,
                        _some_witnesses,
                        more_some_witnesses,
                        _valid_witness,
                        show_witness_masks.drop(1).take(6));
                if (completed_mask_2.count == node_size) {
                    break;
                }
                more_some_witnesses |= _some_witnesses;
                if (i > 0) {
                    completed_mask_2 |= _some_witnesses.invert(node_size);
                }
                future_witness_masks_2.popFront;
            }
            version(none) {
            if (completed_mask_2.count == node_size) {
                return ret = Completed.all_witness;

            }
            return ret = Completed.undecided;
            }
            foreach (witness_mask; future_witness_masks.drop(3)) {
                const some_witnesses_b = some_witnesses_1();
                no_witnesses &= witness_mask.invert(node_size);
                completed_mask |= witness_mask;
                const included_mask_before = included_mask;
                if (count < 3) {
                    included_mask |= witness_mask;
                }
                __write("%12s %sRound %d%s complete=%#s no_witness=%#s included=%#s->%#s witness=%#s count=%d"
                        .replace("#", node_size.to!string),
                        hashgraph.name,
                        MAGENTA,
                        number,
                        RESET,
                        completed_mask,
                        no_witnesses,
                        included_mask_before,
                        included_mask,
                        witness_mask,
                        count);

                count++;
                if (completed_mask.count == node_size) {
                    return ret = Completed.valid_witness;

                }
            }
            if (count >= 3) {
                completed_mask |= no_witnesses;
                const included_mask_before = included_mask;
                included_mask -= no_witnesses;
                __write("%12s %sRound %d%s completed=%#s included=%#s->%#s COUNT=%d %d no_witness=%#s"
                        .replace("#", node_size.to!string),
                        hashgraph.name,
                        MAGENTA,
                        number,
                        RESET,
                        completed_mask,
                        included_mask_before,
                        included_mask,
                        count,
                        completed_mask.count,
                        no_witnesses
                );
                if (completed_mask.count == node_size) {
                    return ret = Completed.witness_gap;
                }

            }
            return ret = Completed.undecided;
        }
        return Completed.none;
    }

    final const(BitMask) witness_mask() const pure nothrow {
        return BitMask(_events.filter!(e => e !is null)
                .map!(e => e.node_id));
    }

    version (none) final const(BitMask) enclosed_witness_mask() const pure nothrow {
        BitMask result;
        auto feature_rounds = this[].retro.drop(1).take(2);
        return feature_rounds.map!(r => r.witness_mask)
            .fold!((a, b) => a | b)(result);
    }

    version (none) final const(BitMask) __decision_mask() const pure nothrow {
        const _witness_mask = witness_mask;
        const _enclosed_witness_mask = enclosed_witness_mask;
        const result = _enclosed_witness_mask | (_witness_mask & _enclosed_witness_mask.invert(_events.length)) | (
                _witness_mask.invert(_events.length) & _enclosed_witness_mask.invert(_events.length));
        return result;
    }

    /**
     * Construct a round from the previous round
     * Params:
     *   previous = previous round
     *   node_size = size of events in a round
     */
    private this(Round previous, const size_t node_size) pure nothrow {
        if (previous) {
            number = previous.number + 1;
            previous._next = this;
            _previous = previous;
        }
        else {
            number = 0;
        }
        _events = new Event[node_size];
    }

    /**
     * All the events in the first ooccurrences of this round
     * Returns: all events in a round
     */
    final const(Event[]) events() const pure nothrow @nogc {
        return _events;
    }

    package final inout(Event[]) events() inout pure nothrow @nogc {
        return _events;
    }

    final uint node_size() const pure nothrow @nogc {
        return cast(uint) _events.length;
    }
    /**
     * Adds the even to round
     * Params:
     *   event = the event to be added
     */
    package final void add(Event event) pure nothrow
    in {
        assert(event._witness, "The event id " ~ event.id.to!string ~ " added to the round should be a witness ");
        assert(_events[event.node_id] is null, "Event at node_id " ~ event.node_id.to!string ~ " should only be added once");
    }
    do {
        _events[event.node_id] = event;
        event._round = this;
    }

    version(none)
    final bool _can_round_be_decided() const pure nothrow {
        auto feature_rounds = opSlice.retro.drop(1).take(2);
        if (feature_rounds.walkLength < 2) {
            return false;
        }
        if (!feature_rounds.map!(r => r.majority).all) {
            return false;
        }
        bool decided_inner(T)(T item) nothrow pure {
            const event = item.value;
            if (event) {
                return event.witness.decision !is Event.Witness.DecisionType.undecided;
            }
            const _node_id = item.index;
            return feature_rounds.map!(r => r.events[_node_id] is null).all ||
                feature_rounds.map!(r => r.events[_node_id]!is null).any;
        }

        return _events.enumerate.map!(item => decided_inner(item)).all;
    }

    version (none) private bool _decided_round_yes() const pure nothrow {
        return majority && _events
            .filter!(e => e !is null)
            .map!(e => e.witness._decidedYes)
            .all;
    }

    version (none) final bool __can_round_be_decided() const pure nothrow {
        bool inner_can_round_be_decided(const Round end_round) {
            if (end_round && majority) {
                const votes_mask = BitMask(end_round.events
                        .filter!(e => e !is null)
                        .map!(e => e.node_id));
                if (isMajority(votes_mask, node_size)) {

                }

            }
            return false;
        }

        return inner_can_round_be_decided(_next);
    }

    version (none) final bool update_round_decided() pure nothrow {
        bool inner_update_decision(const Round r) {
            if (_decided_round_yes) {
                return true;
            }
            if (r && r.majority) {
                node_size.iota
                    .filter!(n => _events[n] && r._events[n])
                    .each!(n => _events[n]._witness.decided_yes_mask |= r._events[n]._witness.decided_yes_mask);
                return inner_update_decision(r._next);

            }
            return false;
        }

        return majority && inner_update_decision(_next);
    }

    version (none) final bool update_round_decided() pure nothrow {
        bool inner_update_decided(Round v) {
            if (v && v.majority) {
                if (v !is _next) {
                    node_size.iota
                        .filter!(n => _events[n] && v._events[n])
                        .each!(n => _events[n].witness.decided_yes_mask |= v._events[n].witness.decided_yes_mask);

                }
                const number_of_voters = v._events.filter!(e => e !is null).count;
                const decided = _events
                    .filter!(e => e !is null)
                    .map!(e => e.witness)
                    .map!(w => w.decided(number_of_voters))
                    .all;
                if (decided) {
                    _voting = (_voting) ? v._next : v;
                    return _voting !is null;
                }
                return inner_update_decided(v._next);
            }
            return false;
        }

        if (majority) {
            version (none)
                if (!_voting) {
                    _events
                        .filter!(e => e !is null)
                        .map!(e => e.witness)
                        .each!(w => w.update_decision_mask);
                }
            return inner_update_decided(_next);

        }
        return false;
    }

    version (none) final bool update_round_decided(const HashGraph hashgraph) pure nothrow {
        import tagion.utils.Term;

        auto list_majority_rounds =
            this[].retro
                .drop(1)
                .until!(r => !r.majority);
        const _name = __format("%s%s%12s%s",
                BOLD,
                (this[].retro.drop(1).until!(r => !r.majority).count > 4) ? BLUE : WHITE,
        hashgraph.name,
        RESET);
        __write("%s Round %d update %d", _name, number, list_majority_rounds.walkLength);
        if (!list_majority_rounds.empty) {
            auto undecided_witnesses_mask = BitMask(
                    node_size.iota
                    .filter!(n => (_events[n] is null) || (!_events[n].witness.votedYes))
            );
            _events
                .filter!(e => e !is null)
                .map!(e => e.witness)
                .each!(w => w.update_decision_mask);
            if (undecided_witnesses_mask.empty) {
                return true;
            }
            //const _name = 
            //auto missing_witness = BitMask(node_size.iota.filter!(n => _events[n] is null));
            BitMask voting_witness_mask;
            size_t _n_voters;
            foreach (r; list_majority_rounds) {
                const round_increment = r.number - number;
                __write("%s Round %d->%d undecided=%#s %-(%s%)".replace("#", node_size.to!string), _name, number, r.number, undecided_witnesses_mask, "->"
                        .repeat(round_increment));
                if (round_increment == 1) {
                    voting_witness_mask = BitMask(
                            r.node_size.iota
                            .filter!(n => r._events[n]!is null));
                    __write("%s %sRound %d%s voting witness %#s".replace("#", node_size.to!string), _name,
                            CYAN,
                            number,
                            RESET,
                            voting_witness_mask);
                }
                else {
                    voting_witness_mask += voting_witness_mask.invert(r.node_size)[]
                        .filter!(n => r._events[n]!is null);
                }

                if (round_increment > 2) {
                    undecided_witnesses_mask -= undecided_witnesses_mask[]
                        .filter!(n => !voting_witness_mask[n] || _events[n] is null);
                    __write("%s %sRound %d%s voting witness %7s undecided=%7s", _name,
                            MAGENTA,
                            number,
                            RESET,
                            voting_witness_mask,
                            undecided_witnesses_mask);
                }

                const number_of_voters = voting_witness_mask.count;
                assert(_n_voters <= number_of_voters, "number of votes should not decrease");
                _n_voters = number_of_voters;
                undecided_witnesses_mask -= undecided_witnesses_mask[]
                    .filter!(n => (_events[n]!is null) && _events[n].witness.decided(number_of_voters));
                undecided_witnesses_mask[]
                    .filter!(n => _events[n]!is null)
                    .filter!(n => r._events[n]!is null)
                    .each!(n => _events[n].witness.decided_yes_mask |= r._events[n].witness.voted_yes_mask);
                if (undecided_witnesses_mask.empty) {
                    const all_decided = _events
                        .filter!(e => e !is null)
                        .map!(e => e.witness)
                        .map!(w => w.decided(number_of_voters))
                        .all;
                    if (all_decided) {
                        _voting = r;
                        __write("%s %sRound %d decided round %d%s yes=%(%d%)",
                                _name, GREEN, number, _voting.number, RESET,
                                _events.map!(e => (e !is null) && e.witness.votedYes));
                        return true;
                    }
                    __write("%s %sRound %d%s  votes=%d yes=%(%d %) decided=%(%d%)",
                            _name, RED, number, RESET,
                            number_of_voters,
                            _events.map!(e => (e is null) ? 0 : e.witness.decided_yes_mask.count),
                            _events.map!(e => (e is null) || e.witness.decided(number_of_voters))
                    );

                }
            }
        }
        return false;
    }
    /*
    final bool __can_round_be_decided() const pure nothrow {
        if (engulfed) {
            const _witness_mask = witness_mask;
            const _enclosed_witness_mask = enclosed_witness_mask;
            return  _enclosed_witness_mask.invert(_events.length)
            .map!(n => _witness_mask[0]
        }
        return false;
    }
    */
    /**
     * Remove the event from the round 
     * Params:
     *   event = event to be removed
     */
    @nogc
    package void remove(const(Event) event) nothrow
    in {
        assert(event.isEva || _events[event.node_id] is event,
        "This event does not exist in round at the current node so it can not be remove from this round");
        assert(event.isEva || !empty, "No events exists in this round");
    }
    do {
        if (!event.isEva && _events[event.node_id]) {
            _events[event.node_id] = null;
        }
    }

    /**
     * Scrap all rounds and events from this round and downwards 
     * Params:
     *   hashgraph = the hashgraph owning the events/rounds
     */
    private void scrap(HashGraph hashgraph) @trusted
    in {
        assert(!_previous, "Round can not be scrapped due that a previous round still exists");
    }
    do {
        uint count;
        void scrap_events(Event e) {
            if (e !is null) {
                count++;

                pragma(msg, "fixme(phr): make event remove work with eventview");
                version (none)
                    if (Event.callbacks) {
                        Event.callbacks.remove(e);
                    }
                scrap_events(e._mother);
                e.disconnect(hashgraph);
                e.destroy;
            }
        }

        foreach (node_id, e; _events) {
            scrap_events(e);
        }
        if (_next) {
            _next._previous = null;
            _next = null;
        }
    }
    /**
     * Previous round from this round
     * Returns: previous round
     */
    @nogc
    package final Round previous() pure nothrow {
        return _previous;
    }

    package final void accumulate_previous_seen_witness_mask(const(Event.Witness) w) nothrow {
        _common_previous_seen_witness_mask |= w.previous_witness_seen_mask;
    }

    final const pure nothrow @nogc {
        /**
     * Check of the round has no events
     * Returns: true of the round is empty
     */
        bool empty() {
            return !_events.any!((e) => e !is null);
        }

        const(BitMask) common_previous_seen_witness_mask() @nogc {
            return _common_previous_seen_witness_mask;
        }
        /**
     * Counts the number of events which has been set in this round
     * Returns: number of events set
     */
        size_t event_count() {
            return _events.count!((e) => e !is null);
        }

        const(Round) previous() {
            return _previous;
        }

        const(Round) next() {
            return _next;
        }

        /**
     * Get the event a the node_id 
     * Params:
     *   node_id = node id number
     * Returns: 
     *   Event at the node_id
     */
        const(Event) event(const size_t node_id) {
            return _events[node_id];
        }

        bool _isFamous() {
            return isMajority(_events
                    .filter!(e => e !is null)
                    .filter!(e => e.witness.votedYes)
                    .count,
                    _events.length);

        }

        bool majority() {
            return isMajority(_events
                    .filter!(e => e !is null)
                    .count,
                    _events.length);
        }

        uint decisions() {
            return cast(uint) _events
                .filter!(e => e !is null)
                .map!(e => e.witness)
                .filter!(w => w.decided)
                .count;
        }

        version (none) uint famous() {
            return cast(uint) _events
                .filter!(e => e !is null)
                .filter!(e => e.witness.votedYes)
                .count;
        }

        uint voters() {
            return cast(uint)(_events.filter!(e => e !is null).count);
        }
    }

    invariant {
        assert(!_previous || (_previous.number + 1 is number));
        assert(!_next || (_next.number - 1 is number));
    }

    /**
 * Range from this round and down
 * Returns: range of rounds 
 */
    @nogc
    package final Rounder.Range!false opSlice() pure nothrow {
        return Rounder.Range!false(this);
    }

    /// Ditto
    @nogc
    final Rounder.Range!true opSlice() const pure nothrow {
        return Rounder.Range!true(this);
    }

    /**
     * The rounder takes care of cleaning up old round 
     * and keeps track of if an round has been decided or can be decided
     */
    struct Rounder {
        Round last_round;
        Round last_decided_round;
        Round latest_famous_round;
        HashGraph hashgraph;
        Event[] last_witness_events;

        //Round[] voting_round_per_node;
        @disable this();

        this(HashGraph hashgraph) pure nothrow {
            this.hashgraph = hashgraph;
            last_round = new Round(null, hashgraph.node_size);
            last_witness_events.length = hashgraph.node_size;
            //voting_round_per_node = last_round.repeat(hashgraph.node_size).array;
        }

        private void update_latest_famous_round() pure nothrow {
            Round inner_latest_famous_round(Round r) {
                if (r && r._isFamous) {
                    return inner_latest_famous_round(r._next);
                }
                if (!r) {
                    return inner_latest_famous_round(last_decided_round);
                }
                return r;
            }

            latest_famous_round = inner_latest_famous_round(latest_famous_round);
        }

        uint count_feature_famous_rounds(const Round r) pure nothrow {
            update_latest_famous_round;
            return cast(uint)(latest_famous_round.number - r.number);
        }

        package void erase() {
            void local_erase(Round r) @trusted {
                if (r !is null) {
                    local_erase(r._previous);
                    r.scrap(hashgraph);
                    r.destroy;
                }
            }

            Event.scrapping = true;
            scope (exit) {
                Event.scrapping = false;
            }
            last_decided_round = null;
            local_erase(last_round);
        }

        /**
     * Sets the round for an event and creates an new round if needed
     * Params:
     *   e = event
     */
        void set_round(Event e) nothrow
        in {
            assert(!e._round, "Round has allready been added");
            assert(last_round, "Base round must be created");
            assert(last_decided_round, "Last decided round must exist");
            assert(e, "Event must create before a round can be added");
        }
        do {
            scope (exit) {
                if (e._witness) {
                    e._round.add(e);
                    const last_witness_event = last_witness_events[e.node_id];
                    if (last_witness_event) {
                        e._witness.separation = e.round.number - last_witness_event.round.number;
                    }
                    last_witness_events[e.node_id] = e;
                    update_latest_famous_round;

                    if (e._round.majority) {
                        version (none)
                            e._round
                                ._events
                                .filter!(e => e !is null)
                                .map!(e => e.witness)
                                .each!(w => w.update_decision_mask);
                        e._round._voting = null;
                    }
                }
            }
            e._round = e.maxRound;
            if (e._witness && e._round._events[e.node_id]) {
                if (e._round._next) {

                    e._round = e._round._next;
                    return;
                }
                e._round = new Round(last_round, hashgraph.node_size);
                last_round = e._round;
            }
        }

        //Cleans up old round and events if they are no-longer needed

        package
        void dustman() {
            void local_dustman(Round r) {
                if (r !is null) {
                    local_dustman(r._previous);
                    r.scrap(hashgraph);
                }
            }

            Event.scrapping = true;
            scope (exit) {
                Event.scrapping = false;
            }
            if (hashgraph.scrap_depth != 0) {
                int depth = hashgraph.scrap_depth;
                for (Round r = last_decided_round; r !is null; r = r._previous) {
                    depth--;
                    if (depth < 0) {
                        local_dustman(r);
                        break;
                    }
                }
            }
        }

        @nogc final const pure nothrow {
            /**
  * Number of round epoch in the rounder queue
  * Returns: size of the queue
   */
            size_t length() {
                return this[].walkLength;
            }

            bool isEventInLastDecidedRound(const(Event) event) {
                if (!last_decided_round) {
                    return false;
                }

                return last_decided_round.events
                    .filter!((e) => e !is null)
                    .map!(e => e.event_package.fingerprint)
                    .canFind(event.event_package.fingerprint);
            }

            /**
     * Check of a round has been decided
     * Params:
     *   test_round = round to be tested
     * Returns: 
     */
            version (none) bool decided(const Round r) {
                if (r) {
                    return (r.number - last_decided_round.number) <= 0;
                }
                return false;
            }

            /**
     * Calculates the number of rounds since the last decided round
     * Returns: number of undecided roundes 
     */
            long coin_round_distance() {
                return last_round.number - last_decided_round.number;
            }

            /**
     * Number of decided round in cached in memory
     * Returns: Number of cached decided rounds
     */

            uint cached_decided_count() {
                uint _cached_decided_count(const Round r, const uint i = 0) pure nothrow {
                    if (r) {
                        return _cached_decided_count(r._previous, i + 1);
                    }
                    return i;
                }

                return _cached_decided_count(last_round);
            }

            /**
     * Check the coin round limit
     * Returns: true if the coin round has been exceeded 
     */
            bool check_decided_round_limit() {
                return cached_decided_count > total_limit;
            }

        }
        enum rounds_beyond_limit = 3;
        void check_decide_round() {
            import tagion.utils.Term;

            auto round_to_be_decided = last_decided_round._next;
            if (!round_to_be_decided) {
                return;
            }
            const new_completed = round_to_be_decided.completed(hashgraph, round_to_be_decided._valid_witness);
            //const new_decided = round_to_be_decided.update_round_decided(hashgraph);
            auto witness_in_round = round_to_be_decided._events
                .filter!(e => e !is null)
                .map!(e => e.witness);
            const _name = format("%s%12s%s",
                    (round_to_be_decided[].retro.drop(1).until!(r => !r.majority).count > 4) ? BLUE : RESET,
            hashgraph.name,
            RESET);
            if (isMajority(witness_in_round.count, hashgraph.node_size)) {
                //                const __decision_mask = round_to_be_decided.enclosed_witness_mask | (round_to_be_decided.witness_mask & round_to_be_decided.enclosed_witness_mask.invert(round_to_be_decided._events.length));
                const count_feature_famous_rounds = count_feature_famous_rounds(round_to_be_decided);
                __write(
                        "%s #1 Round %4d | %(%(%s:%) %)  witness=%2d decision? %s w_masks=%(%7s %)",
                        _name,
                        round_to_be_decided
                        .number,
                        round_to_be_decided[].retro
                        .map!(r => r.events)
                        .map!(es => only(es.filter!(e => e !is null).count,
                            es.filter!(e => e !is null)
                            .filter!(e => e.witness.votedYes)
                            .count))
                        .take(10), //count_feature_famous_rounds,
                        witness_in_round.count,
                        witness_in_round.filter!(w => w.votedYes).count,
                        round_to_be_decided[].retro.drop(1).take(2)
                            .map!(r => r.witness_mask),
                );
                __write("%s #2 Round %d voted_yes_mask    = %(%7s %) witness=%d yes=%d separation=%(%d %)", _name,
                        round_to_be_decided.number,
                        round_to_be_decided._events.map!(e => (e is null) ? BitMask.init : e.witness.voted_yes_mask)
                        .take(10),
                        round_to_be_decided._events.filter!(e => e !is null).count,
                        round_to_be_decided._events
                        .filter!(e => e !is null)
                        .filter!(e => e.witness.votedYes)
                        .count,
                        round_to_be_decided._events.map!(e => (e is null) ? -1 : e.witness.separation)
                );
            }
            version (none)
                if (!can_round_be_decided(round_to_be_decided)) {
                    return;
                }
            version (none)
                if (!round_to_be_decided.__decision) {
                    return;
                }
            if (new_completed <= Completed.undecided) {
                return;
            }
            version (none)
                if (!new_decided) {
                    return;
                }
            __write(
                    "%s %s%sRound %d%s can be decided  witness=%d", // yes=%(%d%) ", //votes=%(%7s %) w_masks=%(%7s %)",
                    _name,
                    BOLD, GREEN,
                    round_to_be_decided.number,
                    RESET,
                    witness_in_round.walkLength, //round_to_be_decided._events.map!(e => (e !is null) && (e.witness.votedYes)),
                    //witness_in_round.map!(w => w.voted_yes_mask),
                    //round_to_be_decided[].retro.take(3).map!(r => r.witness_mask)

                    

            );
            Event.view(witness_in_round.map!(w => w.outer));
            version (none)
                if (!witness_in_round.map!(w => w.votedYes).all) {
                    return;
                }
            log("Round %d decided", round_to_be_decided.number);
            last_decided_round = round_to_be_decided;
            round_to_be_decided.decide;
            hashgraph.statistics.feature_famous_rounds(count_feature_famous_rounds(round_to_be_decided));
            log.event(Event.topic, hashgraph.statistics.feature_famous_rounds.stringof, hashgraph.statistics
                    .feature_famous_rounds);
            if (!isMajority(round_to_be_decided._valid_witness.count,
                    hashgraph.node_size)) {
                __write("%12s Round %d %sNot collected%s", hashgraph.name, round_to_be_decided.number, RED, RESET);
                return;
            }
            collect_received_round(round_to_be_decided);
            check_decide_round;
        }

        protected void collect_received_round(Round r)
        in (r.decided, "The round should be decided before the round can be collected")

        do {
            import tagion.utils.Term;

            auto witness_event_in_round = r._events.filter!(e => e !is null);
            Event[] majority_seen_from_famous(R)(R famous_witness_in_round) @safe if (isInputRange!R) {
                Event[] event_list;
                event_list.length = hashgraph.node_size * hashgraph.node_size;
                uint index;
                foreach (famous_witness; famous_witness_in_round) {
                    BitMask father_mask;
                    foreach (e; famous_witness[].until!(e => !e || e.round_received)) {
                        if (e._father && !father_mask[e._father.node_id]) {
                            father_mask[e._father.node_id] = true;
                            event_list[index++] = e;
                        }
                    }
                }
                event_list.length = index;
                return event_list;
            }

            auto famous_witness_in_round = witness_event_in_round
                .filter!(e => r._valid_witness[e.node_id]);
          version(none)
            witness_event_in_round
            .filter!(e => !r._valid_witness[e.node_id])
            .map!(e => e._witness)
            .each!(w => w.weak=true);
            version(none)
            Event.view(witness_event_in_round);
            
            auto event_list = majority_seen_from_famous(famous_witness_in_round);
            event_list
                .sort!((a, b) => Event.higher_order(a, b));
            BitMask[] famous_seen_masks;
            famous_seen_masks.length = hashgraph.node_size;

            Event[] event_front;
            event_front.length = hashgraph.node_size;
            foreach (e; event_list) {
                famous_seen_masks[e.node_id][e.node_id] = true;
                famous_seen_masks[e._father.node_id] |= famous_seen_masks[e.node_id];
                const top = isMajority(famous_seen_masks[e._father.node_id], hashgraph);
                if (!event_front[e._father.node_id] && isMajority(famous_seen_masks[e._father.node_id], hashgraph)) {
                    event_front[e._father.node_id] = e._father;
                }
            }
            bool done;
            do {
                done = true;
                foreach (e; event_front.filter!(e => e !is null)) {
                    foreach (e_father; e[]
                        .until!(e => !e || e.round_received)
                        .filter!(e => e._father)
                        .map!(e => e._father)
                        .filter!(e_father => !event_front[e_father.node_id] ||
                        e_father.order > event_front[e_father.node_id].order)
                    ) {
                        done = false;
                        event_front[e_father.node_id] = e_father;
                    }
                }
            }
            while (!done);

            event_front
                .filter!(e => e !is null)
                .each!(e => e.top = true);

            auto event_collection = event_front
                .filter!(e => e !is null)
                .map!(e => e[]
                .until!(e => e.round_received !is null))
                .joiner
                .array;
            event_collection.each!(e => e.round_received = r);
            Event.view(event_collection);
            hashgraph.statistics.epoch_events(event_collection.length);
            log.event(Event.topic, hashgraph.statistics.epoch_events.stringof, hashgraph.statistics.epoch_events);
            string show(const Event e) {
                if (e) {
                    return format("%s%d%s", (r._valid_witness[e.node_id]) ? GREEN : YELLOW, e.order, RESET);
                }
                return format("%sX %s", RED, RESET);
            }

            __write("%12s %sRound %d%s %d xepoch %-(%s %) collected=%d  separation=%(%d %) votes=%7s yes=%d  %(%d%) | %(%(%d%) %)",

                    hashgraph.name,
                    CYAN,
                    r.number,
                    RESET,
                    r.number,
                    r._events.map!(e => show(e)), event_collection.length,
                    r._events.map!(e => ((e is null) ? -1 : e.witness.separation)),
                    r._valid_witness,
                    r._valid_witness.count,
                    r.events.map!(e => (e !is null)),
                    r[].retro.drop(1).map!(rx => rx.events.map!(e => (e !is null))));
            
            hashgraph.epoch(event_collection, r);

        }

        /**
     * Call to collect and order the epoch
     * Params:
     *   r = decided round to collect events to produce the epoch
     *   hashgraph = hashgraph which owns this round
     */

        /**
         * Range from this round and down
         * Returns: range of rounds 
         */
        @nogc
        package Range!false opSlice() pure nothrow {
            return Range!false(last_round);
        }

        /// Ditto
        @nogc
        Range!true opSlice() const pure nothrow {
            return Range!true(last_round);
        }

        /**
     * Range of rounds 
     */
        @nogc
        struct Range(bool CONST = true) {
            private Round round;
            this(const Round round) pure nothrow @trusted {
                this.round = cast(Round) round;
            }

            pure nothrow {
                static if (CONST) {
                    const(Round) front() const {
                        return round;
                    }
                }
                else {
                    Round front() {
                        return round;
                    }
                }

                alias back = front;

                bool empty() const {
                    return round is null;
                }

                void popBack() {
                    round = round._next;
                }

                void popFront() {
                    round = round._previous;
                }

                Range save() {
                    return Range(round);
                }

            }

        }

        static assert(isInputRange!(Range!true));
        static assert(isForwardRange!(Range!true));
        static assert(isBidirectionalRange!(Range!true));
    }

}
