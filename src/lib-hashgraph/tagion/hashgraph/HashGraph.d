module tagion.hashgraph.HashGraph;

import std.stdio;
import std.conv;
import std.format;
//import std.bitmanip : BitArray;
import std.exception : assumeWontThrow;
import std.typecons : TypedefType;
import std.algorithm.searching : count, all;
import std.algorithm.iteration : map, each, filter;
import std.algorithm.comparison : max;
import std.range : dropExactly;
import std.array : array;

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
import tagion.hashgraph.BitMask;

import tagion.basic.Logger;
import tagion.utils.Miscellaneous : toHex=toHexString;

@safe
class HashGraph {
    bool print_flag;
    import tagion.basic.ConsensusExceptions;
    protected alias check=Check!HashGraphConsensusException;
    //   protected alias consensus=consensusCheckArguments!(HashGraphConsensusException);
    import tagion.utils.Statistic;
    immutable size_t node_size;
//    immutable size_t min_voting_nodes;
//    immutable size_t max_nodes;
    package Event[] witness_front;

    private {
//        GossipNet net;
        uint iterative_tree_count;
        uint iterative_strong_count;
        Node[Pubkey] nodes; // List of participating nodes T
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

    alias ValidChannel=bool delegate(const Pubkey channel);
    private ValidChannel valid_channel;

    this(const size_t node_size, const SecureNet net, ValidChannel valid_channel) {
//        this.net=net;1
        //net.hashgraph=this;
        hirpc=HiRPC(net);
        this.node_size=node_size;
        witness_front.length = node_size;
        // this.min_voting_nodes=min_voting_nodes;
        // this.max_nodes=max_nodes;
        this.valid_channel=valid_channel;
//        this.authorising=authorising;
        //nodes=new Node[size];
        _rounds=Round.Rounder(this);
        //add_node(net.pubkey);
        //next_event_id; // event_id (0 or event_id.init) is defined as null event
    }


    version(none)
    @nogc
    const(Round.Rounder) rounds() const pure nothrow {
        return _rounds;
    }

    bool areWeOnline() const pure nothrow {
        return nodes.length > 0;
    }


    final Pubkey channel() const pure nothrow {
        return hirpc.net.pubkey;
    }


    @trusted
    const(Pubkey[]) channels() const pure nothrow {
        return nodes.keys;
    }

    bool not_used_channels(const(Pubkey) selected_channel) {
        if (selected_channel == channel) {
            return false;
        }
        const node=nodes.get(selected_channel, null);
        if (node) {
            return node.state is ExchangeState.NONE;
        }
        return true;
    }

    // @nogc
    // size_t voting_nodes() const pure nothrow {
    //     return max(nodes.length, min_voting_nodes);
    // }

    void init_tide(const(Pubkey) send_channel) {
        if (send_channel !is Pubkey(null)) {
            getNode(send_channel).state=ExchangeState.INIT_TIDE;
        }
    }

    immutable(EventPackage*) event_pack(lazy const sdt_t time, const(Event) father_event, const Document doc) @trusted {
        const mother_event=getNode(channel).event;
        immutable ebody=EventBody(doc, mother_event, father_event, time);
        return cast(immutable)new EventPackage(hirpc.net, ebody);
    }


    immutable(EventPackage*) eva_pack(lazy const sdt_t time, const Buffer nonce) @trusted {
        const payload=EvaPayload(channel, nonce);
        immutable eva_event_body=EventBody(payload.toDoc, null, null, time);
        immutable epack=cast(immutable)new EventPackage(hirpc.net, eva_event_body);
        return epack;
    }

    Event createEvaEvent(lazy const sdt_t time, const Buffer nonce) {
        // getNode(channel);
        // writefln("channel in nodes=%s", (channel in nodes) !is null);
        immutable eva_epack=eva_pack(time, nonce);
        auto eva_event=registerEventPackage(eva_epack);
        //eva_event.set_eva_order;
        //assert(eva_event);
        // (() @trusted {
        //     writefln("createEvent=%5s", eva_event.witness_mask);
        // })();
        return eva_event;
    }

    alias EventPackageCache=immutable(EventPackage)*[Buffer];
    alias EventCache=Event[Buffer];

    protected {
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

    /++
     @return true if the event package has been register correct
     +/
    Event registerEventPackage(
        immutable(EventPackage*) event_pack)
        in {
            assert(event_pack.fingerprint !in _event_cache, format("Event %s has already been registerd", event_pack.fingerprint.toHexString));
        }
    do {
        if (valid_channel(event_pack.pubkey)) {
            auto event=new Event(event_pack, this);
            _event_cache[event.fingerprint]=event;
            event.connect(this);
            //event.received_order;
            return event;
        }
        return null;
    }

    class Register {
        private EventPackageCache event_package_cache;
        this(const Wavefront received_wave) {
            foreach(e; received_wave.epacks) {
                if (!(e.fingerprint in event_package_cache || e.fingerprint in _event_cache)) {
                    //log.trace("Received[%s] fingerprint=%s %d", e.pubkey.cutHex, e.fingerprint.cutHex, e.fingerprint.length);
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
                if (valid_channel(event_pack.pubkey)) {
                    //event_package_cache.remove(fingerprint);
                    auto event=new Event(event_pack, this.outer);
                    _event_cache[fingerprint]=event;
                    return event;
                }
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
                Event.check(event !is null, ConsensusFailCode.EVENT_MISSING_IN_CACHE);
                event.connect(this.outer);
            }
            return event;
        }
    }

    protected Register _register;

    package final Event register(scope const(Buffer) fingerprint) {
        if (_register) {
            return _register.register(fingerprint);
        }
        return _event_cache.get(fingerprint, null);
    }

    /++
     Returns:
     The front event of the send channel
     +/
    const(Event) register_wavefront(const Wavefront received_wave, const Pubkey from_channel) {
        _register=new Register(received_wave);
        scope(exit) {
            _register=null;
        }
        assert(_register.event_package_cache.length);
        Event front_seat_event;
        //writefln("_register.event_package_cache.length=%d", _register.event_package_cache.length);
        // const keys=(() @trusted {
        //         return _register.event_package_cache.keys;
        //     })();
        foreach(fingerprint; _register.event_package_cache.byKey) {
            //writefln("isRegisered(%s)=%s", fingerprint.cutHex, isRegistered(fingerprint));
            auto registered_event=register(fingerprint);
            if (registered_event.channel == from_channel) {
                if (front_seat_event is null) {
                    front_seat_event=registered_event;
                }
                else if (higher(registered_event.altitude, front_seat_event.altitude)) {
                    front_seat_event=registered_event;
                }
                //writefln("P%s front_seat %d", from_channel.cutHex, front_seat_event.altitude);
            }
            //registered_event.received_order;
        }

        // foreach(n; nodes) {
        //     if (n && n.event) {
        //         n.event.received_order;
        //     }
        // }

        //assert(!_register.isCached(received_wave.front_seat));
        //assert(front_seat_event);
        return front_seat_event;
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
    const(Wavefront) tidalWave() pure {
        Tides tides;
        foreach(pkey, n; nodes) {
            if ( n.isOnline ) {
                tides[pkey] = n.altitude;
                assert(n._event.isInFront);
            }
        }
        debug {
            writefln("tides.length=%d nodes.length=%d", tides.length, nodes.length);
        }
        return Wavefront(tides);
    }

    const(Wavefront) buildWavefront(const ExchangeState state, const Tides tides=null) {
        if (state is ExchangeState.NONE || state is ExchangeState.BREAKING_WAVE) {
            return Wavefront(null, state);
        }
        immutable(EventPackage)*[] result;
        foreach(n; nodes) {
            if ( n.channel in tides ) {
                const other_altitude=tides[n.channel];
                foreach(e; n[]) {
                    if (!higher(e.altitude, other_altitude)) {
                        break;
                    }
                    result~=e.event_package;

                }
            }
            else {
                n[].each!((e) => result~=e.event_package);
            }
        }
        assert(result.length);
        return Wavefront(result, state);
    }

    void wavefront(
        const Pubkey from_channel,
        const(Wavefront) received_wave,
        lazy const(sdt_t) time,
        void delegate(const(Wavefront) send_wave) @safe response) {
        alias consensus = consensusCheckArguments!(GossipConsensusException);
        // writefln("channels=%s", nodes.byKey.map!(a => a.cutHex));
        // writefln("channel=%s", channel.cutHex);

        check(valid_channel(from_channel), ConsensusFailCode.GOSSIPNET_ILLEGAL_CHANNEL);
        auto received_node=getNode(from_channel);
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

                    immutable epack=event_pack(time, null, Document());
                    const registered=registerEventPackage(epack);
                    assert(registered);
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
                    const from_front_seat=register_wavefront(received_wave, from_channel);
                    immutable epack=event_pack(time, from_front_seat, Document());
                    const registreted=registerEventPackage(epack);
                    assert(registreted);
                    assert(registreted, "The event package has not been registered correct (The wave should be dumped)");
                    return buildWavefront(SECOND_WAVE, received_wave.tides);
                case SECOND_WAVE:
                    if (received_node.state !is TIDAL_WAVE) {
                        received_node.state = NONE;
                        return buildWavefront(BREAKING_WAVE);
                    }
                    consensus(received_node.state, TIDAL_WAVE).check( received_node.state is TIDAL_WAVE,
                        ConsensusFailCode.GOSSIPNET_EXPECTED_EXCHANGE_STATE);
                    received_node.state=NONE;
                    const from_front_seat=register_wavefront(received_wave, from_channel);
                    immutable epack=event_pack(time, from_front_seat, Document());
                    const registrated=registerEventPackage(epack);
                    assert(registrated, "The event package has not been registered correct (The wave should be dumped)");
                }
                return buildWavefront(NONE);
            }
        }
        response(wavefront_response);
    }


    void front_seat(Event event)
        in {
            assert(event, "event must be defined");
        }
    do {
        getNode(event.channel).front_seat(event);
    }

    @safe
    static class Node {
        ExchangeState state;
        immutable size_t node_id;
        immutable(Pubkey) channel;
        @nogc
        this(const Pubkey channel, const size_t node_id) pure nothrow  {
            this.node_id=node_id;
            this.channel=channel;
        }

        /++
         Register first event
         +/
        private void front_seat(Event event)
            in {
                assert(event.channel == channel, "Wrong channel");
            }
        do {
            if (_event is null) {
                _event = event;
            }
            else if (higher(event.altitude, _event.altitude)) {
                Event.check(event.mother !is null, ConsensusFailCode.EVENT_MOTHER_LESS);
                _event=event;
            }
        }

        private Event _event; /// Latest event (front-seat)

        @nogc pure nothrow {
            package final Event event()  {
                return _event;
            }

            final bool isOnline() const  {
                return (_event !is null);
            }

            final int altitude() const
                in {
                    assert(_event !is null, "This node has no events so the altitude is not set yet");
                }
            out {
                assert(_event.isInFront);
            }
            do {
                return _event.altitude;
            }

            package Event.Range!false opSlice()  {
                if (_event) {
                    return _event[];
                }
                return Event.Range!false(null);
            }

            Event.Range!true opSlice() const  {
                if (_event) {
                    return _event[];
                }
                return Event.Range!true(null);
            }
        }
    }

    import std.traits : fullyQualifiedName;
    alias NodeRange=typeof((cast(const)nodes).byValue);

    @nogc
    NodeRange opSlice() const pure nothrow {
        return nodes.byValue;
    }

    void dumpNodes() {
        import std.stdio;
        foreach(i, n; nodes) {
            log("%d:%s:", i, n !is null);
            if ( n !is null ) {
                log("%s ",n.channel.cutHex);
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

    @nogc
    const(SecureNet) net() const pure nothrow {
        return hirpc.net;
    }

    package Node getNode(Pubkey channel) {
        const next_id=next_node_id;
        return nodes.require(channel, new Node(channel, next_id));
    }

    @nogc
    bool isMajority(const uint voting) const pure nothrow {
        return .isMajority(voting, node_size);
    }

    private void remove_node(Node n) nothrow
        in {
//            import std.format;
            assert(n !is null);
            assert(n.channel in nodes, format("Node id %d is not removable because it does not exist", n.node_id));
        }
    do {
        nodes.remove(n.channel);
    }

    bool remove_node(const Pubkey pkey) nothrow {
        if (pkey in nodes) {
            nodes.remove(pkey);
            return true;
        }
        return false;
    }

    @nogc
    uint next_event_id() pure nothrow {
        event_id++;
        if (event_id is event_id.init) {
            return event_id.init+1;
        }
        return event_id;
    }

    @trusted
    size_t next_node_id() const pure nothrow {
        if (nodes.length is 0) {
            return 0;
        }
        import std.algorithm.searching : maxElement;
        import tagion.hashgraph.BitMask;
        scope BitMask used_nodes;
        nodes.byValue.map!(a => a.node_id).each!((n) {used_nodes[n] = true;});
        return (~used_nodes)[].front;
    }



    enum max_package_size=0x1000;
//    alias immutable(Hash) function(immutable(ubyte)[]) @safe Hfunc;
    enum round_clean_limit=10;

    /++
     Dumps all events in the Hashgraph to a file
     +/
    @trusted
    void fwrite(string filename) {
        import tagion.hibon.HiBONRecord : fwrite;
        scope events=new HiBON;
        // bool[size_t] inuse;
        // uint count;
        foreach(n; nodes) {
//            n._event.received_order;
//            pragma(msg, "n._event=", typeof(n._event));
            foreach(e; n[]) {
                //pragma(msg, typeof(e.received_order));
//                if (e.hasOrder) {
                auto event_view=EventView(e);
                events[e.id]=event_view;
//                 if (e.received_order is int.init) {
//                     writefln("id=%d:%d isFatherLess=%s received_order=%d alt=%d",
//                         e.id, e.node_id, e.isFatherLess, e.received_order, e.altitude);
// //                    writefln("FWRITE %J", event_view);
//                     //                  }
//                 }
            }
        }
        scope h=new HiBON;
        h[Params.size]=node_size;
        h[Params.events]=events;
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
            import tagion.hibon.HiBONJSON;
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
                    // assumeWontThrow(
                    //     writefln("send %s", doc.toPretty));
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

                const(Pubkey) gossip(
                    ChannelFilter channel_filter, const Document doc) {
                    foreach(count; 0..channel_queues.length/2) {
                        const node_index=random.value(0, channel_queues.length);
                        const send_channel = channel_queues
                            .byKey
                            .dropExactly(node_index)
                            .front;
                        if (channel_filter(send_channel)) {
                            send(send_channel, doc);
                            return send_channel;
                        }
                    }
                    //assert(null);
                    return Pubkey();
                }

                final const(Pubkey) gossip(T)(ChannelFilter channel_filter, const T pack) if(isHiBONRecord!T) {
                    return gossip(channel_filter, pack.toDoc);
                }

                // final const(Pubkey) gossip(T)(const(Pubkey) channel_owner, const T pack) if(isHiBONRecord!T) {
                //     return gossip(channel_owner, pack.toDoc);
                // }

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
                    if (name == "Alice") {
                        _hashgraph.print_flag=true;
                    }
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
                        auto eva_event=_hashgraph.createEvaEvent(time, nonce);
                        //writefln("### eva_event.received_order=%d node_id=%d", eva_event.received_order, eva_event.node_id);
                        //const registrated=_hashgraph.registerEventPackage(epack);

                        if (eva_event is null) {
                            log.error("The channel of this oner is not valid");
                            return;
                        }
                    }
                    uint count;
                    bool stop;
                    while (!stop) {
                        writefln("Node %s %s", name, _hashgraph.channel.cutHex);
                        // (() @trusted {
                        //     yield;
                        // })();
                        // writefln("\t\tempty %s", authorising.empty(_hashgraph.channel));

                        while (!authorising.empty(_hashgraph.channel)) {
                            const received=_hashgraph.hirpc.receive(authorising.receive(_hashgraph.channel));
                            //writefln("received(%s:%d)=%J", name, count, received);
                            _hashgraph.wavefront(
                                received.pubkey,
                                received.params!(Wavefront)(_hashgraph.hirpc.net),
                                time,
                                (const Wavefront return_wavefront) @safe {
                                    log("Return <- %s", return_wavefront.state);
                                    if (return_wavefront.state !is ExchangeState.NONE) {
                                        const sender=_hashgraph.hirpc.wavefront(return_wavefront);
                                        authorising.send(received.pubkey, sender);
                                    }
                                });
                            //count++;
                        }
                        (() @trusted {
                            yield;
                        })();
                        const onLine=_hashgraph.areWeOnline;
                        const init_tide=random.value(0,2) is 1;
                        // writefln("\t\tonLine %s init_tide %s", onLine, init_tide);
                        // //if (_hashgraph.areWeOnline && random.value(0,2) is 1) {
                        if (onLine && init_tide) {
                            auto h=new HiBON;
                            h["node"]=format("%s-%d", name, count);
                            immutable epack=_hashgraph.event_pack(time, null, Document(h));
                            const registrated=_hashgraph.registerEventPackage(epack);
                            assert(registrated, "Should not fail here");
                            const sender=_hashgraph.hirpc.wavefront(_hashgraph.tidalWave);
                            if (registrated.isFatherLess) {
                                (() @trusted {
                                    writefln("Own isFatherLess=%5s", registrated.witness_mask);
                                })();
                            }
                            // pragma(msg, "isHiBONRecord!(typeof(sender))=", isHiBONRecord!(typeof(sender)));
                            const send_channel=authorising.gossip(&_hashgraph.not_used_channels, sender);
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
                    auto h=new HashGraph(N, net, &authorising.isValidChannel);
                    networks[net.pubkey]=new FiberNetwork(h, E.to!string);
                }
                networks.byKey.each!((a) => authorising.add_channel(a));
                // foreach(net; networks) {
                //     networks.byKey.each!((a) => net._hashgraph.add_node(a));
                // }
            }
        }

    }

    //version(none)
    unittest {
        import tagion.hashgraph.Event;
        // This is the example taken from
        // HASHGRAPH CONSENSUSE
        // SWIRLDS TECH REPORT TR-2016-01
        //import tagion.crypto.SHA256;
        import std.stdio;
        import std.traits;
        import std.conv;
        import std.datetime;
        import tagion.hibon.HiBONJSON;
        import tagion.basic.Logger : log, LoggerType;
        //log.push(LoggerType.ALL);
        log.push(LoggerType.NONE);

        enum NodeLabel {
            Alice,
            Bob,
            Carol,
            Dave,
            Elisa,
            Freja,
            Geoge
        }

        auto network=new UnittestNetwork!NodeLabel();
        network.random.seed(123456789);

        network.global_time=SysTime.fromUnixTime(1_614_355_286); //SysTime(DateTime(2021, 2, 26, 15, 59, 46));

        //auto monitor=new UnittestMonitor;
        //Event.callbacks=monitor;
        const channels=network.channels;
        // foreach(_net; network.networks) {
        //     if (_net.name == "Alice") {
        //         const filename=fileId(_net.name);
        //         _net._hashgraph.fwrite(filename.fullpath);
        //     }
        // }
        //writefln("channels.length=%d", channels.length);
        try {
            foreach(i; 0..776) {
                const channel_number=network.random.value(0, channels.length);
                const channel=channels[channel_number];
                auto current=network.networks[channel];
                // writefln("channel_number=%d channel=%s", channel_number, channel.cutHex);
                //monitor.name=current.name;
                (() @trusted {
                    current.call;
                })();
            }
        }
        catch (Exception e) {
            (() @trusted {
                writefln("%s", e);
            })();
        }

        foreach(_net; network.networks) {
            if (_net.name == "Alice") {
                const filename=fileId(_net.name);
                _net._hashgraph.fwrite(filename.fullpath);
            }
        }

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
