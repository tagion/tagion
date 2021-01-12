module tagion.hashgraph.HashGraph;

import std.stdio;
import std.conv;
import std.format;
import std.bitmanip : BitArray;
import tagion.hashgraph.Event;
import tagion.gossip.InterfaceNet;
import tagion.utils.LRU;
import tagion.hibon.Document;
import tagion.utils.Miscellaneous;
import tagion.basic.ConsensusExceptions;

import tagion.basic.Basic : Pubkey, Buffer, bitarray_clear, countVotes;
import Basic=tagion.hashgraph.HashGraphBasic;

import tagion.basic.Logger;

private alias check=Check!HashGraphConsensusException;

@safe
class HashGraph : Basic.HashGraphI {
    import tagion.utils.Statistic;
    //alias Pubkey=immutable(ubyte)[];
    alias Privkey=immutable(ubyte)[];
    //alias HashPointer=RequestNet.HashPointer;
    private GossipNet _gossip_net;
    private uint iterative_tree_count;
    private uint iterative_strong_count;
    private Statistic!uint iterative_tree;
    private Statistic!uint iterative_strong;
    //alias LRU!(Round, uint*) RoundCounter;
    alias Sign=immutable(ubyte)[] function(Pubkey, Privkey,  immutable(ubyte)[] message);
    // List of rounds
    package Round.Rounder _rounds;

    this() {
        _rounds=Round.Rounder(this);
    }

    @nogc
    Round.Rounder rounds() pure nothrow {
        return _rounds;
    }

    void request_net(GossipNet net) nothrow
        in {
            assert(_gossip_net is null, "RequestNet has already been set");
        }
    do {
        _gossip_net=net;
    }

    alias EventPackageCache=immutable(EventPackage)*[const(ubyte[])];
    alias EventCache=Event[const(ubyte[])];

    protected {
        EventPackageCache _event_package_cache;
        EventCache _event_cache;
    }

    // final bool isRegistered(scope immutable(ubyte[]) fingerprint) pure {
    //     return _request_net.isRegistered(fingerprint);
    // }

    // final Event register(immutable(Buffer) fingerprint) {
    //     return _request_net.register(fingerprint);
    // }

    final Event lookup(scope const(ubyte[]) fingerprint) {
        if (fingerprint in _event_cache) {
            return _event_cache[fingerprint];
        }
        else if (fingerprint in _event_package_cache) {
            auto event_pack=_event_package_cache[fingerprint];
            _event_package_cache.remove(fingerprint);
            auto event=new Event(event_pack, this);
            _event_cache[fingerprint]=event;
            //event.register(this);
            return event;
        }
        return null;
    }

    void eliminate(scope const(ubyte[]) fingerprint) {
        _event_cache.remove(fingerprint);
    }

    size_t number_of_registered_event() const pure nothrow {
        return _event_cache.length;
    }

    bool isRegistered(scope const(ubyte[]) fingerprint) const pure nothrow {
        return (fingerprint in _event_cache) !is null;
    }

    bool isCached(scope const(ubyte[]) fingerprint) const pure nothrow {
        return (fingerprint in _event_package_cache) !is null;
    }

    void cache(scope const(ubyte[]) fingerprint, immutable(EventPackage*) event_package) nothrow
        in {
            assert(fingerprint !in _event_package_cache, "Event has already been registered");
        }
    do {
        _event_package_cache[fingerprint] = event_package;
    }

    Event registerEvent(
        immutable(EventPackage*) event_pack)
        in {
            assert(event_pack.fingerprint !in _event_cache, format("Event %s has already been registerd", event_pack.fingerprint.toHexString));
        }
    do {
        auto event=new Event(event_pack, this);
        _event_cache[event.fingerprint]=event;
        //event.register(this);
        return event;
    }


    void register_wavefront() {
        foreach(fingerprint, event_package; _event_package_cache) {
            auto current_event = Event.register(this, fingerprint);
            auto current_node = getNode(current_event.pubkey);
            if (highest(current_event.altitude, current_node.event.altitude)) {
                // If the current event is in front of the wave the wave front is set to the current event
                current_node.event = current_event;
            }
            //register(current_event);
        }
    }

    @safe
    static class Node {
        ExchangeState state;
        immutable uint node_id;
//        immutable ulong discovery_time;
        immutable(Pubkey) pubkey;
        @nogc
        this(Pubkey pubkey, uint node_id) pure nothrow {
            this.pubkey=pubkey;
            this.node_id=node_id;

//            this.discovery_time=time;
        }

