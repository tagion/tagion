module tagion.hashgraph.HashGraph;


import std.stdio;
import std.conv;
import std.format;
import std.bitmanip : BitArray;
import std.exception : assumeWontThrow;
import std.typecons : TypedefType;
import std.algorithm.searching : count;
import std.algorithm.iteration : map, each, filter;
import std.algorithm.comparison : max;
import std.range : dropExactly;
// import std.stdio : File;

import tagion.hashgraph.Event;
//import tagion.hashgraph.HashGraphBasic : HashGraphI;
import tagion.crypto.SecureInterfaceNet;
//import tagion.utils.LRU;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : isHiBONRecord;
import tagion.communication.HiRPC;
import tagion.utils.Miscellaneous;
import tagion.utils.StdTime;

import tagion.basic.Basic : Pubkey, Signature, Privkey, Buffer, bitarray_clear, countVotes;
import tagion.hashgraph.HashGraphBasic;

import tagion.basic.Logger;
import tagion.utils.Miscellaneous : toHex=toHexString;

@safe
class HashGraph {
    enum int eva_altitude=-77;
    import tagion.basic.ConsensusExceptions;
    protected alias check=Check!HashGraphConsensusException;
    //   protected alias consensus=consensusCheckArguments!(HashGraphConsensusException);
    import tagion.utils.Statistic;
    immutable size_t min_voting_nodes;
    private {
//        GossipNet net;
        uint iterative_tree_count;
        uint iterative_strong_count;
        private Node[Pubkey] nodes; // List of participating nodes T
        //    private size_t[Pubkey] node_ids; // Translation table from pubkey to node_indices;
        Statistic!uint iterative_tree;
        Statistic!uint iterative_strong;
        uint event_id;
        HiRPC hirpc;
//        Authorising authorising;
    }
    //alias LRU!(Round, uint*) RoundCounter;
//    alias Sign=immutable(ubyte)[] function(Pubkey, Privkey,  immutable(ubyte)[] message);
    // List of rounds
    package Round.Rounder _rounds;

    this(const size_t min_voting_nodes, const SecureNet net) {
//        this.net=net;
        //net.hashgraph=this;
        hirpc=HiRPC(net);
        this.min_voting_nodes=min_voting_nodes;
//        this.authorising=authorising;
        //nodes=new Node[size];
        _rounds=Round.Rounder(this);
        add_node(net.pubkey);
        next_event_id; // event_id (0 or event_id.init) is defined as null event
    }


    @nogc
    Round.Rounder rounds() pure nothrow {
        return _rounds;
    }

    bool areWeOnline() const pure nothrow {
        return nodes.length > 1;
    }


    final Pubkey channel() const pure nothrow {
        return hirpc.net.pubkey;
    }


    @trusted
    const(Pubkey[]) channels() const pure nothrow {
        return nodes.keys;
    }

    @nogc
    size_t voting_nodes() const pure nothrow {
        return max(nodes.length, min_voting_nodes);
    }

    void init_tide(const(Pubkey) send_channel) {
        nodes[send_channel].state=ExchangeState.INIT_TIDE;
    }

    // immutable(EventPackage*) eva_pack(const sdt_t time, const Buffer nonce) @trusted {
    //     const payload=EvaPayload(channel, nonce);
    //     immutable eva_body=EventBody(payload.toDoc, null, null, time, eva_altitude);
    //     return cast(immutable)new EventPackage(hirpc.net, eva_body);
    // }

    immutable(EventPackage*) single_pack(const sdt_t time, const Document doc) @trusted {
        const node=nodes[channel];
        immutable ebody=EventBody(doc, node.event, null, time);
        return cast(immutable)new EventPackage(hirpc.net, ebody);
    }

    // @nogc
    // immutable(Pubkey) pubkey() const pure nothrow {
    //     return net.pubkey;
    // }

    alias EventPackageCache=immutable(EventPackage)*[Buffer];
    alias EventCache=Event[Buffer];

    protected {
//        EventPackageCache _event_package_cache;
        EventCache _event_cache;
    }

    void eliminate(scope const(Buffer) fingerprint) {
        _event_cache.remove(fingerprint);
    }

    size_t number_of_registered_event() const pure nothrow {
        return _event_cache.length;
    }

    bool isRegistered(scope const(ubyte[]) fingerprint) const pure nothrow {
        return (fingerprint in _event_cache) !is null;
    }

    version(none)
    bool isCached(scope const(ubyte[]) fingerprint) const pure nothrow {
        return (fingerprint in _event_package_cache) !is null;
    }

