module tagion.hashgraph.Event;

import std.datetime;   // Date, DateTime
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;

import tagion.utils.Miscellaneous;

import tagion.gossip.InterfaceNet;
import tagion.basic.ConsensusExceptions;
import std.conv;
import std.bitmanip;

import std.format;
import std.typecons;
import std.traits : Unqual;

import tagion.basic.Basic : this_dot, basename, Pubkey, Buffer, Payload, bitarray_clear, bitarray_change, countVotes, EnumText;
import tagion.hashgraph.HashGraphBasic : isMajority;
import tagion.Keywords;

import tagion.basic.Logger;


/// check function used in the Event package
private alias check=Check!EventConsensusException;

// Returns the highest altitude
@safe @nogc
int highest(int a, int b) pure nothrow {
    if ( higher(a,b) ) {
        return a;
    }
    else {
        return b;
    }
}

// Is a higher or equal to b
@safe @nogc
bool higher(int a, int b) pure nothrow {
    return a-b > 0;
}

@safe @nogc
bool lower(int a, int b) pure nothrow {
    return a-b < 0;
}

@safe @nogc
unittest { // Test of the altitude measure function
    int x=int.max-10;
    int y=x+20;
    assert(x>0);
    assert(y<0);
    assert(highest(x,y) == y);
    assert(higher(y,x));
    assert(lower(x,y));
    assert(!lower(x,x));
    assert(!higher(x,x));
}

@safe
struct EventBody {
    immutable(ubyte)[] payload; // Transaction
    immutable(ubyte)[] mother; // Hash of the self-parent
    immutable(ubyte)[] father; // Hash of the other-parent
    int altitude;

    ulong time;
    invariant {
        if ( (mother.length != 0) && (father.length != 0 ) ) {
            assert( mother.length == father.length );
        }
    }

    this(
        Payload payload,
        Buffer mother,
        Buffer father,
        immutable ulong time,
        immutable int altitude) inout {
        this.time      =    time;
        this.altitude  =    altitude;
        this.father    =    father;
        this.mother    =    mother;
        this.payload   =    cast(Buffer)payload;
        consensus();
    }

    this(immutable(ubyte[]) data) inout {
        auto doc=Document(data);
        this(doc);
    }

    @nogc
    bool isEva() pure const nothrow {
        return (mother.length == 0);
    }

    this(Document doc, RequestNet request_net=null) inout {
        foreach(i, ref m; this.tupleof) {
            alias Type=typeof(m);
            alias UnqualT=Unqual!Type;
            enum name=basename!(this.tupleof[i]);
            if ( doc.hasElement(name) ) {
                static if ( name == mother.stringof || name == father.stringof ) {
                    if ( request_net ) {
                        immutable event_id=doc[name].get!uint;
                        this.tupleof[i]=request_net.eventHashFromId(event_id);
                    }
                    else {
                        this.tupleof[i]=(doc[name].get!type).idup;
                    }
                }
                else {
                    static if ( is(Type : immutable(ubyte[])) ) {
                        this.tupleof[i]=(doc[name].get!UnqualT).idup;
                    }
                    else {
                        this.tupleof[i]=doc[name].get!UnqualT;
                    }
                }
            }
        }
        consensus();
    }

    void consensus() inout {
        if ( mother.length == 0 ) {
            // Seed event first event in the chain
            check(father.length == 0, ConsensusFailCode.NO_MOTHER);
        }
        else {
            if ( father.length != 0 ) {
                // If the Event has a father
                check(mother.length == father.length, ConsensusFailCode.MOTHER_AND_FATHER_SAME_SIZE);
            }
            check(mother != father, ConsensusFailCode.MOTHER_AND_FATHER_CAN_NOT_BE_THE_SAME);
        }
    }

    HiBON toHiBON(const(Event) use_event=null) const {
        auto hibon=new HiBON;
        foreach(i, m; this.tupleof) {
            enum name=basename!(this.tupleof[i]);
            static if ( __traits(compiles, m.toHiBON) ) {
                hibon[name]=m.toHiBON;
            }
            else {
                bool include_member=true;
                static if ( __traits(compiles, m.length) ) {
                    include_member=m.length != 0;
                }
                if ( include_member ) {
                    if ( use_event && name == basename!mother &&  use_event._mother ) {
                        hibon[name]=use_event._mother.id;
                    }
                    else if ( use_event && name == basename!father && use_event._father ) {
                        hibon[name]=use_event._father.id;
                    }
                    else {
                        hibon[name]=m;
                    }
                }
            }
        }
        return hibon;
    }

    @trusted
    immutable(ubyte[]) serialize(const(Event) use_event=null) const {
        return toHiBON(use_event).serialize;
    }

}