        private Event _event; // Latest event
        package Event latest_witness_event; // Latest witness event

        version(none)
        @nogc
        final package Event previous_witness() nothrow pure
            in {
                assert(!latest_witness_event.isEva, "No previous witness exist for an Eva event");
            }
        do {
            return latest_witness_event._round._events[latest_witness_event];
        }

        @nogc
        final package void event(Event e) nothrow
            in {
                assert(e);
                assert(e.son is null);
                assert(e.daughter is null);
            }
        do {
            if ( _event is null ) {
                _cache_altitude=e.altitude;
                _event=e;
            }
            else if ( lower(_event.altitude, e.altitude) ) {
                altitude=e.altitude;
                _event=e;
            }
            if ( _event.witness ) {
                latest_witness_event=_event;
            }
        }

        @nogc
        final const(Event) event() pure const nothrow
            in {
                if ( _event && _event.witness ) {
                    assert(_event is latest_witness_event);
                }
            }
        do {
            return _event;
        }

        @nogc void remove() nothrow {
            state = ExchangeState.NONE;
            _event = null;
            latest_witness_event = null;
        }

        @nogc
        final bool isOnline() pure const nothrow {
            return (_event !is null);
        }

        // This is the altiude of the cache Event
        private int _cache_altitude;

        @nogc
        final void altitude(int a) nothrow
            in {
                if ( _event ) {
                    assert(_event.daughter is null);
                }
            }
        do {
            int result=_cache_altitude;
            if ( _event ) {
                _cache_altitude=highest(_event.altitude, _cache_altitude);
            }
            _cache_altitude=highest(a, _cache_altitude);
        }

        @nogc
        final int altitude() pure const nothrow
            in {
                assert(_event !is null, "This node has no events so the altitude is not set yet");
            }
        do {
            return _cache_altitude;
        }

        @nogc
        struct Range(bool also_ground) {
            private Event current;
            @trusted
            this(const Event event) pure nothrow {
                current=cast(Event)event;
            }

            @property pure nothrow {
                bool empty() const {
                    static if (also_ground) {
                        return (current is null) || current.grounded;
                    }
                    else {
                        return current is null;
                    }
                }

                const(Event) front() const {
                    return current;
                }

                void popFront() {
                    current = current.mother_raw;
                }


                // void popFront() {
                //     current = current.mother_raw;
                // }
            }
        }

        @nogc
        Range!false opSlice() const pure nothrow {
            return Range!false(_event);
        }

        invariant {
            if ( latest_witness_event ) {
                assert(latest_witness_event.witness);
            }
        }
    }

    @nogc
    const(uint) node_size() const pure nothrow {
        return cast(uint)(nodes.length);
    }

    private Node[uint] nodes; // List of participating nodes T
    private uint[Pubkey] node_ids; // Translation table from pubkey to node_indices;
    private uint[] unused_node_ids; // Stack of unused node ids



    @nogc
    Range opSlice() const pure nothrow {
        return Range(this);
    }

    @nogc
    bool isOnline(Pubkey pubkey) pure nothrow const {
        return (pubkey in node_ids) !is null;
    }

    bool createNode(Pubkey pubkey) pure nothrow {
        if ( pubkey in node_ids ) {
            return false;
        }
        auto node_id=cast(uint)node_ids.length;
        node_ids[pubkey]=node_id;
        auto node=new Node(pubkey, node_id);
        nodes[node_id]=node;
        return true;
    }

    const(uint) nodeId(scope Pubkey pubkey) const pure {
        auto result=pubkey in node_ids;
        check(result !is null, ConsensusFailCode.EVENT_NODE_ID_UNKNOWN);
        return *result;
    }

    void setAltitude(scope Pubkey pubkey, const(int) altitude) {
        auto nid=pubkey in node_ids;
        check(nid !is null, ConsensusFailCode.EVENT_NODE_ID_UNKNOWN);
        auto n=nodes[*nid];
        n.altitude=altitude;
    }

    @nogc
    bool isNodeIdKnown(scope Pubkey pubkey) const pure nothrow {
        return (pubkey in node_ids) !is null;
    }