    Event registerEvent(
        immutable(EventPackage*) event_pack)
        in {
            assert(event_pack.fingerprint !in _event_cache, format("Event %s has already been registerd", event_pack.fingerprint.toHexString));
        }
    do {
        auto event=new Event(event_pack, this);
        _event_cache[event.fingerprint]=event;
        event.connect(this);
//        front_seat(event);
        return event;
    }

    class Register {
        private EventPackageCache event_package_cache;
        this(const Wavefront received_wave) {
            foreach(e; received_wave.epacks) {
                if (!(e.fingerprint in event_package_cache)) {
                    log.trace("Received[%s] fingerprint=%s %d", e.pubkey.cutHex, e.fingerprint.cutHex, e.fingerprint.length);
                    event_package_cache[e.fingerprint] = e;
                }
            }
        }
        final Event lookup(scope Buffer fingerprint) {
            if (fingerprint in _event_cache) {
                return _event_cache[fingerprint];
            }
            else if (fingerprint in event_package_cache) {
                immutable event_pack=event_package_cache[fingerprint];
                event_package_cache.remove(fingerprint);
                auto event=new Event(event_pack, this.outer);
                _event_cache[fingerprint]=event;
                return event;
            }
            return null;
        }

        final bool isCached(scope const(Buffer) fingerprint) const pure nothrow {
            return (fingerprint in event_package_cache) !is null;
        }

        final Event register(scope const(Buffer) fingerprint) {
            Event event;
            if (fingerprint) {
                event = lookup(fingerprint);
                if ( event ) {
                    log.trace("owner[%s] channel[%s] event[%s] alt=%d", channel.cutHex, event.channel.cutHex, fingerprint.cutHex, event.altitude);
                    event.connect(this.outer);
                    front_seat(event);
                }
            }
            return event;
        }
    }

    protected Register _register;

    package final Event register(scope const(Buffer) fingerprint) {
        if (_register) {
            return _register.register(fingerprint);
        }
        return null;
    }

    final bool isCached(scope const(Buffer) fingerprint) const pure nothrow {
        if (_register) {
            return _register.isCached(fingerprint);
        }
        return false;
    }

    final const(Event) lookup(scope const(Buffer) fingerprint) const
        in {
            assert(!isCached(fingerprint),
                format("The event %s has not been registered yet it is not in the graph yet", fingerprint.toHex));
        }
    do {
        return _event_cache.get(fingerprint, null);
    }

    void register_wavefront(const Wavefront received_wave) {
        _register=new Register(received_wave);
        writefln("Create Register");
        // scope(exit) {
        //     writefln("Remove Register");
        //     _register=null;
        // }
        _register.event_package_cache.byKey.each!((fingerprint) => register(fingerprint));
    }

