/// HashGraph Round
module tagion.hashgraph.Round;

//import std.stdio;

import std.datetime; // Date, DateTime
import std.algorithm.iteration : cache, each, filter, fold, joiner, map, reduce;
import std.algorithm.searching;
import std.algorithm.searching : all, any, canFind, count, until;
import std.algorithm.sorting : sort;
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
import tagion.hibon.HiBONRecord;
import tagion.logger.Logger;
import tagion.utils.BitMask : BitMask;
import tagion.utils.Miscellaneous;
import tagion.utils.StdTime;
import tagion.basic.Debug;

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
        last_witness
    }

    final Completed completed(const HashGraph hashgraph) const pure nothrow {
        import tagion.utils.Term;

        if (majority) {
            BitMask missing_witness;
            Completed ret;
            auto list_majority_rounds =
                this[].retro
                    .drop(1)
                    .until!(r => !r.majority);
            if (list_majority_rounds.empty) {
                return Completed.none;
            }
            scope (exit) {
                __write("%12s Round %d completed=%s  missing %7s -> %(%(%d%) %)", 
                hashgraph.name, 
                number, 
                ret, 
                missing_witness, 
                list_majority_rounds
                        .map!(r => r._events.map!(e => e !is null)));
            }
            const next_round=list_majority_rounds.front;
            missing_witness = BitMask(node_size.iota.filter!(n => next_round._events[n] is null));
            if (missing_witness.empty) {
                
                return ret = Completed.all_witness;
            }
            if (list_majority_rounds.empty) {
                return ret = Completed.majority_none;
            }
            { /// Marks witness not missing, if they exsists in the following majority rounds 
                auto _range = list_majority_rounds
                    .map!(r => missing_witness[].filter!(n => r._events[n]!is null))
                    .joiner
                    .until!(n => missing_witness.empty);
                foreach (n; _range) {
                    missing_witness[n] = false;
                }
                __write("%12s Round %d missing %7s list=%s", hashgraph.name, number, missing_witness, _range.take(10));
                if (missing_witness.empty) {
                    return ret = Completed.next_witness;
                }
            }
            const last_majority_round = list_majority_rounds.tail(1).front;
            missing_witness-=missing_witness[]
                .filter!(n => hashgraph.rounds.last_witness_events[n]!is null)
                .filter!(n => last_majority_round._events[n]!is null)
                .filter!(n => (last_majority_round.number - hashgraph.rounds.last_witness_events[n].round.number) >= 3);
            if (missing_witness.empty) {
                return ret = Completed.higher;
            }
            if (list_majority_rounds.take(2).walkLength < 2) {
                return ret = Completed.too_few;
            }
            {
                BitMask tmp_mask;
                const none_witness = list_majority_rounds
                    .take(2)
                    .map!(r => BitMask(r.node_size.iota.map!(n => r._events[n] is null)))
                    .fold!((a, b) => a | b)(tmp_mask);
                missing_witness -= none_witness;
                if (missing_witness.empty) {
                    return ret = Completed.missing;
                }
                __write("%12s Round %d %sMissing%s missing %7s none_witness=%7s", hashgraph.name, number, YELLOW, RESET, missing_witness, none_witness);
            }
            missing_witness[]
                .filter!(n => hashgraph.rounds.last_witness_events[n] is null)
                .each!(n => missing_witness[n] = false);
            if (missing_witness.empty) {
                return ret = Completed.last_witness;
            }
            return ret = Completed.undecided;
            //return ret = missing_witness.empty;
        }
        return Completed.none;
    }

    final const(BitMask) witness_mask() const pure nothrow {
        return BitMask(_events.filter!(e => e !is null)
                .map!(e => e.node_id));
    }

    version(none)
    final const(BitMask) enclosed_witness_mask() const pure nothrow {
        BitMask result;
        auto feature_rounds = this[].retro.drop(1).take(2);
        return feature_rounds.map!(r => r.witness_mask)
            .fold!((a, b) => a | b)(result);
    }
    version(none)
    final const(BitMask) __decision_mask() const pure nothrow {
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

        version(none)
    private bool _decided_round_yes() const pure nothrow {
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

    final bool update_round_decided(const HashGraph hashgraph) pure nothrow {
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
            foreach ( r; list_majority_rounds) {
                const round_increment=r.number-number; 
                __write("%s Round %d->%d undecided=%7s %-(%s%)", _name, number, r.number, undecided_witnesses_mask, "->".repeat(round_increment)); 
                if (round_increment == 1) {
                    voting_witness_mask = BitMask(
                            r.node_size.iota
                            .filter!(n => r._events[n]!is null));
                    __write("%s %sRound %d%s voting witness %7s", _name, 
                    CYAN,    
                number, 
                    RESET,
                voting_witness_mask);
                }
                else {
                    voting_witness_mask+=voting_witness_mask.invert(r.node_size)[]
                        .filter!(n => r._events[n]!is null);
                }
                
                if (round_increment > 2) {
                    undecided_witnesses_mask-=undecided_witnesses_mask[]
                        .filter!(n => !voting_witness_mask[n] || _events[n] is null);
                    __write("%s %sRound %d%s voting witness %7s undecided=%7s", _name, 
                        MAGENTA,
                        number, 
                        RESET,
                        voting_witness_mask,
                        undecided_witnesses_mask);
                }

                const number_of_voters=voting_witness_mask.count;
                assert(_n_voters <= number_of_voters, "number of votes should not decrease");
                _n_voters = number_of_voters;
                undecided_witnesses_mask-=undecided_witnesses_mask[]
                    .filter!(n => (_events[n]!is null) && _events[n].witness.decided(number_of_voters));
                undecided_witnesses_mask[]
                .filter!(n => _events[n] !is null)
                .filter!(n => r._events[n] !is null)
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
                            _name, GREEN, number,  _voting.number, RESET,
                        _events.map!(e => (e !is null) && e.witness.votedYes));
                        return true;
                    }
                        __write("%s %sRound %d%s  votes=%d yes=%(%d %) decided=%(%d%)", 
                            _name, RED, number,  RESET,
                        number_of_voters,
                        _events.map!(e => (e is null)?0: e.witness.decided_yes_mask.count),
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
                    const last_witness_event=last_witness_events[e.node_id];
                    if (last_witness_event) {
                        e._witness.separation=e.round.number-last_witness_event.round.number;
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
            const new_completed = round_to_be_decided.completed(hashgraph);
            const new_decided = round_to_be_decided.update_round_decided(hashgraph);
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
                        "%s #1 Round %4d | %(%(%s:%) %)  witness=%2d decision? %s yes=%d  w_masks=%(%7s %)",
                        _name,
                        round_to_be_decided
                        .number,
                        round_to_be_decided[].retro
                        .map!(r => r.events)
                        .map!(es => only(es.filter!(e => e !is null).count,
                            es.filter!(e => e !is null)
                            .filter!(e => e.witness.decidedYes)
                            .count)), //count_feature_famous_rounds,
                        witness_in_round.count,
                        format("%s%s", new_decided? GREEN ~ "yes" : RED ~ "no", RESET),
                        witness_in_round.filter!(w => w.decidedYes).count,
                        round_to_be_decided[].retro.drop(1).take(2)
                            .map!(r => r.witness_mask),
                );
                __write("%s #2 Round %d voted_yes_mask    = %(%7s %) witness=%d separation=%(%d %)", _name,
                        round_to_be_decided.number,
                        round_to_be_decided._events.map!(e => (e is null) ? BitMask.init : e.witness.voted_yes_mask),
                        round_to_be_decided._events.filter!(e => e !is null).count,
                        round_to_be_decided._events.map!(e => (e is null)?-1:e.witness.separation)
                        );
                __write(
                        "%s #2 Round %d decision_yes_mask = %(%7s %) voting round %d newYes=%(%d%)  %s completed=%s",
                        _name,
                        round_to_be_decided.number,
                        round_to_be_decided._events.map!(e => (e is null) ? BitMask.init : e.witness.decided_yes_mask),
                        round_to_be_decided.voting_number,
                        round_to_be_decided._events.map!(e => (e !is null) && e.witness.decidedYes),
                        format("%s%s", new_decided ? GREEN ~ "yes" : RED ~ "no", RESET),
                        new_completed
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
        
            if (!new_decided) {
                return;
            }
            __write(
                    "%s %s%sRound %d%s can be decided  witness=%d", // yes=%(%d%) ", //votes=%(%7s %) w_masks=%(%7s %)",
                    _name, 
                    BOLD, GREEN,
                    round_to_be_decided.number, 
                    RESET,
                    witness_in_round.walkLength,
                    //round_to_be_decided._events.map!(e => (e !is null) && (e.witness.votedYes)),
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
                if (!isMajority(round_to_be_decided.events
                        .filter!(e => e !is null)
                        .map!(e => e.witness.votedYes)
                        .count, hashgraph.node_size)) {
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
                .filter!(e => e._witness.votedYes);
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
                    return format("%s%d%s", (e._witness.decidedYes)?GREEN:YELLOW, e.altitude, RESET);
                }
                return format("%sX %s", RED, RESET);
            }
            __write("%12s %sRound %d%s %d witness %-(%s %) collected=%d separation=%(%d %) votes=%(%7s %) yes=%d voting=%-(%s %)", 
            hashgraph.name, 
            CYAN,
            r.number,
            RESET,
            r.number,
            r._events.map!(e => show(e)), event_collection.length,
            r._next._events.map!(e => (e is null)?-1:e.witness.separation),
            r._events.map!(e => (e is null)?BitMask.init:e.witness.voted_yes_mask),
            r._events.filter!(e => e !is null).filter!(e => e.witness.votedYes).count,
            r._events.map!(e => ((e is null) || !e.witness.votedYes)?null:e)
            .map!(e => show(e)));
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
