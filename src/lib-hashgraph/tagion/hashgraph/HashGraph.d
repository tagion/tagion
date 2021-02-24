module tagion.hashgraph.HashGraph;

import std.stdio;
import std.conv;
import std.format;
import std.bitmanip : BitArray;
import std.exception : assumeWontThrow;
import std.algorithm.searching : count;
import std.typecons : TypedefType;
import std.algorithm.iteration : map;

import tagion.hashgraph.Event;
import tagion.gossip.InterfaceNet;
//import tagion.utils.LRU;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.communication.HiRPC;
import tagion.utils.Miscellaneous;

import tagion.basic.Basic : Pubkey, Signature, Privkey, Buffer, bitarray_clear, countVotes;
import tagion.hashgraph.HashGraphBasic;

import tagion.basic.Logger;
import tagion.utils.Miscellaneous : toHex=toHexString;

@safe
class HashGraph : HashGraphI {
    import tagion.basic.ConsensusExceptions;
    protected alias check=Check!HashGraphConsensusException;
    import tagion.utils.Statistic;
    private {
        GossipNet net;
        uint iterative_tree_count;
        uint iterative_strong_count;
        Statistic!uint iterative_tree;
        Statistic!uint iterative_strong;
        HiRPC hirpc;
    }
    //alias LRU!(Round, uint*) RoundCounter;
//    alias Sign=immutable(ubyte)[] function(Pubkey, Privkey,  immutable(ubyte)[] message);
    // List of rounds
    package Round.Rounder _rounds;

    this(const size_t size, GossipNet net) {
        this.net=net;
        net.hashgraph=this;
        nodes=new Node[size];
        _rounds=Round.Rounder(this);
        add_node(net.pubkey);
        hirpc=HiRPC(net);
    }

    @nogc
    Round.Rounder rounds() pure nothrow {
        return _rounds;
    }

    @nogc
    immutable(Pubkey) pubkey() const pure nothrow {
        return net.pubkey;
    }

    alias EventPackageCache=EventPackage[Pubkey];
    alias EventCache=Event[Pubkey];

    protected {
        EventPackageCache _event_package_cache;
        EventCache _event_cache;
    }

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

    version(none)
    void cache(scope const(ubyte[]) fingerprint, immutable(EventPackage)* event_package) nothrow
        in {
            assert(fingerprint !in _event_package_cache, "Event has already been registered");
        }
    do {
        _event_package_cache[fingerprint] = event_package;
    }

    Event registerEvent(
        immutable(EventPackage)* event_pack)
        in {
            assert(event_pack.fingerprint !in _event_cache, format("Event %s has already been registerd", event_pack.fingerprint.toHexString));
        }
    do {
        auto event=new Event(event_pack, this);
        _event_cache[event.fingerprint]=event;
//        event.connect(this);
        front_seat(event);
        return event;
    }

    version(none)
    const(HiRPC.Sender) buildPackage(const(HiBON) block, const ExchangeState state) {
        const pack=Package(block, state);
        hirpc.wavefront(pack);
//        const pack=Package(net, block, state);
        return hirpc.sender.toDoc;
    }

    static {
        @HiRPCMethod() const(HiRPC.Sender) wavefront(const Wavefront wave, const uint id=0) {
            return hirpc.wavefront(wave);
//            return senrder;
        }
    }

    private const(HiRPC.Sender) wavefront(ref const(HiRPC.Receiver) receiver) {
        if (receiver.pubkey in node_ids) {
            wavefront(receiver.params!Wavefront);
        }
        else {
            log.warning("Node channel %s unknown", receiver.pubkey.toHex);
        }
    }