    //static {
    @HiRPCMethod() const(HiRPC.Sender) wavefront(const Wavefront wave, const uint id=0) {
        return hirpc.wavefront(wave, id);
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
    const(Wavefront) tideWave() const pure {
        Tides tides;
        foreach(pkey, n; nodes) {
            if ( n.isOnline ) {
                tides[pkey] = n.altitude;
            }
        }
        debug {
            writefln("tides.length=%d nodes.length=%d", tides.length, nodes.length);
        }
        return Wavefront(tides);
    }

    /++
     Puts the event in the front seat of the wavefront if the event altitude is highest
     +/
    bool front_seat(Event event) {
        auto current_node = nodes[event.channel];
        if ((current_node._event is null) || highest(event.altitude, current_node.event.altitude)) {
            // If the current event is in front of the wave front is set to the current event
            current_node.event = event;
            return true;
        }
        return false;
    }

    const(Wavefront) buildWavefront(const ExchangeState state, const Tides tides=null) const {
        if (tides is null) {
            return Wavefront(null, state);
        }
        immutable(EventPackage*)[] result;
//       log.trace("nodes.length=%d", nodes.length);
        foreach(n; nodes) {
            log.trace("node_id=%d alt=%d", n.node_id, (n._event is null)?-117:n._event.altitude);
            if ( n.pubkey in tides ) {
                const other_altitude=tides[n.pubkey];
                foreach(e; n[]) {
                    if ( higher( other_altitude, e.altitude) ) {
                        break;
                    }
                    log.trace("\t%d) buildWavefront[%s] %d -> %d", n.node_id, n.pubkey.cutHex, other_altitude, e.altitude);
                    result~=e.event_package;
                }
            }
            else {
                foreach(e; n[]) {
                    log.trace("\t%d) buildWavefront[%s] %d ", n.node_id, n.pubkey.cutHex, e.altitude);
                    result~=e.event_package;
                }
            }
        }
//        Wavefront.epacks=result;
        return Wavefront(result, state);
    }

    void wavefront(
        const Pubkey channel,
        const(Wavefront) received_wave,
        void delegate(const(Wavefront) send_wave) @safe response) {
        alias consensus = consensusCheckArguments!(GossipConsensusException);
        // writefln("channels=%s", nodes.byKey.map!(a => a.cutHex));
        // writefln("channel=%s", channel.cutHex);

        auto received_node=nodes[channel];
        //    auto received_wave=received.params!Wavefront;
        if ( Event.callbacks ) {
            Event.callbacks.receive(received_wave);
        }
        log("received_wave(%s <- %s)", received_wave.state, received_node.state);
        scope(exit) {
            log("next <- %s", received_node.state);
        }
        const(Wavefront) wavefront_response() @safe {
            with(ExchangeState) {
                final switch (received_wave.state) {
                case NONE:
                case INIT_TIDE:
                    consensus(received_wave.state).check(false, ConsensusFailCode.GOSSIPNET_ILLEGAL_EXCHANGE_STATE);
                    break;
                case TIDAL_WAVE: ///
                    if (received_node.state !is NONE) {
                        received_node.state = NONE;
                        return buildWavefront(BREAKING_WAVE);
                    }
                    // Receive the tide wave
                    consensus(received_wave.state, INIT_TIDE, NONE).
                        check((received_wave.state !is INIT_TIDE) && (received_wave.state !is NONE),
                            ConsensusFailCode.GOSSIPNET_EXPECTED_OR_EXCHANGE_STATE);
                    check(received_wave.epacks.length is 0, ConsensusFailCode.GOSSIPNET_TIDAL_WAVE_CONTAINS_EVENTS);
                    received_node.state=received_wave.state;
//                    register_wavefront(received_wave);
                    return buildWavefront(FIRST_WAVE, received_wave.tides);
                case BREAKING_WAVE:
                    log.trace("BREAKING_WAVE");
                    received_node.state = NONE;
                    break;
                case FIRST_WAVE:
                    if (received_node.state !is INIT_TIDE) {
                        received_node.state = NONE;
                        return buildWavefront(BREAKING_WAVE);
                    }
                    consensus(received_node.state, INIT_TIDE, TIDAL_WAVE).
                        check((received_node.state is INIT_TIDE) || (received_node.state is TIDAL_WAVE),
                            ConsensusFailCode.GOSSIPNET_EXPECTED_OR_EXCHANGE_STATE);
                    received_node.state=NONE;
                    register_wavefront(received_wave);
                    return buildWavefront(SECOND_WAVE, received_wave.tides);
                case SECOND_WAVE:
                    if (received_node.state !is TIDAL_WAVE) {
                        received_node.state = NONE;
                        return buildWavefront(BREAKING_WAVE);
                    }
                    consensus(received_node.state, TIDAL_WAVE).check( received_node.state is TIDAL_WAVE,
                        ConsensusFailCode.GOSSIPNET_EXPECTED_EXCHANGE_STATE);
                    received_node.state=NONE;
                    register_wavefront(received_wave);
                }
                return buildWavefront(NONE);
            }
        }
        response(wavefront_response);
    }


    @safe
    static class Node : NodeI {
        ExchangeState state;
        immutable size_t node_id;

        @nogc
        size_t nodeId() const pure nothrow {
            return node_id;
        }
//        immutable ulong discovery_time;
        immutable(Pubkey) pubkey;
        @nogc
        this(const Pubkey pubkey, const size_t node_id) pure nothrow {
            this.pubkey=pubkey;
            this.node_id=node_id;
        }

        final immutable(Pubkey) channel() const pure nothrow {
            return pubkey;
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
                // assert(e.son is null);
                // assert(e.daughter is null);
            }
        do {

            // if ( _event is null ) {
            //     //_cache_altitude=e.altitude;
            //     _event=e;
            // }
            if ( (_event is null) ||  lower(_event.altitude, e.altitude) ) {
                //altitude=e.altitude;
                _event=e;
                if ( _event.witness ) {
                    latest_witness_event=_event;
                }
            }
            // if ( _event.witness ) {
            //     latest_witness_event=_event;
            // }
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
//        private int _cache_altitude;

        version(none)
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
            return _event.altitude;
        }

        version(none)
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

                @trusted
                void popFront() {
                    current = cast(Event)current.raw_mother;
                }



                // void popFront() {
                //     current = current.mother_raw;
                // }
            }
        }

