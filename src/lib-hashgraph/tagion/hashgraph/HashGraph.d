module tagion.hashgraph.HashGraph;

import std.stdio;
import std.conv;
//import tagion.hashgraph.Store;
import tagion.hashgraph.Event;
import tagion.hashgraph.GossipNet;
import tagion.utils.LRU;
import tagion.utils.BSON : Document;
import tagion.crypto.Hash;
import tagion.hashgraph.ConsensusExceptions;
import std.bitmanip : BitArray;
import tagion.Base : Pubkey, Buffer, bitarray_clear, countVotes;
import Base=tagion.Base;

@safe
class HashGraph {
    //alias Pubkey=immutable(ubyte)[];
    alias Privkey=immutable(ubyte)[];
    //alias HashPointer=RequestNet.HashPointer;
    alias LRU!(Buffer, Event) EventCache;
//    private uint visit;

    private uint iterative_tree_count;
    private uint iterative_strong_count;
    //alias LRU!(Round, uint*) RoundCounter;
    alias immutable(ubyte)[] function(Pubkey, Privkey,  immutable(ubyte)[] message) Sign;
    private EventCache _event_cache;
    // List of rounds
    private Round _rounds;
    // private GossipNet _gossip_net;


    this() {
        _event_cache=new EventCache(null);
//        _gossip_net=gossip_net;
        //_round_counter=new RoundCounter(null);
    }

    // package static Round find_previous_round(Event event) {
    //     Event e;
    //     for (e=event; e && !e.round; e=e.mother) {
    //         // Empty
    //     }
    //     return e.round;
    // }

    @safe
    class Node {
        ExchangeState state;
        // Is set if local has initiated an communication with this node
//        bool initiator;
        //DList!(Event) queue;
        // private BitArray _famous_mask;
        // private uint _famous_votes;
        immutable uint node_id;
//        immutable ulong discovery_time;
        immutable(Pubkey) pubkey;
        this(Pubkey pubkey, uint node_id) {
            this.pubkey=pubkey;
            this.node_id=node_id;
//            this.discovery_time=time;
        }
        // void updateRound(Round round) {
        //     this.round=round;
        // }
        // Counts the number of times that a search has
        // passed this node in the graph search
        int passed;
//        uint seeing; // See a witness
        bool voted;
        // uint voting;
        private Event _event; // Latest event
        package Event latest_witness_event; // Latest witness event

        package Event previous_witness()
        in {
            assert(!latest_witness_event.isEva, "No previous witness exist for an Eva event");
        }
        do {
            return latest_witness_event.witness.previous_witness_event;
        }

        package void event(Event e)
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


        const(Event) event() pure const nothrow
        in {
            if ( _event && _event.witness ) {
                assert(_event is latest_witness_event);
            }
        }
        do {
            return _event;
        }


        bool isOnline() pure const nothrow {
            return (_event !is null);
        }
        // This is the altiude of the cache Event
        private int _cache_altitude;