    /++ to synchronize two nodes A and B
     +  1)
     +  Node A send it's wave front to B
     +  This is done via the waveFront function
     +  2)
     +  B collects all the events it has which is are in front of the
     +  wave front of A.
     +  This is done via the waveFront function
     +  B send the all the collected event to B including B's wave font of all
     +  the node which B know it leads in,
     +  The wave from is collect via the waveFront function by adding the remaining tides
     +  3)
     +  A send the rest of the event which is in front of B's wave-front
     +/
    const(Wavefront) tideWave() const pure nothrow {
        Tides tides;
        foreach(n; nodes) {
            if ( n.isOnline ) {
                tides[n.pubkey] = n.altitude;
            }
        }
        return Wavefront(tides);
    }

    /++
     Puts the event in the front seat of the wavefront if the event altitude is highest
     +/
    bool front_seat(Event event) {
        auto current_node = getNode(event.pubkey);
        if ((current_node.event is null) || highest(event.altitude, current_node.event.altitude)) {
            // If the current event is in front of the wave front is set to the current event
            current_node.event = event;
            return true;
        }
        return false;
    }

    const(EventPackage[]) buildWavefront(const Tides tides) const {
        const(EventPackage)[] result;
        foreach(n; nodes) {
            if ( n.pubkey in tides ) {
                const other_altitude=tides[n.pibkey];
                foreach(e; n[]) {
                    if ( higher( other_altitude, e.altitude) ) {
                        break;
                    }
                    log.trace("buildWavefront %d -> %d", other_altitude, e.altitude);
                    result~=e.event_package;
                }
            }
            else {
                foreach(e; n[]) {
                    log.trace("buildWavefront %d ", e.altitude);
                    result~=e.event_package;
                }
            }
        }
        return result;
    }

    void register_wavefront(const(Wavefront) received_wave) {
        foreach(e; receiver_wave.epacks) {
            if (!e.fingerprint in receiver_wave.epacks) {
                _event_package_cache[e.fingerprint] = e;
            }
        }
    }


    const(Wavefront) wavefront_machine(const(Wavefront) received_wave) {
        if ( net.callbacks ) {
            net.callbacks.receive(received_wave);
        }
        auto received_node=getNode(received_wave.pubkey);
        log("%J", wave);
        with(ExchangeState) {
            final switch (received_wave.state) {
            case NONE:
            case INIT_TIDE:
                consensus(received_wave.state).check(false, ConsensusFailCode.GOSSIPNET_ILLEGAL_EXCHANGE_STATE);
                break;
            case TIDAL_WAVE: ///
                if (received_node.state !is NONE) {
                    return buildWavefront(BREAK_WAVE);
                }
                // Receive the tide wave
                consensus(wave.state, INIT_TIDE, NONE).
                    check((wave.state is INIT_TIDE) || (wave.state is NONE),
                        ConsensusFailCode.GOSSIPNET_EXPECTED_OR_EXCHANGE_STATE);
                check(received_wave.epack.length is 0, ConsensusFailCode.GOSSIPNET_TIDAL_WAVE_CONTAINS_EVENTS);
                received_node.state=received_wave.state;
                return buildWavefront(receiver_wave, FIRST_WAVE);
            case BREAKING_WAVE:
                log.trace("BREAKING_WAVE");
                received_node.state=NONE;
                break;
            case FIRST_WAVE:
                if (received_node.state !is INIT) {
                    return buildWavefront(BREAK_WAVE);
                }
                consensus(received_node.state, INIT_TIDE, TIDAL_WAVE).
                    check((received_node.state is INIT_TIDE) || (received_node.state is TIDAL_WAVE),
                        ConsensusFailCode.GOSSIPNET_EXPECTED_OR_EXCHANGE_STATE);
                received_node.state=NONE;
                register_wavefront(receive_wave);
                return buildPackage(received_wave, SECOND_WAVE);
            case SECOND_WAVE:
                if (received_node.state !is TIDAL) {
                    return buildWavefront(BREAK_WAVE);
                }
                consensus(received_node.state, TIDAL_WAVE).check( received_node.state is TIDAL_WAVE,
                    ConsensusFailCode.GOSSIPNET_EXPECTED_EXCHANGE_STATE);
                received_node.state=NONE;
                register_wavefront(receive_wave);
            }
            return Wavefront(NONE);
        }
    }


    @safe
    static class Node {
        ExchangeState state;
        immutable size_t node_id;
//        immutable ulong discovery_time;
        immutable(Pubkey) pubkey;
        @nogc
        this(const Pubkey pubkey, const size_t node_id) pure nothrow {
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
    const(size_t) node_size() const pure nothrow {
        return nodes.length;
    }

    private Node[] nodes; // List of participating nodes T
    private size_t[Pubkey] node_ids; // Translation table from pubkey to node_indices;
//    private uint[] unused_node_ids; // Stack of unused node ids



    @nogc
    Range opSlice() const pure nothrow {
        return Range(this);
    }

    @nogc
    bool isOnline(Pubkey pubkey) pure nothrow const {
        return (pubkey in node_ids) !is null;
    }

    bool createNode(Pubkey pubkey) nothrow
        in {
            assert(pubkey !in node_ids,
                assumeWontThrow(format("Node %d has already created for pubkey %s", node_ids[pubkey], pubkey.hex)));
        }
    do {
        scope(exit) {
            log.error("createNode %d", node_ids[pubkey]);
        }
        if ( pubkey in node_ids ) {
            return false;
        }
        foreach(id, ref n; nodes) {
            if (n is null) {
                const node_id=cast(uint)id;
                n=new Node(pubkey, node_id);
                node_ids[pubkey]=node_id;
                return true;
            }
        }
        assert(0, "Node creating overflow");
        //     const node_id=
        // auto node_id=cast(uint)node_ids.length;
        // node_ids[pubkey]=node_id;

        // nodes[node_id]=node;
        // return true;
    }

    const(size_t) nodeId(scope Pubkey pubkey) const pure {
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
        private {
            Node[] r;
        }
        @nogc @trusted
        this(const HashGraph owner) nothrow pure {
            r = cast(Node[])owner.nodes;
        }

        @nogc @property pure nothrow {
            bool empty() {
                return r.length is 0;
            }

            const(Node) front() {
                return r[0];
            }

            void popFront() {
                while (!empty && (r[0] !is null)) {
                    r=r[1..$];
                }
            }

        }
    }

    @nogc
    Pubkey nodePubkey(const uint node_id) pure const nothrow
        in {
            assert(node_id < nodes.length, "node_id out of range");
        }
    do {
        auto node=nodes[node_id];
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
        return (node_id < nodes.length) && (nodes[node_id] !is null);
    }

    version(none)
    void assign(Event event)
    in {
        assert(net !is null, "RequestNet must be set");
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
        return cast(uint)nodes.count!(q{a is null})(false);
//        return cast(uint)(node_ids.length);
    }

    @nogc
    uint total_nodes() const pure nothrow {
        return cast(uint)(nodes.length);
    }

    inout(Node) getNode(const size_t node_id) inout pure nothrow {
        return nodes[node_id];
    }

    inout(Node) getNode(Pubkey pubkey) inout pure {
        return getNode(nodeId(pubkey));
    }

    @nogc
    bool isMajority(const uint voting) const pure nothrow {
        return .isMajority(voting, active_nodes);
    }

    private void remove_node(Node n) nothrow
        in {
//            import std.format;
            assert(n !is null);
            assert(n.node_id < nodes.length);
            assert(nodes[n.node_id] !is null, format("Node id %d is not removable because it does not exist", n.node_id));
        }
    do {
        scope(success) {
            nodes[n.node_id] = null;
        }
        node_ids.remove(n.pubkey);
    }

    bool remove_node(const Pubkey pkey) nothrow {
        const node_id_p=pkey in node_ids;
        //if (
        //const node_id=node_ids.get(pkey, size_t.max);
        // if (node_id < nodes.length) {
        //     //remove_node(nodes[node_id]);
        //     return true;
        // }
        return false;
    }

    bool add_node(const Pubkey pkey) nothrow
        in {
//            assert(pkey != net.pubkey);
            assert(!(pkey in node_ids), format("Node with pubkey %s has already been added", pkey.toHex));
        }
    do {
        foreach(node_id, ref node; nodes) {
            if (node is null) {
                node=new Node(pkey, node_id);
                node_ids[pkey]=node_id;
                return true;
            }
        }
        return false;
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
                r.range.each!((a) => {if (a !is null) {a.disconnect; pragma(msg, typeof(a));}});

            }
        }
        Round _lowest=Round.lowest;
        if ( _lowest ) {
            local_scrap(_lowest);
            _lowest.__grounded=true;
            log("Round scrapped");
        }
    }

    /**
       This function makes sure that the HashGraph has all the events connected to this event
    */
    version(unittest) {

        static class UnittestNetwork {
            import core.thread.fiber : Fiber;
            import tagion.gossip.GossipNet : StdGossipNet;
            import tagion.utils.Random;
            Random!size_t random;
//            private HashGraph[] hashgraphs;
            @safe class UnittestGossipNet : StdGossipNet {
//            private Tid[immutable(Pubkey)] _tids;
                private Pubkey[] _pkeys;
                private HashGraph _hashgraph;
//                protected uint _send_node_id;


                this() {
                    super();
                }

                void set(Pubkey[] pkeys)
                    in {
                        assert(_hashgraph.node_size is pkeys.length);
                    }
                do {
                    _pkeys=pkeys;
                }

                HashGraphI hashgraph() pure nothrow {
                    return _hashgraph;
                }

                void hashgraph(HashGraphI h) nothrow
                    in {
                        assert(_hashgraph is null);
                    }
                do {
                    _hashgraph=cast(HashGraph)h;

                }


                immutable(Pubkey) selectRandomNode(const bool active=true)
                out(result)  {
                    assert(result != pubkey);
                }
                do {
                    for(;;) {
                        const node_index=random.value(0, _hashgraph.node_size);
                        auto result=_pkeys[node_index];
                        if (result != pubkey) {
                            return result;
                        }
                    }
                    assert(0);
                }



                void dump(const(HiBON[]) events) const {
                    foreach(e; events) {
                        auto pack_doc=Document(e.serialize);
                        immutable pack=buildEventPackage(this, pack_doc);
//            immutable fingerprint=pack.event_body.fingerprint;
//                    log("\tsending %s f=%s a=%d", pack.pubkey.cutHex, pack.fingerprint.cutHex, pack.event_body.altitude);
                    }
                }

//            protected uint _send_count;
                @trusted
                void send(immutable(Pubkey) channel, const(Document) doc) {
                    log.trace("send to %s %d bytes", channel.cutHex, doc.serialize.length);
                    if ( callbacks ) {
                        callbacks.send(channel, doc);
                    }
                    //_tids[channel].send(doc);
                }

                bool online() const  {
                    // Does my own node exist and do the node have an event
                    auto own_node=_hashgraph.getNode(pubkey);
                    return (own_node !is null) && (own_node.event !is null);
                }

            }

            class FiberNetwork : Fiber {
                private GossipNet net;
                @trusted this(GossipNet net) {
                    this.net=net;
                    super(&run);
                }

                private void run() {
                    (() @trusted {
                        yield;
                    })();
                }
            }

            FiberNetwork[Pubkey] networks;
            @disable this();
//            this(HashGraph[] hashgraphs) {
            this(string[] passphrases) {
                immutable N=passphrases.length;
                foreach(passphrase; passphrases) {
                    auto net=new UnittestGossipNet();
                    net.generateKeyPair(passphrase);
                    auto h=new HashGraph(N, net);
                    networks[net.pubkey]=new FiberNetwork(net);
                }

                foreach(n; networks) {
                    foreach(m; networks) {
                        if (n !is m) {
                            n.net.hashgraph.add_node(m.net.pubkey);
                        }
                    }
                }
            }
        }

    }

//    version(none)
    unittest { // strongSee
        // This is the example taken from
        // HASHGRAPH CONSENSUS
        // SWIRLDS TECH REPORT TR-2016-01
        //import tagion.crypto.SHA256;
        import std.traits;
        import std.conv;
        import tagion.gossip.GossipNet : StdGossipNet;
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

//        const net=new StdGossipNet("very secret");
        enum N=EnumMembers!NodeLable.length;
//        HashGraph[] hashgraphs; //=new HashGraph[N];
        //hashgraphs.length=N;
        // foreach(E; EnumMembers!NodeLable) {
        //     hashgraphs[E]=new HashGraph(N);
        // }
        UnittestNetwork networks;
        {

            import std.meta : staticMap;
            import std.conv;
            string[] phrases;
            foreach(E; EnumMembers!NodeLable) {
                phrases~=format("very secret %s", E);
            }
            networks=new UnittestNetwork(phrases);

            enum ToString(alias T)=T.stringof;
            writefln("xxx %s", staticMap!(ToString, EnumMembers!NodeLable));
        }
//        auto network=new UnittestNetwork(hashgraphs);

        //foreach(n; ne
        version(none) {
        //auto h=new HashGraph(net, feature/active_node);
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
}