    void dumpNodes() {
        import std.stdio;
        foreach(i, n; nodes) {
            log("%d:%s:", i, n !is null);
            if ( n !is null ) {
                log("%s ",n.pubkey[0..7].toHexString);
            }
            else {
                log("Non ");
            }
        }
        log("");
    }

    struct Range {
//        private HashGraph _owner;
        alias NodeRange=typeof(const(HashGraph).nodes.byValue);
        private NodeRange r;
//        Result r;
        @nogc
        this(const HashGraph owner) nothrow pure {
            r = owner.nodes.byValue;
        }

        @nogc @property pure nothrow {
            bool empty() {
                return r.empty;
            }

            const(Node) front() {
                return r.front;
            }

            void popFront() {
                r.popFront;
            }

        }
    }

    @nogc
    Pubkey nodePubkey(const uint node_id) pure const nothrow {
        auto node=node_id in nodes;
        if ( node ) {
            return node.pubkey;
        }
        else {
            Pubkey _null;
            return _null;
        }
    }

    @nogc
    bool isNodeActive(const uint node_id) pure const nothrow {
        return (node_id in nodes) !is null;
    }

    version(none)
    void assign(Event event)
        in {
            assert(_gossip_net !is null, "RequestNet must be set");
        }
    do {
        auto node=getNode(event.channel);
        node.event=event;
        _hashgraph.register(event.fingerprint, event);
//        _event_cache[event.fingerprint]=event;
        if ( event.isEva ) {
            node.latest_witness_event=event;
        }
    }

    // Returns the number of active nodes in the network
    @nogc
    uint active_nodes() const pure nothrow {
        return cast(uint)(node_ids.length);
    }

    @nogc
    uint total_nodes() const pure nothrow {
        return cast(uint)(node_ids.length+unused_node_ids.length);
    }

    inout(Node) getNode(const uint node_id) inout pure nothrow {
        return nodes[node_id];
    }

    inout(Node) getNode(Pubkey pubkey) inout pure {
        return getNode(nodeId(pubkey));
    }

    @nogc
    bool isMajority(const uint voting) const pure nothrow {
        return Basic.isMajority(voting, active_nodes);
    }

    private void remove_node(Node n)
        in {
            import std.format;
            assert(n !is null);
            assert(n.node_id < total_nodes);
            assert(n.node_id in nodes, format("Node id %d is not removable because it does not exist", n.node_id));
        }
    do {
        nodes.remove(n.node_id);
        node_ids.remove(n.pubkey);
        unused_node_ids~=n.node_id;
    }

    enum max_package_size=0x1000;
//    alias immutable(Hash) function(immutable(ubyte)[]) @safe Hfunc;
    enum round_clean_limit=10;

    version(none)
    Event registerEvent(
//        RequestNet request_net,
        // Pubkey pubkey,
        // immutable(ubyte[]) signature,
        immutable(EventPackage*) event_pack)
        in {
            assert(_request_net !is null, "RequestNet must be set");
        }
    do {
        return _request_net.lookup(event_pack);
        // auto event=new Event(event_pack, this);
        // event.register(this);

        // return event;
    }