        @trusted
        Event.Range opSlice() const pure nothrow {
            return Event.Range(_event);
        }

        invariant {
            if ( latest_witness_event ) {
                assert(latest_witness_event.witness);
            }
        }
    }

    import std.traits : fullyQualifiedName;
    alias NodeRange=typeof((cast(const)nodes).byValue);
    @nogc
    NodeRange opSlice() const pure nothrow {
        return nodes.byValue;
    }


    version(none)
    void setAltitude(scope Pubkey pubkey, const(int) altitude) {
        auto node=pubkey in nodes;
        check(node !is null, ConsensusFailCode.EVENT_NODE_ID_UNKNOWN);
        node.altitude=altitude;
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

    @nogc
    size_t active_nodes() const pure nothrow {
        return nodes.length;
    }

    const(SecureNet) net() const pure nothrow {
        return hirpc.net;
    }

    // const(Node) getNode(const size_t node_id) const pure nothrow {
    //     return nodes[node_id];
    // }

    public const(Node) getNode(Pubkey channel) const pure {
        return nodes.get(channel, null);
    }

    package Node getNode(Pubkey channel) pure {
        return nodes.get(channel, null);
    }

    @nogc
    bool isMajority(const uint voting) const pure nothrow {
        return .isMajority(voting, voting_nodes);
    }

    private void remove_node(Node n) nothrow
        in {
//            import std.format;
            assert(n !is null);
            assert(n.pubkey in nodes, format("Node id %d is not removable because it does not exist", n.node_id));
        }
    do {
        nodes.remove(n.pubkey);
    }

    bool remove_node(const Pubkey pkey) nothrow {
        if (pkey in nodes) {
            nodes.remove(pkey);
            return true;
        }
        return false;
    }

    @nogc
    uint next_event_id() nothrow {
        event_id++;
        if (event_id is event_id.init) {
            return event_id.init+1;
        }
        return event_id;
    }

    @trusted
    size_t next_node_id() const pure nothrow
        out(result) {
            debug
                writefln("%s next_node_id=%d", channel.cutHex, result);
        }
    do {
        if (nodes.length is 0) {
            return 0;
        }
        import std.algorithm.searching : maxElement;
        scope BitArray used_nodes;
        used_nodes.length=nodes.byValue.map!(a => a.node_id).maxElement+1; //.max;
        nodes.byValue.map!(a => a.node_id).each!((n) {used_nodes[n] = true;});
        debug writefln("used_nodes=%b", used_nodes);

        auto unused_list=(~used_nodes).bitsSet;
        if (unused_list.empty) {
            return used_nodes.length;
        }
        return unused_list.front;
    }

    void add_node(const Pubkey pkey) nothrow {
        if (!(pkey in nodes)) {
            nodes[pkey]=new Node(pkey, next_node_id);
        }
    }


    enum max_package_size=0x1000;
//    alias immutable(Hash) function(immutable(ubyte)[]) @safe Hfunc;
    enum round_clean_limit=10;

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

    /++
     Dumps all events in the Hashgraph to a file
     +/
    @trusted
    void fwrite(string filename) {
        import tagion.hibon.HiBONRecord : fwrite;
        scope h=new HiBON;
        foreach(n; nodes) {
            foreach(e; n[]) {
                h[e.id]=EventView(e);
            }
        }
        filename.fwrite(h);
    }

    /**
       This function makes sure that the HashGraph has all the events connected to this event
    */
    version(unittest) {

        static class UnittestNetwork(NodeList) if (is(NodeList == enum)) {
            import core.thread.fiber : Fiber;
            import tagion.crypto.SecureNet : StdSecureNet;
            import tagion.utils.Random;
            import tagion.utils.Queue;
            import std.datetime.systime : SysTime;
            import core.time;
            UnittestAuthorising authorising;
            Random!size_t random;
            SysTime global_time;
            enum timestep {
                MIN = 50,
                MAX = 150
            }

            alias ChannelQueue=Queue!Document;

            class UnittestAuthorising  : Authorising {
                protected {
                    ChannelQueue[Pubkey] channel_queues;
                    Pubkey[] channel_keys;
                    sdt_t _current_time;
                }

                @property
                void time(const(sdt_t) t) {
                    _current_time=sdt_t(t);
                }


                @property
                const(sdt_t) time() pure const {
                    return _current_time;
                }

                bool isValidChannel(const(Pubkey) channel) const pure nothrow {
                    return (channel in channel_queues) !is null;
                }

                void send(const(Pubkey) channel, const(Document) doc) nothrow {
                    log.trace("send to %s %d bytes", channel.cutHex, doc.serialize.length);
                    if ( Event.callbacks ) {
                        Event.callbacks.send(channel, doc);
                    }
                    channel_queues[channel].write(doc);
                }

                final void send(T)(const(Pubkey) channel, T pack) if(isHiBONRecord!T) {
                    send(channel, pack.toDoc);
                }

                const(Document) receive(const Pubkey channel) nothrow {
                    return channel_queues[channel].read;
                }

                const(Pubkey) gossip(const(Pubkey) channel_owner, const Document doc) {
                    const(Pubkey) selectRandomNode() pure nothrow {
                        const channels=channel_queues.byKey;
                        const node_index=random.value(0, channel_queues.length-1);
                        return channel_queues
                            .byKey
                            .filter!((a) => a != channel_owner)
                            .dropExactly(node_index)
                            .front;
                    }
                    if (channel_queues.length > 1) {
			const send_channel = selectRandomNode;
                        send(send_channel, doc);
                        return send_channel;
                    }
                    return Pubkey();
                }

                final const(Pubkey) gossip(T)(const(Pubkey) channel_owner, const T pack) if(isHiBONRecord!T) {
                    return gossip(channel_owner, pack.toDoc);
                }

                bool empty(const Pubkey channel) const pure nothrow {
                    return channel_queues[channel].empty;
                }

                void add_channel(const Pubkey channel) {
                    channel_queues[channel]=new ChannelQueue;
                }

                void remove_channel(const Pubkey channel) {
                    channel_queues.remove(channel);
                }
            }
//            @trusted
            class FiberNetwork : Fiber {
                private HashGraph _hashgraph;
                immutable(string) name;
                @trusted
                this(HashGraph h, string name) nothrow
                in {
                    assert(_hashgraph is null);
                }
                do {
                    super(&run);
                    _hashgraph=h;
                    this.name=name;
                }

                const(HashGraph) hashgraph() const pure nothrow {
                    return _hashgraph;
                }

                sdt_t time() {
                    const systime=global_time+random.value(timestep.MIN, timestep.MAX).msecs;
                    return sdt_t(systime.stdTime);
                }
                private void run() {
                    {
                        immutable buf=cast(Buffer)_hashgraph.channel;
                        const nonce=_hashgraph.hirpc.net.calcHash(buf);
//                        _hashgraph.registerEvent(_hashgraph.eva_pack(time, nonce));
                        Event.createEvaEvent(_hashgraph, time, nonce);
                    }
                    uint count;
                    bool stop;
                    while (!stop) {
                        writefln("Node %s", name);
                        (() @trusted {
                            yield;
                        })();
                        while (!authorising.empty(_hashgraph.channel)) {
                            const received=_hashgraph.hirpc.receive(authorising.receive(_hashgraph.channel));
                            //writefln("received(%s:%d)=%J", name, count, received);
                            _hashgraph.wavefront(
                                received.pubkey,
                                received.params!(Wavefront)(_hashgraph.hirpc.net),
                                (const Wavefront return_wavefront) @safe {
                                    log("Return <- %s", return_wavefront.state);
                                    if (return_wavefront.state !is ExchangeState.NONE) {
                                        const sender=_hashgraph.hirpc.wavefront(return_wavefront);
                                        authorising.send(received.pubkey, sender);
                                    }
                                });
                            //count++;
                        }
                        if (_hashgraph.areWeOnline && random.value(0,2) is 1) {
                            auto h=new HiBON;
                            h["node"]=format("%s-%d", name, count);
                            immutable epack=_hashgraph.single_pack(time, Document(h));
                            _hashgraph.registerEvent(epack);
                            // const tide_wave=_hashgraph.tideWave;
                            // writefln("tide_wave.tides.length=%d", tide_wave._tides.length);
                            const sender=_hashgraph.hirpc.wavefront(_hashgraph.tideWave);
                            pragma(msg, "isHiBONRecord!(typeof(sender))=", isHiBONRecord!(typeof(sender)));
                            const send_channel=authorising.gossip(_hashgraph.channel, sender);
                            _hashgraph.init_tide(send_channel);
                            count++;
                        }
                    }
                }
            }

            @trusted
            const(Pubkey[]) channels() const pure nothrow {
                return networks.keys;
            }

            FiberNetwork[Pubkey] networks;
//            @disable this();
            this() {
                import std.traits : EnumMembers;
                import std.conv : to;
                authorising=new UnittestAuthorising;
                immutable N=EnumMembers!NodeList.length;
                foreach(E; EnumMembers!NodeList) {
                    immutable passphrase=format("very secret %s", E);
//                }

//                immutable N=passphrases.length;
//                foreach(passphrase; passphrases) {
                    auto net=new StdSecureNet();
                    net.generateKeyPair(passphrase);
                    auto h=new HashGraph(N, net);
                    networks[net.pubkey]=new FiberNetwork(h, E.to!string);
                }
                networks.byKey.each!((a) => authorising.add_channel(a));
                foreach(net; networks) {
                    networks.byKey.each!((a) => net._hashgraph.add_node(a));
                }
            }
        }

    }

//    version(none)
    unittest { // strongSee
        import  std.typecons : BlackHole;
        import tagion.hashgraph.Event;
        // This is the example taken from
        // HASHGRAPH CONSENSUSE
        // SWIRLDS TECH REPORT TR-2016-01
        //import tagion.crypto.SHA256;
        import std.stdio;
        import std.traits;
        import std.conv;
        import std.datetime;
        import tagion.basic.Logger : log, LoggerType;
        log.push(LoggerType.ALL);
        enum NodeLabel {
            Alice,
            Bob,
            Carol,
            Dave,
            Elisa
        }

        @safe static abstract class UnittestAbstractMonitor : EventMonitorCallbacks {
            nothrow {
                string name;
                @trusted
                void create(const(Event) e) {
                    assumeWontThrow(
                        writefln("\t$%s$ create id=%d", name, e.id));
                }
                void connect(const(Event) e) {
                    assumeWontThrow(
                        writefln("\t$%s$ connect id=%d %s %s", name, e.id, e.connected, e.isGrounded));
                }
                abstract {
                    void witness(const(Event) e);
                    //void witness_mask(const(Event) e);
                    //void strongly_seeing(const(Event) e);
                    //void strong_vote(const(Event) e, immutable uint vote);
                    void round_seen(const(Event) e);
                    //void looked_at(const(Event) e);
                    void round_decided(const(Round.Rounder) rounder);
                    void round_received(const(Event) e);
                    //void coin_round(const(Round) r);
                    void famous(const(Event) e);
                    void round(const(Event) e);
                    void son(const(Event) e);
                    void daughter(const(Event) e);
                    void forked(const(Event) e);
                    //void remove(const(Round) r);
                    void epoch(const(Event[]) received_event);
                    //void iterations(const(Event) e, const uint count);
                    //void exiting(const(Pubkey) owner_key, const(HashGraphI) hashgraph);
                    void send(const Pubkey channel, lazy const Document doc);
                    void receive(lazy const Document doc);
                    //void consensus_failure(const(ConsensusException) e);
                }
            }
        }

        alias UnittestMonitor=BlackHole!UnittestAbstractMonitor;


        auto network=new UnittestNetwork!NodeLabel();
        network.random.seed(123456789);

        network.global_time=SysTime.fromUnixTime(1_614_355_286); //SysTime(DateTime(2021, 2, 26, 15, 59, 46));

        auto monitor=new UnittestMonitor;
        Event.callbacks=monitor;
        const channels=network.channels;
        foreach(i; 0..157) {
            const channel_number=network.random.value(0, channels.length);
            const channel=channels[channel_number];
            // writefln("channels.length=%d", channels.length);
            // writefln("network.random.value(0,100)=%d", network.random.value(0,100));
            // writefln("channel_number=%d", channel_number);
            auto current=network.networks[channel];
            monitor.name=current.name;
            // if (current.name != NodeLabel.Alice.to!string) {
            //     log.push(0);
            // }
            // else {
            //     log.push(LoggerType.ALL);
            // }
            // scope(exit) {
            //     log.pop;
            // }
            (() @trusted {
                current.call;
            })();
        }

        foreach(net; network.networks) {
            const filename=fileId(net.name);
            // auto fout = File(filename.fullpath, "w");
            // scope(exit) {
            //     fout.close;
            // }
            net._hashgraph.fwrite(filename.fullpath);
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


version(unittest) {
    import Basic=tagion.basic.Basic;
    const(Basic.FileNames) fileId(T=HashGraph)(string prefix=null) @safe {
        import basic=tagion.basic.Basic;
        return basic.fileId!T("hibon", prefix);
    }
}
