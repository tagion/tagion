module tagion.hashgraph.HashGraph;

import std.stdio;
import std.conv;
import tagion.hashgraph.Event;
import tagion.gossip.InterfaceNet;
import tagion.utils.LRU;
import tagion.hibon.Document;
import tagion.utils.Miscellaneous;
import tagion.basic.ConsensusExceptions;
import std.bitmanip : BitArray;
import tagion.basic.Basic : Pubkey, Buffer, bitarray_clear, countVotes;
import Basic=tagion.hashgraph.HashGraphBasic;

import tagion.basic.Logger;

private alias check=Check!HashGraphConsensusException;

@safe
class HashGraph {
    //alias Pubkey=immutable(ubyte)[];
    alias Privkey=immutable(ubyte)[];
    //alias HashPointer=RequestNet.HashPointer;
    alias LRU!(Buffer, Event) EventCache;

    private uint iterative_tree_count;
    private uint iterative_strong_count;
    //alias LRU!(Round, uint*) RoundCounter;
    alias Sign=immutable(ubyte)[] function(Pubkey, Privkey,  immutable(ubyte)[] message);
    private EventCache _event_cache;
    // List of rounds
    private Round _rounds;


    this() pure nothrow {
        _event_cache=new EventCache(null);
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

        @nogc
        final package Event previous_witness() nothrow pure
            in {
                assert(!latest_witness_event.isEva, "No previous witness exist for an Eva event");
            }
        do {
            return latest_witness_event.witness.previous_witness_event;
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

                // void popFront() {
                //     current = current.mother_raw;
                // }
            }
                void popFront() {
                    current = current.mother_raw;
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
    uint node_size() const pure nothrow {
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

    void assign(Event event) {
        auto node=getNode(event.channel);
        node.event=event;
        _event_cache[event.fingerprint]=event;
        if ( event.isEva ) {
            node.latest_witness_event=event;
        }
    }

    Event lookup(scope immutable(ubyte[]) fingerprint) {
        return _event_cache[fingerprint];
    }

    void eliminate(scope immutable(ubyte[]) fingerprint) {
        _event_cache.remove(fingerprint);
    }

    bool isRegistered(scope immutable(ubyte[]) fingerprint) pure {
        return _event_cache.contains(fingerprint);
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
            assert(n !is null);
            assert(n.node_id < total_nodes);
            assert(n.node_id in nodes, "Node id "~to!string(n.node_id)~" is not removable because it does not exist");
        }
    do {
        nodes.remove(n.node_id);
        node_ids.remove(n.pubkey);
        unused_node_ids~=n.node_id;
    }

    enum max_package_size=0x1000;
//    alias immutable(Hash) function(immutable(ubyte)[]) @safe Hfunc;
    enum round_clean_limit=10;
    Event registerEvent(
        RequestNet request_net,
        Pubkey pubkey,
        immutable(ubyte[]) signature,
        ref immutable(EventBody) eventbody) {
        immutable ebody=eventbody.serialize;
        immutable fingerprint=request_net.calcHash(ebody);
        if ( Event.scriptcallbacks ) {
            // Sends the eventbody to the scripting engine
            Event.scriptcallbacks.send(eventbody);
        }
        Event event=lookup(fingerprint);
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

            event=new Event(eventbody, request_net, signature, pubkey, node_id, node_size);

            // Add the event to the event cache
            assign(event);

            // Makes sure that we have the event tree before the graph is checked
            iterative_tree_count=0;
            requestEventTree(request_net, event);

            // See if the node is strong seeing the hashgraph
            iterative_strong_count=0;
            strongSee(event);

            event.collect_famous_votes;

            event.round.check_coin_round;

            // if ( Round.check_decided_round_limit) {
            //     // Scrap the lowest round which is not need anymore
            //     event.round.scrap(this);
            // }

            if ( Event.callbacks ) {
                Event.callbacks.round(event);
                if ( iterative_strong_count != 0 ) {
                    Event.callbacks.iterations(event, iterative_strong_count);
                }
                Event.callbacks.witness_mask(event);
            }

        }
        return event;
    }

    /**
       This function makes sure that the HashGraph has all the events connected to this event
    */
    protected void requestEventTree(RequestNet request_net, Event event, Event child=null, immutable bool is_father=false) {
        iterative_tree_count++;
        if ( event && ( !event.is_loaded ) ) {
            event.loaded;

            auto mother=event.mother(this, request_net);
            requestEventTree(request_net, mother, event, false);
            if ( mother ) {
                mother.daughter=event;
            }
            auto father=event.father(this, request_net);
            requestEventTree(request_net, father, event, true);
            if ( father ) {
                father.son=event;
            }

            if ( Event.callbacks ) {
                Event.callbacks.create(event);
            }

        }
    }


    @trusted
    package void strongSee(Event top_event) {
        if ( top_event && !top_event.is_strongly_seeing_checked ) {

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