    version(none)
    Event registerEvent(
//        RequestNet request_net,
        // Pubkey pubkey,
        // immutable(ubyte[]) signature,
        immutable(EventPackage*) event_pack)
        in {
            assert(_request_net !is null, "RequestNet must be set");
        }
    do {

        immutable pubkey=event_pack.pubkey;
        immutable ebody=event_pack.event_body.serialize;
        immutable fingerprint=_request_net.calcHash(ebody);
        if ( Event.scriptcallbacks ) {
            // Sends the eventbody to the scripting engine
            Event.scriptcallbacks.send(event_pack.event_body);
        }
        Event event=_request_net.lookup(fingerprint);
        if ( !event ) {
            auto get_node_id=pubkey in node_ids;
            uint node_id;
            Node node;

            // Find a reusable node id if possible
            if ( get_node_id is null ) {
                if ( unused_node_ids.length ) {
                    node_id=unused_node_ids[0];
                    unused_node_ids=unused_node_ids[1..$];
                    node_ids[pubkey]=node_id;
                }
                else {
                    node_id=cast(uint)node_ids.length;
                    node_ids[pubkey]=node_id;
                }
                node=new Node(pubkey, node_id);
                nodes[node_id]=node;
            }
            else {
                node_id=*get_node_id;
                node=nodes[node_id];
            }

            event=new Event(event_pack, this, node_id, node_size);

            // Add the event to the event cache
            assign(event);

            // Makes sure that we have the event tree before the graph is checked
            iterative_tree_count=0;
            requestEventTree(event);

            // See if the node is strong seeing the hashgraph
            iterative_strong_count=0;
            Event.set_marker;
            strongSee(event);

            const round_has_been_decided=event.collect_famous_votes;
            if ( round_has_been_decided ) {
                log.trace("After round decision the event cache contains %d", _request_net.number_of_registered_event);
            }
            event.round.check_coin_round;

            if ( Round.check_decided_round_limit) {
                 // Scrap the lowest round which is not need anymore
                scrap;
            }

            if ( Event.callbacks ) {
                Event.callbacks.round(event);
                if ( iterative_strong_count > 0 ) {
                    Event.callbacks.iterations(event, iterative_strong_count);
                }
                Event.callbacks.witness_mask(event);
            }


        }
        if (iterative_strong_count > 0) {
            const result=iterative_strong(iterative_strong_count).result;

            log.trace("Strong iterations=%d [%d:%d] mean=%s std=%s", iterative_strong_count,
                result.min, result.max, result.mean, result.sigma);
        }
        if (iterative_tree_count > 0) {
            const result=iterative_tree(iterative_tree_count).result;

            log.trace("Register iterations=%d [%d:%d] mean=%s std=%s", iterative_tree_count,
                result.min, result.max, result.mean, result.sigma);
        }
        return event;
    }

    version(none)
    protected void scrap() {
        // Scrap the rounds and events below this
        import std.algorithm.searching : all;
        import std.algorithm.iteration : each;

        void local_scrap(Round r) @trusted {
            log.trace("Try to remove round %d", r.number);
            if (r[].all!(a => (a is null) || (a.round_received !is null))) {
                log.trace("Remove and disconnection round in %d", r.number);
                //import core.memory : GC;
//                log.fatal("round.decided=%s round=%d usedSize=%d", r._decided, r.number, GC.stats.usedSize);
//                r.range.each!(a => a._grounded = true);
                r.range.each!((a) => {if (a !is null) {a.disconnect; pragma(msg, typeof(a));}});
                // foreach(e; r.range) {
                //     if (e) {
                //         e.disconnect(this);
                //     }
                // }

            }
//             version(none) {
//                 scope round_numbers = new int[r.node_size];
//                 scope round_received_numbers = new int[r.node_size];
//                 bool sealed_round=true;
//                 // scope(exit) {
//                 //     log.fatal("round.decided=%s", r._decided);
//                 //     log.fatal("   round:%s", round_numbers);
//                 //     log.fatal("received:%s", round_received_numbers);
//                 //     if (sealed_round) {
//                 //         //   log.fatal("ROUND Sealed!!");
//                 //         log.fatal("ROUND Sealed!! %s", r[].all!(a => a._mother.round_received !is null));
//                 //     }
//                 // }

//                 foreach(node_id, e; r[].enumerate) {
// //                e._mother._grounded=true;
//                     round_numbers[node_id]=r.number;
//                     if (e._mother.round_received) {
// //                    sealed_round &= (e._mother.round_received.number == r.number+1);

//                         round_received_numbers[node_id]=e._mother.round_received.number;
//                     }
//                     else {
// //                    sealed_round=false;
//                         round_received_numbers[node_id]=-1;
// //                    log.fatal("node_id=%d round=%d NO ROUND_RECEIVED !!!", node_id, r.number);
//                     }
//                     // void scrap_event(Event e) {
//                     //     if ( e ) {
//                     //         scrap_event(e._mother);
//                     //         if ( Event.callbacks ) {
//                     //             Event.callbacks.remove(e);
//                     //         }
//                     //         hashgraph.eliminate(e.fingerprint);
//                     //         e.disconnect;
//                     //         e.destroy;
//                     //     }
//                     // }
//                     // scrap_event(e._mother);
//                     // if ( e ) {
//                     //     assert(e._mother is null);
//                     // }
//                 }
//             }
        }
        Round _lowest=Round.lowest;
//        version(none)
        if ( _lowest ) {
            local_scrap(_lowest);
            _lowest.__grounded=true;
            log("Round scrapped");
        }
    }