        void altitude(int a)
            in {
                if ( _event ) {
//                    assert(_event.son is null);
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

        int altitude() pure const nothrow
            in {
                assert(_event !is null, "This node has no events so the altitude is not set yet");
            }
        do {
            return _cache_altitude;
        }

        int opApply(scope int delegate(const(Event) e) @safe dg) const
            in {
                if ( _event ) {
                    //                  assert(_event.son is null);
                    assert(_event.daughter is null);
                }
            }
        do {
            int iterate(const(Event) e) @safe {
                int result;
                if ( e ) {
                    result=dg(e);
                    if ( result == 0 ) {
                        iterate(e.mother);
                    }
                }
                return result;

            }
            return iterate(_event);
        }

        version(node)
        protected void vote_famous(Event witness_event)
            in {
                Event.fout.writefln("collect_round=%s latest_witness.round=%s isEva=%s", witness_event.round.number,  previous_witness.round.number, witness_event.isEva);
                assert(!witness_event.isEva );
                assert((witness_event.round.number-previous_witness.round.number) == 1);
                assert(latest_witness_event.witness);
            }
        do {
            Event.fout.writefln("Before  previous_witness");
            witness_event.witness.vote_famous(witness_event, witness_event.node_id, witness_event.seeing_witness(node_id));
            Event.fout.writefln("After  previous_witness");
        }


        invariant {
            if ( latest_witness_event ) {
                assert(latest_witness_event.witness);
            }
        }



    }

    uint node_size() const pure nothrow {
        const result = cast(uint)(nodes.length);
        return result;
    }

    private Node[uint] nodes; // List of participating nodes T
    private uint[Pubkey] node_ids; // Translation table from pubkey to node_indices;
    private uint[] unused_node_ids; // Stack of unused node ids


    NodeIterator!(const(Node)) nodeiterator() {
        return NodeIterator!(const(Node))(this);
    }

    bool isOnline(Pubkey pubkey) {
        return (pubkey in node_ids) !is null;
    }

    bool createNode(Pubkey pubkey) {
        if ( pubkey in node_ids ) {
            return false;
        }
        auto node_id=cast(uint)node_ids.length;
        node_ids[pubkey]=node_id;
        auto node=new Node(pubkey, node_id);
        nodes[node_id]=node;
        return true;
    }

    const(uint) nodeId(Pubkey pubkey) inout {
        auto result=pubkey in node_ids;
        check(result !is null, ConsensusFailCode.EVENT_NODE_ID_UNKNOWN);
        return *result;
    }

    void setAltitude(Pubkey pubkey, const(int) altitude) {
        auto nid=pubkey in node_ids;
        check(nid !is null, ConsensusFailCode.EVENT_NODE_ID_UNKNOWN);
        auto n=nodes[*nid];
        n.altitude=altitude;
    }


    bool isNodeIdKnown(Pubkey pubkey) const pure nothrow {
        return (pubkey in node_ids) !is null;
    }

    void dumpNodes() {
        import std.stdio;
        foreach(i, n; nodes) {
            Event.fout.writef("%d:%s:", i, n !is null);
            if ( n !is null ) {
                Event.fout.writef("%s ",n.pubkey[0..7].toHexString);
            }
            else {
                Event.fout.write("Non ");
            }
        }
        Event.fout.writefln("");
    }

    @safe
    private struct NodeIterator(N) {
        static assert(is(N : const(Node)), "N must be a Node type");
        private HashGraph _owner;
        this(HashGraph owner) {
            _owner = owner;
        }

        int opApply(scope int delegate(ref N node) @safe dg) {
            int result;
            foreach(ref N n; _owner.nodes) {
                result=dg(n);
                if ( result ) {
                    break;
                }
            }
            return result;
        }

        int opApply(scope int delegate(size_t i, ref N node) @safe dg) {
            int result;
            foreach(i, ref N n; _owner.nodes) {
                result=dg(i, n);
                if ( result ) {
                    break;
                }
            }
            return result;
        }
    }

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

    Event lookup(immutable(ubyte[]) fingerprint) {
        // scope(exit) {
        //     _event_cache.remove(fingerprint);
        // }
        return _event_cache[fingerprint];
    }

    void eliminate(immutable(ubyte[]) fingerprint) {
        _event_cache.remove(fingerprint);
    }

    bool isRegistered(immutable(ubyte[]) fingerprint) {
        return _event_cache.contains(fingerprint);
    }

    // Returns the number of active nodes in the network
    uint active_nodes() const pure nothrow {
        return cast(uint)(node_ids.length);
    }

    uint total_nodes() const pure nothrow {
        return cast(uint)(node_ids.length+unused_node_ids.length);
    }

    inout(Node) getNode(const uint node_id) inout {
        return nodes[node_id];
    }

    inout(Node) getNode(Pubkey pubkey) inout {
        return getNode(nodeId(pubkey));
    }

    bool isMajority(const uint voting) const pure nothrow {
        return Base.isMajority(voting, active_nodes);
    }

    private void remove_node(Node n)
        in {
            assert(n !is null);
            assert(n.node_id < total_nodes);
            assert(n.node_id in nodes, "Node id "~to!string(n.node_id)~" is not removable because it does not exist");
        }
    do {
        nodes.remove(n.node_id);//=null;
        node_ids.remove(n.pubkey);
        unused_node_ids~=n.node_id;
    }

    enum max_package_size=0x1000;
    alias immutable(Hash) function(immutable(ubyte)[]) @safe Hfunc;
    version(none)
    @trusted
    Event receive(
//        GossipNet gossip_net,
        immutable(ubyte)[] data,
        bool delegate(ref const(Pubkey) pubkey, immutable(ubyte[]) msg, Hfunc hfunc) signed,
        Hfunc hfunc) {
        auto doc=Document(data);
        Pubkey pubkey;
        Event event;
        enum pubk=pubkey.stringof;
        enum event_label=event.stringof;
        immutable(ubyte)[] eventbody_data;
        with ( ConcensusFailCode ) {
            check((data.length <= max_package_size), PACKAGE_SIZE_OVERFLOW, "The package size exceeds the max of "~to!string(max_package_size));
            check(doc.hasElement(pubk), EVENT_PACKAGE_MISSING_PUBLIC_KEY, "Event package is missing public key");
            check(doc.hasElement(event_label), EVENT_PACKAGE_MISSING_EVENT, "Event package missing the actual event");
            pubkey=doc[pubk].get!(immutable(ubyte)[]);
            eventbody_data=doc[event_label].get!(immutable(ubyte[]));
            check(signed(pubkey, eventbody_data, hfunc), EVENT_PACKAGE_BAD_SIGNATURE, "Invalid signature on event");
        }
        // Now we come this far so we can register the event
        immutable eventbody=EventBody(eventbody_data);
        event=registerEvent(pubkey, eventbody);
        return event;
    }

    private static Event event_cleaner;
    enum round_clean_limit=10;
    Event registerEvent(
        RequestNet request_net,
        Pubkey pubkey,
        immutable(ubyte[]) signature,
        ref immutable(EventBody) eventbody) {
        immutable fingerprint=request_net.calcHash(eventbody.serialize);
        Event event=lookup(fingerprint);
        // writefln("PUB %s registerEvent=%s",
        //     pubkey[0..7].toHexString,
        //     fingerprint[0..7].toHexString);
        if ( !event ) {
            auto get_node_id=pubkey in node_ids;
            uint node_id;
            Node node;

            // Find a resuable node id if possible
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


//            writefln("Before new Event isEva=%s", eventbody.isEva);
            event=new Event(eventbody, request_net, signature, pubkey, node_id, node_size);


            // writeln("Before assign");
            // Add the event to the event cache
            assign(event);

            // writeln("Before requestEventTree");
            // Makes sure that we have the tree before the graph is checked
            iterative_tree_count=0;
            requestEventTree(request_net, event);

            // See if the node is strong seeing the hashgraph
            // writeln("Before strong See");
            iterative_strong_count=0;
            strongSee(event);
            event.round; // Make sure that the round exists

            event.mark_round_seeing;

            // if ( event.witness ) {
            //     writefln("Collect famous for id=%d node_id=%d", event.id, event.node_id);
            // }
            event.collect_famous_votes;
//            event.collect_witness_seen_votes;

            // if ( event.witness ) {
            //     // Collect votes from this witness to the previous witness
            //     // previous round

            // }
//            vote_famous(event);

            if ( Event.callbacks ) {
                Event.callbacks.round(event);
                if ( iterative_strong_count != 0 ) {
                    Event.callbacks.iterations(event, iterative_strong_count);
                }
//                                    if ( callbacks ) {
                // if ( event.) {
                Event.callbacks.witness_mask(event);
                // }
//                    }

            }

            if ( !event_cleaner ) {
                event_cleaner=event;
            }
            else if ( ( event.round.number - event_cleaner.round.number ) > round_clean_limit ) {
                writefln("CLEAN ROUND %d", event_cleaner.round.number);
//                event_cleaner.ground(this);
                event_cleaner=event;
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

            if ( child ) {
                if ( is_father ) {
                    event.son=child;
                }
                else {
                    event.daughter=child;
                }
            }
            auto mother=event.mother(this, request_net);
            requestEventTree(request_net, mother, event, false);
            auto father=event.father(this, request_net);
            requestEventTree(request_net, father, event, true);

            if ( Event.callbacks ) {
                Event.callbacks.create(event);
                // event.witness_mask;
                // Event.callbacks.witness_mask(event);
            }

        }
    }


        @trusted
            package void strongSee(Event top_event) {
            if ( top_event && !top_event.is_strongly_seeing_checked ) {

                strongSee(top_event.mother);
                strongSee(top_event.father);
                if ( isMajority(top_event.witness_votes(total_nodes)) ) {
                    scope BitArray[] witness_vote_matrix=new BitArray[total_nodes];
                    scope BitArray strong_vote_mask;
                    uint seeing;
                    bool strong;
//                    const round=top_event.previousRound;
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
                                            // if ( isMajority(seeing) ) {
                                            //     strong=true;
                                            //     return;
                                            // }
                                        }
                                    }
                                }
                                /+
                                 The father event is searched first to cross as many nodes as fast as possible
                                 +/
                                if ( path_mask[check_event.node_id] ) {
                                    checkStrongSeeing(check_event.father, path_mask);
                                    checkStrongSeeing(check_event.mother, path_mask);
                                }
                                else {
                                    scope BitArray sub_path_mask=path_mask.dup;
                                    sub_path_mask[check_event.node_id]=true;

                                    checkStrongSeeing(check_event.father, sub_path_mask);
                                    checkStrongSeeing(check_event.mother, sub_path_mask);
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
                        writefln("Strong votes=%d id=%d %s", seeing, top_event.id, cast(string)(top_event.payload));
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