@safe
class HashGraphException : Exception {
    this( immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

@safe
interface EventMonitorCallbacks {
    void create(const(Event) e);
    void witness(const(Event) e);
    void witness_mask(const(Event) e);
    void strongly_seeing(const(Event) e);
    void strong_vote(const(Event) e, immutable uint vote);
    void round_seen(const(Event) e);
    void looked_at(const(Event) e);
    void round_decided(const(Round) r);
    void round_received(const(Event) e);
    void coin_round(const(Round) r);
    void famous(const(Event) e);
    void round(const(Event) e);
    void son(const(Event) e);
    void daughter(const(Event) e);
    void forked(const(Event) e);
    void remove(const(Event) e);
    void remove(const(Round) r);
    void epoch(const(Event[]) received_event);
    void iterations(const(Event) e, const uint count);
}

@safe
interface EventScriptCallbacks {
    void epoch(const(Event[]) received_event, immutable long epoch_time);
    void send(ref Payload[] payloads, immutable long epoch_time); // Should be execute when and epoch is finished

    void send(immutable(EventBody) ebody);
    bool stop(); // Stops the task
}


@safe
class Round {
    enum uint total_limit = 3;
    enum int coin_round_limit = 10;
    private Round _previous;
    // Counts the number of nodes in this round
    immutable int number;
    private bool _decided;
    private static uint _decided_count;

    private BitArray _looked_at_mask;
    private uint _looked_at_count;
    static int increase_number(const(Round) r) {
        return r.number+1;
    }

    private Event[] _events;
    // Counts the witness in the round
    private uint _events_count;
    private static Round _rounds;
    // Last undecided round
    private static Round _undecided;
    //
    private BitArray _ground_mask;
    static void dump() {
        log("ROUND dump");
        for(Round r=_rounds; r !is null; r=r._previous) {
            log("\tRound %d %s", r.number, r.decided);
        }
    }

    @nogc
    bool lessOrEqual(const Round rhs) pure const nothrow {
        return (number - rhs.number) <= 0;
    }

    @nogc
    uint node_size() pure const nothrow {
        return cast(uint)_events.length;
    }

    private this(Round r, const uint node_size, immutable int round_number) {
        if ( r is null ) {
            // First round created
            _decided=true;
        }
        _previous=r;
        number=round_number;
        _events=new Event[node_size];
        bitarray_clear(_looked_at_mask, node_size);
        bitarray_clear(_ground_mask, node_size);
    }

    @nogc
    static bool check_decided_round_limit() nothrow {
         return _decided_count > total_limit;
    }

    private void disconnect()
        in {
            assert(_previous is null, "Only the last round can be disconnected");
            assert(_events_count == 0, "All witness must be removed before the round can be disconnected");
        }
    do {
        Round before;
        for(before=_rounds; (before !is null) && (before._previous !is this); before=before._previous) {
            // Empty
        }
        before._previous=null;
        _decided_count--;
    }

    private Round next_consecutive() {
        _rounds=new Round(_rounds, node_size, _rounds.number+1);
        return _rounds;
    }

    // Used to make than an witness in the next round at the node_id has looked at this round
    @trusted @nogc
    package void looked_at(const uint node_id) {
        if ( !_looked_at_mask[node_id] ) {
            _looked_at_mask[node_id]=true;
            _looked_at_count++;
        }
    }

    // Checked if all active nodes/events in this round has beend looked at
    @nogc
    bool seeing_completed() const pure nothrow {
        return _looked_at_count == node_size;
    }

    @nogc
    ref const(BitArray) looked_at_mask() pure const nothrow {
        return _looked_at_mask;
    }

    @nogc
    uint looked_at_count() pure const nothrow {
        return _looked_at_count;
    }

    package static Round seed_round(const uint node_size) {
        if ( _rounds is null ) {
            _rounds = new Round(null, node_size, -1);
        }
        // Use the latest round as seed round
        return _rounds;
    }

    static Round opCall(const int round_number)
        in {
            assert(_rounds, "Seed round has to exists before the operation is used");
        }
    do {
        Round find_round(Round r) pure nothrow {
            if ( r ) {
                if ( r.number == round_number ) {
                    return r;
                }
                return find_round(r._previous);
            }
            assert(0, "No round found");
        }
        immutable round_space=round_number - _rounds.number;
        if ( round_space == 1) {
            return _rounds.next_consecutive;
        }
        else if ( round_space <= 0 ) {
            return find_round(_rounds);
        }
        assert(0, "Round number must increase by one");
    }

    package int opApply(scope int delegate(const uint node_id, ref Event event) @safe dg) {
        int result;
        foreach(node_id, ref e; _events) {
            if ( e ) {
                result=dg(cast(uint)node_id, e);
                if ( result ) {
                    break;
                }
            }
        }
        return result;
    }

    int opApply(scope int delegate(const uint node_id, const(Event) event) @safe dg) const {
        int result;
        foreach(node_id, e; _events) {
            if ( e ) {
                result=dg(cast(uint)node_id, e);
                if ( result ) {
                    break;
                }
            }
        }
        return result;
    }

    @nogc
    package void add(Event event) nothrow
        in {
            assert(_events[event.node_id] is null, "Evnet should only be added once");
        }
    do {
        if ( _events[event.node_id] is null ) {
            _events_count++;
            _events[event.node_id]=event;
        }
    }

    @nogc
    package void remove(const(Event) e) nothrow
        in {
            assert(_events[e.node_id] is e, "This event does not exist in round at the current node so it can not be remove from this round");
            assert(_events_count > 0, "No events exists in this round");
        }
    do {
        if ( _events[e.node_id] ) {
            _events_count--;
            _events[e.node_id]=null;
        }
    }

    @nogc
    bool empty() pure const nothrow {
        return _events_count == 0;
    }

    // Return true if all witness in this round has been created
    @nogc
    bool completed() pure const nothrow {
        return _events_count == node_size;
    }

    @nogc
    inout(Event) event(const uint node_id) pure inout {
        return _events[node_id];
    }

    // Whole round decided
    @nogc
    bool decided() pure const nothrow {
        return _decided;
    }

    int coin_round_distance() const nothrow {
        if ( _undecided ) {
            return number-_undecided.number;
        }
        return 0;
    }

    package void check_coin_round() {
        if ( coin_round_distance >= coin_round_limit ) {
            log("coin round");
            // Force a coin round
            Round undecided=undecided_round;
            undecided.decide;
            if ( Event.callbacks ) {
                Event.callbacks.coin_round(undecided);
            }
        }
    }

    @trusted
    private bool ground(const uint node_id, ref const(BitArray) rhs) {
        _ground_mask[node_id]=true;
        return rhs == _ground_mask;
    }

    @nogc
    ref const(BitArray) ground_mask() pure const nothrow {
        return _ground_mask;
    }

    // @trusted
    // bool check_ground_mask(ref const(BitArray) rhs) {
    //     return rhs == _ground_mask;
    // }

    private void consensus_order() {
        import std.stdio;
            writeln("consensus order");
        import std.algorithm : sort, SwapStrategy;
        import std.functional;
                import tagion.hibon.HiBONJSON;
        scope Event[] famous_events=new Event[_events.length];
        BitArray unique_famous_mask;
        bitarray_change(unique_famous_mask, node_size);
        @trusted
        ulong find_middel_time() {
            try{
                writeln("finding middel time");
                uint famous_node_id;
                foreach(e; _events) {
                    if(e is null){
                        writeln("event is null");
                        stdout.flush();
                        // writeln(Document(e.toHiBON.serialize).toJSON);
                    }
                    if(e._witness is null){
                        writeln("witness is null");
                        stdout.flush();
                        writeln(Document(e.toHiBON.serialize).toJSON);
                    }else{
                        writeln("ok");
                        if (e._witness.famous) {
                            famous_events[famous_node_id]=e;
                            unique_famous_mask[famous_node_id]=true;
                            famous_node_id++;
                        }
                    }
                }
                famous_events.length=famous_node_id;
                // Sort the time stamps
                famous_events.sort!((a,b) => (Event.timeCmp(a,b) <0));
                writeln("famous sorted");
                // Find middel time
                immutable middel_time_index=(famous_events.length >> 2) + (famous_events.length & 1);
                writefln("middle time index: %d, len: %d", middel_time_index, famous_events.length);
                stdout.flush();
                scope(exit){
                    writeln("calc successfully");
                }
                return famous_events[middel_time_index].eventbody.time;
            }
            catch(Exception e){
                writeln("exc: ", e.msg);
                throw e;
            }
        }

        immutable middel_time=find_middel_time;
        immutable number_of_famous=cast(uint)famous_events.length;
        //
        // Clear round received counters
        //
        foreach(event; famous_events) {
            Event event_to_be_grounded;
            bool trigger;
            void clear_round_counters(Event e) {
                if ( e && !e.grounded ) {
                    if ( !trigger && e.round_received ) {
                        trigger=true;
                        event_to_be_grounded=e;
                    }
                    else if ( !e.round_received ) {
                        trigger=false;
                        event_to_be_grounded=null;
                    }
                    e.clear_round_received_count;
                    clear_round_counters(e._mother);
                }
            }
            clear_round_counters(event._mother);
            if ( event_to_be_grounded ) {
                event_to_be_grounded._grounded=true;
                if ( event_to_be_grounded._round._previous ) {
                    if ( event_to_be_grounded._round._previous.ground(event_to_be_grounded.node_id, unique_famous_mask) ) {
                        // scrap round!!!!
                    }
                }
            }
        }
        //
        // Select the round received events
        //
        Event[] round_received_events;
        foreach(event; famous_events) {
            Event.visit_marker++;
            void famous_seeing_count(Event e) {
                if ( e && !e.visit && !e.grounded ) {
                    if ( e.check_if_round_was_received(number_of_famous, this) ) {
                        round_received_events~=e;
                    }
                    famous_seeing_count(e._mother);
                    famous_seeing_count(e._father);
                }
            }
            famous_seeing_count(event);
        }
        //
        // Consensus sort
        //
        sort!((a,b) => ( a<b ), SwapStrategy.stable)(round_received_events);


        if ( Event.scriptcallbacks ) {
            import std.stdio;
            writefln("EPOCH received %d time=%d", round_received_events.length, middel_time);
            Event.scriptcallbacks.epoch(round_received_events, middel_time);
        }

        if ( Event.callbacks ) {
            Event.callbacks.epoch(round_received_events);
        }
   }

    private void decide()
        in {
            assert(!_decided, "Round should only be decided once");
            assert(this is Round.undecided_round, "Round can only be decided if it is the lowest undecided round in the round stack");
        }
    out{
        assert(_undecided._previous._decided, "Previous round should be decided");
    }
    do {
        Round one_over(Round r=_rounds) {
            if ( r._previous is this ) {
                return r;
            }
            return one_over(r._previous);
        }
        _undecided=one_over;
        _decided=true;
        _decided_count++;
        if ( Event.callbacks ) {
            foreach(seen_node_id, e; this) {
                Event.callbacks.famous(e);
            }
            Event.callbacks.round_decided(this);
        }
        consensus_order;
    }

    // Returns true of the round can be decided
    bool can_be_decided() const
        in {
            assert( _previous, "This is not a valid round to ask for a decision, because not round below exists");
        }
    do {
        if ( _decided ) {
            return true;
        }
        if ( seeing_completed && completed ) {
            if ( _previous ) {
                foreach(node_id, e; this) {
                    if ( !e._witness.famous_decided ) {
                        return false;
                    }
                }
                return true;
            }
        }
        return false;
    }

    // Find collecting round from which the famous votes is collected from the previous round
    package static Round undecided_round() {
        if ( !_undecided ) {
            Round search(Round r=_rounds) @safe {
                if ( r && r._previous && r._previous._decided ) {
                    return r;

                }
                return search(r._previous);
            }
            _undecided=search();
        }
        return _undecided;
    }

    @nogc
    inout(Round) previous() inout pure nothrow {
        return _previous;
    }

    // Find the lowest decide round
    static Round lowest() {
        Round local_lowest(Round r=_rounds) {
            if ( r ) {
                if ( r._decided && r._previous && (r._previous._previous is null ) ) {
                    return r;
                }
                return local_lowest(r._previous);
            }
            return null;
        }
        return local_lowest;
    }

    // Scrap the lowest Round
    static void scrap(H)(H hashgraph) {
        // Scrap the rounds and events below this
        void local_scrap(Round r) @trusted {
            foreach(node_id, ref e; r) {
                void scrap_event(Event e) {
                    if ( e ) {
                        scrap_event(e._mother);
                        if ( Event.callbacks ) {
                            Event.callbacks.remove(e);
                        }
                        hashgraph.eliminate(e.fingerprint);
                        e.disconnect;
                        e.destroy;
                    }
                }
                scrap_event(e._mother);
                if ( e ) {
                    assert(e._mother is null);
                }
            }
        }
        Round _lowest=lowest;
        if ( _lowest ) {
            local_scrap(_lowest);
        }
    }

    @nogc
    static uint decided_count() nothrow {
        return _decided_count;
    }

    invariant {
        void check_round_order(const Round r, const Round p) pure {
            if ( ( r !is null) && ( p !is null ) ) {
                assert( (r.number-p.number) == 1, "Consecutive round-numbers has to increase by one");
                if ( r._decided ) {
                    assert( p._decided, "If a higher round is decided all rounds below must be decided");
                }
                check_round_order(r._previous, p._previous);
            }
        }
        check_round_order(this, _previous);
    }
}


@safe
class Event {
    protected enum _params = [
        "altitude",   // altitude
        Keywords.pubkey,
        Keywords.signature,
        // "pubkey",
        // "signature" Keywords.,
        "type",
        "event",
        "ebody",

        ];

    mixin(EnumText!("Params", _params));


    @safe
    class Witness {
        private Event _previous_witness_event;
        private BitArray _famous_decided_mask;
        private bool     _famous_decided;
        private BitArray _strong_seeing_mask;
        // This vector shows what we can see in the previous witness round
        // Round seeing masks from next round
        private BitArray _round_seen_mask;
        private uint     _round_seen_count;
        private uint     _famous_votes;
        @trusted
        this(Event owner_event, Event previous_witness_event, ref const(BitArray) strong_seeing_mask)
        in {
            assert(strong_seeing_mask.length > 0);
            assert(owner_event);
        }
        do {
            _strong_seeing_mask=strong_seeing_mask.dup;
            _famous_decided_mask.length=node_size;
            _previous_witness_event=previous_witness_event;
            _round_seen_mask.length=node_size;
        }

        @nogc
        uint node_size() pure const nothrow {
            return cast(uint)_strong_seeing_mask.length;
        }

        @nogc
        inout(Event) previous_witness_event() inout pure nothrow {
            return _previous_witness_event;
        }

        @nogc
        ref const(BitArray) strong_seeing_mask() pure const nothrow {
            return _strong_seeing_mask;
        }

        @trusted
        package void seeing_previous_round(Event owner_event) {
            import std.stdio;
            void update_round_seeing(Event event, string indent="") @trusted {
                if ( event ) {
                    if ( !event.visit ) {
                        immutable round_distance = owner_event._round.number - event._round.number;
                        if ( event.witness ) {
                            if ( !event._round.seeing_completed ) {
                                if ( round_distance == 1 ) {
                                    event.witness.round_seen_vote(owner_event.node_id);
                                    event._round.looked_at(owner_event.node_id);
                                    if ( Event.callbacks ) {
                                        Event.callbacks.round_seen(event);
                                        Event.callbacks.looked_at(event);
                                    }
                                }
                                update_round_seeing(event._mother, indent~"  ");
                                update_round_seeing(event._father, indent~"  ");
                            }
                        }
                        else if ( round_distance  <= 1 ) {
                            foreach(seeing_node_id, e; event._round) {
                                if ( event.witness_mask[seeing_node_id] ) {
                                    update_round_seeing(e, indent~"  ");
                                }
                            }
                        }
                    }
                }
            }
            // Update the visit marker to prevent infinity recusive loop
            Event.visit_marker++;
            update_round_seeing(owner_event.mother, "::");
            update_round_seeing(owner_event.father,  "::");
        }


        @nogc
        ref const(BitArray) round_seen_mask() pure const nothrow {
            return _round_seen_mask;
        }

        @trusted
        package void round_seen_vote(const uint node_id) {
            if ( !_round_seen_mask[node_id] ) {
                _round_seen_mask[node_id] = true;
                _round_seen_count++;
            }
        }

        @trusted
        package void famous_vote(ref const(BitArray) strong_seeing_mask) {
            if ( !_famous_decided ) {
                const BitArray vote_mask=strong_seeing_mask & _round_seen_mask;
                immutable votes=countVotes(vote_mask);
                if ( votes > _famous_votes ) {
                    _famous_votes = votes;
                }
                if ( isMajority(votes, node_size ) ) {
                    _famous_decided_mask|=vote_mask;
                    if ( _famous_decided_mask == _round_seen_mask ) {
                        // Famous decided if all the round witness has been seen with majority
                        _famous_decided=true;
                    }
                }
            }
        }

        @trusted
        bool famous_decided() pure const nothrow {
            return _famous_decided;
        }

        @nogc
        uint famous_votes() pure const nothrow {
            return _famous_votes;
        }

        @nogc
        bool famous() pure const nothrow {
            return isMajority(_famous_votes, node_size);
        }

    }

    alias Event delegate(immutable(ubyte[]) fingerprint, Event child) @safe Lookup;
    alias bool delegate(Event) @safe Assign;
    static EventMonitorCallbacks callbacks;
    static EventScriptCallbacks scriptcallbacks;
//    import std.stdio;
//    static File* fout;
    immutable(ubyte[]) signature;
    immutable(Buffer) pubkey;
    @nogc
    immutable(Pubkey) channel() pure const nothrow {
        return Pubkey(pubkey);
    }

    // Recursive markes
    private uint _visit;
    package static uint visit_marker;
    @nogc
    private bool visit() nothrow {
        scope(exit) {
            _visit = visit_marker;
        }
        return (_visit == visit_marker);
    }
    // The altitude increases by one from mother to daughter
    immutable(EventBody) event_body;

    private Buffer _fingerprint;
    // This is the internal pointer to the
    private Event _mother;
    private Event _father;
    private Event _daughter;
    private Event _son;
    private bool _grounded;
    private int _received_order;
    private Round  _round;
    private Round  _round_received;
    private uint _round_received_count;
    // The withness mask contains the mask of the nodes
    // Which can be seen by the next rounds witness

    private Witness _witness;
    private uint _witness_votes;
    private BitArray _witness_mask;

    @nogc
    private uint node_size() pure const nothrow {
        return cast(uint)witness_mask.length;
    }

    private bool _strongly_seeing_checked;

    private bool _loaded;
    // This indicates that the hashgraph aften this event
    private bool _forked;
    immutable uint id;
    private static uint id_count;

    @nogc
    private static immutable(uint) next_id() nothrow {
        if ( id_count == id_count.max ) {
            id_count = 1;
        }
        else {
            id_count++;
        }
        return id_count;
    }

    HiBON toHiBON() const {
        auto hibon=new HiBON;
        foreach(i, m; this.tupleof) {
            enum member_name=basename!(this.tupleof[i]);
            static if ( member_name == basename!(event_body) ) {
                enum name=Params.ebody;
            }
            else {
                enum name=member_name;
            }
            static if ( name[0] != '_' ) {
                static if ( __traits(compiles, m.toHiBON) ) {
                    hibon[name]=m.toHiBON;
                }
                else {
                    hibon[name]=m;
                }
            }
        }
        return hibon;
    }

    @nogc
    static int timeCmp(const(Event) a, const(Event) b) pure nothrow {
        immutable diff=cast(long)(b.eventbody.time) - cast(long)(a.eventbody.time);
        if ( diff < 0 ) {
            return -1;
        }
        else if ( diff > 0 ) {
            return 1;
        }

        if ( a.signature < b.signature ) {
            return -1;
        }
        else {
            return 1;
        }
        assert(0, "This should be improbable to have two equal signatures");
    }

    @nogc
    int opCmp(const(Event) rhs) const pure nothrow {
        immutable diff=rhs._received_order - _received_order;
        if ( diff < 0 ) {
            return -1;
        }
        else if ( diff > 0 ) {
            return 1;
        }
//            immutable result=signature < rhs.signature;
        if ( signature < rhs.signature ) {
            return -1;
        }
        else {
            return 1;
        }
        assert(0, "This should be improbable to have two equal signatures");
    }

    private bool check_if_round_was_received(const uint number_of_famous, Round received) {
        if ( !_round_received ) {
            _round_received_count++;
            if ( _round_received_count == number_of_famous ) {
                _round_received=received;
                if ( callbacks ) {
                    callbacks.round_received(this);
                }
                return true;
            }
        }
        return false;
    }

    @nogc
    private void clear_round_received_count() pure nothrow {
        if ( !_round_received ) {
            _round_received_count=0;
        }
    }

    @nogc
    const(Round) round_received() pure const nothrow {
        return _round_received;
    }

    @nogc
    bool isFront() pure const nothrow {
        return _daughter is null;
    }

    @nogc
    inout(Round) round() inout pure nothrow
    out(result) {
        assert(result, "Round should be defined before it is used");
    }
    do {
        return _round;
    }

    @nogc
    bool hasRound() const pure nothrow {
        return (_round !is null);
    }

    // This function markes the witness in the previous round which
    // See this the witness
    @trusted // FIXME: trusted should be removed after debugging
    package void collect_famous_votes() {
        import std.stdio;
        void collect_votes(Round previous_round) @safe {
            if ( previous_round && !previous_round._decided ) {
                collect_votes( previous_round._previous );
                foreach(seen_node, e; previous_round) {
                    e._witness.famous_vote(_witness.strong_seeing_mask);
                }
                if ( previous_round._previous ) {
                    if ( ( previous_round is Round.undecided_round ) && previous_round.can_be_decided ) {
                        previous_round.decide;
                    }
                }
            }
        }
        if ( _witness && !isEva  ) {
            collect_votes(_round._previous);
        }
    }

    @nogc
    const(Round) round() pure const nothrow
    out(result) {
        assert(result, "Round must be set before this function is called");
    }
    do {
        return _round;
    }

    @nogc
    Round round() nothrow
        in {
            if ( motherExists ) {
                assert(_mother, "Graph has not been resolved");
            }
        }
    out(result) {
        assert(result, "No round was found for this event");
    }
    do {
        if ( !_round ) {
            _round=_mother._round;
        }
        return _round;
    }

    uint witness_votes(immutable uint node_size) {
        witness_mask(node_size);
        return _witness_votes;
    }

    @nogc
    uint witness_votes() pure const nothrow
        in {
            assert(is_witness_mask_checked);
        }
    do {
        return _witness_votes;
    }

    @nogc
    bool is_witness_mask_checked() pure const nothrow {
        return _witness_mask.length != 0;
    }


    package ref const(BitArray) witness_mask(immutable uint node_size) {
        ref BitArray check_witness_mask(Event event, immutable uint level=0) @trusted
            in {
                assert(event);
            }
        do {
            if ( !event.is_witness_mask_checked ) {
                bitarray_clear(event._witness_mask, node_size);
                if ( event._witness ) {
                    if ( !event._witness_mask[event.node_id] ) {
                        event._witness_votes++;
                    }
                    event._witness_mask[event.node_id]=true;
                }
                else {
                    if ( event.mother ) {
                        auto mask=check_witness_mask(event.mother, level+1);
                        if ( mask.length < event._witness_mask.length ) {
                            mask.length = event._witness_mask.length;
                        }
                        else if ( mask.length > event._witness_mask.length ) {
                            event._witness_mask.length = mask.length;
                        }

                        event._witness_mask|=mask;

                    }
                    if ( event.father ) {
                        auto mask=check_witness_mask(event.father, level+1);
                        if ( mask.length < event._witness_mask.length ) {
                            mask.length = event._witness_mask.length;
                        }
                        else if ( mask.length > event._witness_mask.length ) {
                            event._witness_mask.length = mask.length;
                        }

                        event._witness_mask|=mask;
                    }
                    event._witness_votes=countVotes(_witness_mask);
                }
            }
            bitarray_change(event._witness_mask, node_size);
            return event._witness_mask;
        }
        return check_witness_mask(this);
    }


    @nogc
    ref const(BitArray) witness_mask() pure const nothrow
        in {
            assert(is_witness_mask_checked);
        }
    do {
        return _witness_mask;
    }

    @nogc
    const(Witness) witness() pure const nothrow {
        return _witness;
    }

    @nogc
    package Witness witness() pure {
        return _witness;
    }

    @trusted
    package void strongly_seeing(Event previous_witness_event, ref const(BitArray) strong_seeing_mask)
        in {
            assert(!_strongly_seeing_checked);
            assert(_witness_mask.length != 0);
            assert(previous_witness_event);
        }
    do {
        bitarray_clear(_witness_mask, node_size);
        _witness_mask[node_id]=true;
        if ( _father && _father._witness !is null ) {
            _witness_mask|=_father.witness_mask;
        }
        _witness=new Witness(this, previous_witness_event, strong_seeing_mask);
        next_round;
        _witness.seeing_previous_round(this);
        if ( callbacks ) {
            callbacks.strongly_seeing(this);
            callbacks.round(this);
        }
    }

    private void next_round() {
        // The round number is increased by one
        _round=Round(_mother._round.number+1);
        // Event added to round
        _round.add(this);

    }

    @nogc
    bool strongly_seeing() const pure nothrow {
        return _witness !is null;
    }

    @nogc
    void strongly_seeing_checked() nothrow
        in {
            assert(!_strongly_seeing_checked);
        }
    do {
        _strongly_seeing_checked=true;
    }

    @nogc
    bool is_strongly_seeing_checked() const pure nothrow {
        return _strongly_seeing_checked;
    }

    @trusted
    bool seeing_witness(const uint node_id) const pure
        in {
            assert(_witness, "Seeing witness can only be called from witness event");
        }
    do {
        bool result;
        if ( mother ) {
            if ( mother.witness_mask[node_id] ) {
                result=true;
            }
            else if ( _round.lessOrEqual(mother._round) ) {
                result=mother._round.event(mother.node_id).seeing_witness(node_id);
            }
        }
        else if ( father ) {
            if ( father.witness_mask[node_id] ) {
                result=true;
            }
            else if ( _round.lessOrEqual(father._round) ) {
                result=father._round.event(father.node_id).seeing_witness(node_id);
            }
        }
        return result;
    }

    void forked(bool s)
        in {
            if ( s ) {
                assert(!_forked, "An event can not unforked");
            }
        }
    do {
        _forked = s;
        if ( callbacks && _forked ) {
            callbacks.forked(this);
        }
    }


    @nogc
    bool forked() const pure nothrow {
        return _forked;
    }

    @nogc
    immutable(int) altitude() const pure nothrow {
        return event_body.altitude;
    }

    immutable uint node_id;
// FixMe: CBR 19-may-2018
// Note pubkey is redundent information
// The node_id should be enought this will be changed later
    this(
        ref immutable(EventBody) ebody,
        RequestNet request_net,
        immutable(ubyte[]) signature,
        Pubkey pubkey,
        const uint node_id,
        const uint node_size) {
        event_body=ebody;
        this.node_id=node_id;
        this.id=next_id;
        _fingerprint=request_net.calcHash(event_body.serialize);
        this.signature=signature;
        this.pubkey=cast(Buffer)pubkey;

        if ( isEva ) {
            // If the event is a Eva event the round is undefined
            BitArray strong_mask;
            bitarray_clear(strong_mask, node_size);
            _witness = new Witness(this, null, strong_mask);
            _round = Round.seed_round(node_size);
            _round.add(this);
            _received_order=-1;
        }

    }

// Disconnect the Event from the graph
    @trusted
    void disconnect() {
        if ( _son ) {
            _son._father=null;
        }
        if ( _daughter ) {
            _daughter._grounded=true;
            _daughter._mother=null;
        }
        if ( _father ) {
            _father._son=null;
        }
        _mother=_father=null;
        _daughter=_son=null;
        if ( _witness ) {
            assert(_round.event(node_id) is this);
            _round.remove(this);
            _witness.destroy;
            _witness=null;
            if ( _round.empty ) {
                if ( Event.callbacks ) {
                    Event.callbacks.remove(_round);
                }
                _round.disconnect;
                _round.destroy;
                _round=null;
            }
        }
    }

    @nogc
    bool grounded() pure const nothrow {
        return _grounded || (_mother is null);
    }


    Event mother(H)(H h, RequestNet request_net) {
        Event result;
        result=mother!true(h);
        if ( !result && motherExists ) {
            request_net.request(h, mother_hash);
            result=mother(h);
        }
        return result;
    }

    @nogc
    int received_order_max(const(Event) e, const bool increase=false) pure const nothrow {
        int result=_received_order;
        if ( e && ( ( _received_order - e._received_order ) < 0 ) ) {
            result=e._received_order;
        }
        if ( increase ) {
            result++;
            if ( result < 0 ) {
                result=0;
            }
        }
        return result;
    }

    @nogc
    int received_order() pure const nothrow {
        return _received_order;
    }

    private Event mother(bool ignore_null_check=false, H)(H h)
        out(result) {
            static if ( !ignore_null_check) {
                if ( mother_hash ) {
                    assert(result, "the mother is not found");
                }
            }
        }
    do {
        if ( _mother is null ) {
            _mother = h.lookup(mother_hash);
            if ( _mother ) {
                _received_order=_mother.received_order_max(_father, true);
            }
        }
        return _mother;
    }

    @nogc
    inout(Event) mother() inout pure nothrow
    in {
        assert(!_grounded, "This event is grounded");
        if ( mother_hash ) {
            assert(_mother);
            assert( (altitude-_mother.altitude) == 1 );
        }
    }
    do {
        return _mother;
    }

    Event father(bool ignore_null_check=false, H)(H h)
        out(result) {
            static if ( !ignore_null_check) {
                if ( father_hash ) {
                    assert(result, "the father is not found");
                }
            }
            assert(!_grounded, "This event is grounded");
        }
    do {
        if ( _father is null ) {
            _father = h.lookup(father_hash);
            if ( _father ) {
                _received_order=_father.received_order_max(_mother, true);
            }
        }
        return _father;
    }

    Event father(H)(H h, RequestNet request_net) {
        Event result;
        result=father!true(h);
        if ( !result && fatherExists ) {
            request_net.request(h, father_hash);
            result=father(h);
        }
        return result;
    }

    @nogc
    inout(Event) father() inout pure nothrow
    in {
        if ( father_hash ) {
            assert(_father);
        }
    }
    do {
        return _father;
    }

    @nogc
    inout(Event) daughter() inout pure nothrow {
        return _daughter;
    }

    void daughter(Event c)
        in {
            if ( _daughter !is null ) {
                assert( c !is null, "Daughter can not be set to null");
            }
        }
    do {
        if ( _daughter && (_daughter !is c) ) {
            forked = true;
        }
        else {
            _daughter=c;
            if ( callbacks ) {
                callbacks.daughter(this);
            }

        }
    }

    @nogc
    inout(Event) son() inout pure nothrow {
        return _son;
    }

    void son(Event c)
        in {
            if ( _son !is null ) {
                assert( c !is null, "Son can not be set to null");
            }
        }
    do {
        if ( _son && (_son !is c) ) {
            forked=true;
        }
        else {
            _son=c;
            if ( callbacks ) {
                callbacks.son(this);
            }
        }
    }

    @nogc
    void loaded() nothrow
        in {
            assert(!_loaded, "Event can only be loaded once");
        }
    do {
        _loaded=true;
    }

    @nogc
    bool is_loaded() const pure nothrow {
        return _loaded;
    }

    @nogc
    immutable(ubyte[]) father_hash() const pure nothrow {
        return event_body.father;
    }

    @nogc
    immutable(ubyte[]) mother_hash() const pure nothrow {
        return event_body.mother;
    }

    @nogc
    immutable(ubyte[]) payload() const pure nothrow {
        return event_body.payload;
    }

    @nogc
    ref immutable(EventBody) eventbody() const pure nothrow {
        return event_body;
    }

//True if Event contains a payload or is the initial Event of its creator
    @nogc
    bool containPayload() const pure nothrow {
        return payload.length != 0;
    }

    @nogc
    bool motherExists() const pure nothrow
        in {
            assert(!_grounded, "This function should not be used on a grounded event");
        }
    do {
        return event_body.mother !is null;
    }

    @nogc
    bool fatherExists() const pure nothrow {
        return event_body.father !is null;
    }

// is true if the event does not have a mother or a father
    @nogc
    bool isEva() pure const nothrow
        in {
            assert(!_grounded, "This event is gounded");
        }
    do {
        return !motherExists;
    }

    @nogc
    immutable(Buffer) fingerprint() const pure nothrow
    in {
        assert(_fingerprint, "Hash has not been calculated");
    }
    do {
        return _fingerprint;
    }

    int opApply(scope int delegate(immutable uint level,
            immutable bool mother ,const(Event) e) @safe dg) const {
        int iterator(const(Event) e, immutable bool mother=true, immutable uint level=0) @safe {
            int result;
            if ( e ) {
                result = dg(level, mother, e);
                if ( result == 0 ) {
                    iterator(e.mother, true, level+1);
                    iterator(e.father, false, level+1);
                }
            }
            return result;
        }
        return iterator(this);
    }

}

unittest { // Serialize and unserialize EventBody
    import std.digest.sha;
    Payload payload=cast(immutable(ubyte)[])"Some payload";
//    auto mother=SHA256(cast(uint[])"self").digits;
    immutable mother=sha256Of("self");
    immutable father=sha256Of("other");
    auto seed_body=EventBody(payload, mother, father, 0, 0);

    auto raw=seed_body.serialize;

    auto replicate_body=EventBody(raw);

    // Raw and repicate should be the same
    assert(seed_body == replicate_body);
//    auto seed_event=new Event(seed_body);
}