    /**
       This function makes sure that the HashGraph has all the events connected to this event
    */
    version(none)
    protected void requestEventTree(Event event)
        in {
            assert(_request_net !is null, "RequestNet must be set");
        }
    do {
        iterative_tree_count++;
        if ( event && ( !event.is_loaded ) ) {
            event.loaded;

            auto mother=event.mother(_request_net);
            requestEventTree(mother);
            if ( mother ) {
                mother.daughter=event;
            }
            auto father=event.father_x(_request_net);
            requestEventTree(father);
            if ( father ) {
                father.son=event;
            }

            if ( Event.callbacks ) {
                Event.callbacks.create(event);
            }

        }
    }


    version(none)
    @trusted
    package void strongSee(Event top_event) {
        if ( top_event && !top_event.is_strongly_seeing_checked && !top_event.is_marked) {
            top_event.mark;
            strongSee(top_event.mother_raw);
            strongSee(top_event.father_raw);
            if ( isMajority(top_event.witness_votes(total_nodes)) ) {
                scope BitArray[] witness_vote_matrix=new BitArray[total_nodes];
                scope BitArray strong_vote_mask;
                uint seeing;
                bool strong;
                const round=top_event.round;
                @trusted
                    void checkStrongSeeing(Event check_event, const BitArray path_mask) {
                    iterative_strong_count++;
                    if ( check_event && round.lessOrEqual(check_event.round) ) {
                        // && !check_event.is_strongly_seeing_checked ) {
                        const BitArray checked_mask=strong_vote_mask & check_event.witness_mask(total_nodes);
                        const check=(checked_mask != check_event.witness_mask);
                        if ( check ) {

                            if ( !strong_vote_mask[check_event.node_id] ) {
                                scope BitArray common=witness_vote_matrix[check_event.node_id] | path_mask;
                                if ( common != witness_vote_matrix[check_event.node_id] ) {
                                    witness_vote_matrix[check_event.node_id]=common;

                                    immutable votes=countVotes(witness_vote_matrix[check_event.node_id]);
                                    if ( isMajority(votes) ) {
                                        strong_vote_mask[check_event.node_id]=true;
                                        seeing++;
                                    }
                                }
                            }
                            /+
                             The father event is searched first to cross as many nodes as fast as possible
                             +/
                            if ( path_mask[check_event.node_id] ) {
                                checkStrongSeeing(check_event.father_raw, path_mask);
                                checkStrongSeeing(check_event.mother_raw, path_mask);
                            }
                            else {
                                scope BitArray sub_path_mask=path_mask.dup;
                                sub_path_mask[check_event.node_id]=true;

                                checkStrongSeeing(check_event.father_raw, sub_path_mask);
                                checkStrongSeeing(check_event.mother_raw, sub_path_mask);
                            }
                        }
                    }
                }

                BitArray path_mask;
                bitarray_clear(path_mask, total_nodes);
                bitarray_clear(strong_vote_mask, total_nodes);
                foreach(node_id, ref mask; witness_vote_matrix) {
                    bitarray_clear(mask, total_nodes);
                    mask[node_id]=true;
                }
                checkStrongSeeing(top_event, path_mask);
                strong=isMajority(seeing);
                if ( strong ) {
                    auto previous_witness_event=nodes[top_event.node_id].latest_witness_event;
                    top_event.strongly_seeing(previous_witness_event, strong_vote_mask);
                    nodes[top_event.node_id].latest_witness_event=top_event;
                    log("Strong votes=%d id=%d %s", seeing, top_event.id, cast(string)(top_event.payload));
                }
                top_event.strongly_seeing_checked;
                if ( Event.callbacks ) {
                    Event.callbacks.strong_vote(top_event, seeing);
                }
            }
        }
    }

    version(none)
    unittest { // strongSee
        // This is the example taken from
        // HASHGRAPH CONSENSUS
        // SWIRLDS TECH REPORT TR-2016-01
        import tagion.crypto.SHA256;
        import std.traits;
        import std.conv;
        enum NodeLable {
            Alice,
            Bob,
            Carol,
            Dave,
            Elisa
        }
        struct Emitter {
            Pubkey pubkey;
        }
        auto h=new HashGraph;
        Emitter[NodeLable.max+1] emitters;
//        writefln("@@@ Typeof Emitter=%s %s", typeof(emitters).stringof, emitters.length);
        foreach (immutable l; [EnumMembers!NodeLable]) {
//            writefln("label=%s", l);
            emitters[l].pubkey=cast(Pubkey)to!string(l);
        }
        ulong current_time;
        uint dummy_index;
        ulong dummy_time() {
            current_time+=1;
            return current_time;
        }
        Hash hash(immutable(ubyte)[] data) {
            return new SHA256(data);
        }
        immutable(EventBody) newbody(immutable(EventBody)* mother, immutable(EventBody)* father) {
            dummy_index++;
            if ( father is null ) {
                auto hm=hash(mother.serialize).digits;
                return EventBody(null, hm, null, dummy_time);
            }
            else {
                auto hm=hash(mother.serialize).digits;
                auto hf=hash(father.serialize).digits;
                return EventBody(null, hm, hf, dummy_time);
            }
        }
        // Row number zero
        writeln("Row 0");
        // EventBody* a,b,c,d,e;
        with(NodeLable) {
            immutable a0=EventBody(hash(emitters[Alice].pubkey).digits, null, null, 0);
            immutable b0=EventBody(hash(emitters[Bob].pubkey).digits, null, null, 0);
            immutable c0=EventBody(hash(emitters[Carol].pubkey).digits, null, null, 0);
            immutable d0=EventBody(hash(emitters[Dave].pubkey).digits, null, null, 0);
            immutable e0=EventBody(hash(emitters[Elisa].pubkey).digits, null, null, 0);
            h.registerEvent(emitters[Bob].pubkey,   b0, &hash);
            h.registerEvent(emitters[Carol].pubkey, c0, &hash);
            h.registerEvent(emitters[Alice].pubkey, a0, &hash);
            h.registerEvent(emitters[Elisa].pubkey, e0, &hash);
            h.registerEvent(emitters[Dave].pubkey,  d0, &hash);

            // Row number one
            writeln("Row 1");
            alias a0 a1;
            alias b0 b1;
            immutable c1=newbody(&c0, &d0);
            immutable e1=newbody(&e0, &b0);
            alias d0 d1;
            //with(NodeLable) {
            h.registerEvent(emitters[Carol].pubkey, c1, &hash);
            h.registerEvent(emitters[Elisa].pubkey, e1, &hash);

            // Row number two
            writeln("Row 2");
            alias a1 a2;
            immutable b2=newbody(&b1, &c1);
            immutable c2=newbody(&c1, &e1);
            alias d1 d2;
            immutable e2=newbody(&e1, null);
            h.registerEvent(emitters[Bob].pubkey,   b1, &hash);
            h.registerEvent(emitters[Carol].pubkey, c1, &hash);
            h.registerEvent(emitters[Elisa].pubkey, e1, &hash);
            // Row number 2 1/2
            writeln("Row 2 1/2");

            alias a2 a2a;
            alias b2 b2a;
            alias c2 c2a;
            immutable d2a=newbody(&d2, &c2);
            alias e2 e2a;
            h.registerEvent(emitters[Dave].pubkey,  d2a, &hash);
            // Row number 3
            writeln("Row 3");

            immutable a3=newbody(&a2, &b2);
            immutable b3=newbody(&b2, &c2);
            immutable c3=newbody(&c2, &d2);
            alias d2a d3;
            immutable e3=newbody(&e2, null);
            //
            h.registerEvent(emitters[Alice].pubkey, a3, &hash);
            h.registerEvent(emitters[Bob].pubkey,   b3, &hash);
            h.registerEvent(emitters[Carol].pubkey, c3, &hash);
            h.registerEvent(emitters[Elisa].pubkey, e3, &hash);
            // Row number 4
            writeln("Row 4");


            immutable a4=newbody(&a3, null);
            alias b3 b4;
            alias c3 c4;
            alias d3 d4;
            immutable e4=newbody(&e3, null);
            //
            h.registerEvent(emitters[Alice].pubkey, a4, &hash);
            h.registerEvent(emitters[Elisa].pubkey, e4, &hash);
            // Row number 5
            writeln("Row 5");
            alias a4 a5;
            alias b4 b5;
            immutable c5=newbody(&c4, &e4);
            alias d4 d5;
            alias e4 e5;



            //

            h.registerEvent(emitters[Carol].pubkey, c5, &hash);
            // Row number 6
            writeln("Row 6");

            alias a5 a6;
            alias b5 b6;
            immutable c6=newbody(&c5, &a5);
            alias d5 d6;
            alias e5 e6;

            //
            h.registerEvent(emitters[Alice].pubkey, a6, &hash);
        }
        writeln("Row end");

    }

}
