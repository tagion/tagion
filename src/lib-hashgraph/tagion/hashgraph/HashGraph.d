module tagion.hashgraph.HashGraph;

//import std.stdio;
import std.conv;
import std.format;
import std.exception : assumeWontThrow;
import std.typecons : TypedefType;
import std.algorithm.searching : count, all;
import std.algorithm.iteration : map, each, filter;
import std.algorithm.comparison : max;
import std.range : dropExactly, lockstep;
import std.array : array;

import tagion.hashgraph.Event;
import tagion.crypto.SecureInterfaceNet;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : isHiBONRecord;
import tagion.communication.HiRPC;
import tagion.utils.Miscellaneous;
import tagion.utils.StdTime;

import tagion.basic.Basic : Pubkey, Signature, Privkey, Buffer, bitarray_clear, countVotes;
import tagion.hashgraph.HashGraphBasic;
import tagion.utils.BitMask;

import tagion.basic.Logger;
import tagion.utils.Miscellaneous : toHex=toHexString;
import tagion.gossip.InterfaceNet;

@safe
class HashGraph {
    enum default_scrap_depth=5;
    bool print_flag;
    int scrap_depth = default_scrap_depth;
    import tagion.basic.ConsensusExceptions;
    protected alias check=Check!HashGraphConsensusException;
    //   protected alias consensus=consensusCheckArguments!(HashGraphConsensusException);
    import tagion.utils.Statistic;
    immutable size_t node_size;
    Statistic!uint witness_search_statistic;
    Statistic!uint strong_seeing_statistic;
    Statistic!uint received_order_statistic;
    Statistic!uint mark_received_statistic;
    Statistic!uint order_compare_statistic;
    Statistic!uint epoch_events_statistic;
    Statistic!uint wavefront_event_package_statistic;
    Statistic!uint wavefront_event_package_used_statistic;
    Statistic!uint live_events_statistic;
    Statistic!uint live_witness_statistic;

    private {
        BitMask _excluded_nodes_mask;
        Node[Pubkey] nodes; // List of participating nodes T
        uint event_id;
    }

    package HiRPC hirpc;

    @nogc
    const(BitMask) excluded_nodes_mask() const pure nothrow {
        return _excluded_nodes_mask;
    }

    package Round.Rounder _rounds;

    alias ValidChannel=bool delegate(const Pubkey channel);
    private ValidChannel valid_channel;
    alias EpochCallback = void delegate(const(Event)[] events) @safe;
    EpochCallback epoch_callback;

    this(const size_t node_size, const SecureNet net, ValidChannel valid_channel, EpochCallback epoch_callback) {
        hirpc=HiRPC(net);
        this.node_size=node_size;
        this.valid_channel=valid_channel;
        this.epoch_callback=epoch_callback;
        _rounds=Round.Rounder(this);
    }

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

    void init_tide(
        const(Pubkey) delegate(GossipNet.ChannelFilter channel_filter, const(HiRPC.Sender) delegate() response) @safe responde,
        const(Document) delegate() @safe payload,
        lazy const sdt_t time) {
        const(HiRPC.Sender) payload_sender() @safe {
            const doc=payload();
            pragma(msg, "doc ", typeof(doc));
            const doc_1=Document(doc);
            immutable epack=event_pack(time, null, doc);
            const registrated=registerEventPackage(epack);
            assert(registrated, "Should not fail here");
            const sender=hirpc.wavefront(tidalWave);
            return sender;
        }
        const send_channel=responde(&not_used_channels, &payload_sender);
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
        immutable eva_epack=eva_pack(time, nonce);
        auto eva_event=registerEventPackage(eva_epack);
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

    package void epoch(const(Event)[] events, const Round decided_round) {
        import std.stdio;
        if (print_flag) {
            writefln("Epoch round %d event.count=%d witness.count=%d", decided_round.number, Event.count, Event.Witness.count);
        }
        if (epoch_callback !is null) {
            epoch_callback(events);
        }
        if (!disable_scrapping) {
            live_events_statistic(Event.count);
            live_witness_statistic(Event.Witness.count);
            _rounds.dustman;
        }
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
            return event;
        }
        return null;
    }

    class Register {
        private EventPackageCache event_package_cache;
        this(const Wavefront received_wave) {
            uint count_events;
            scope(exit) {
                wavefront_event_package_statistic(count_events);
                wavefront_event_package_used_statistic(cast(uint)event_package_cache.length);
            }
            foreach(e; received_wave.epacks) {
                count_events++;
                if (e.fingerprint in _event_cache) {
                    const event=_event_cache[e.fingerprint];
                }
                if (!(e.fingerprint in event_package_cache || e.fingerprint in _event_cache)) {
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
        foreach(fingerprint; _register.event_package_cache.byKey) {
            auto registered_event=register(fingerprint);
            if (registered_event.channel == from_channel) {
                if (front_seat_event is null) {
                    front_seat_event=registered_event;
                }
                else if (higher(registered_event.altitude, front_seat_event.altitude)) {
                    front_seat_event=registered_event;
                }
            }
        }

        return front_seat_event;
    }

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
        return Wavefront(tides);
    }

    const(Wavefront) buildWavefront(const ExchangeState state, const Tides tides=null) {
        if (state is ExchangeState.NONE || state is ExchangeState.BREAKING_WAVE) {
            return Wavefront(null, null, state);
        }

        immutable(EventPackage)*[] result;
        // if (print_flag && state is ExchangeState.SECOND_WAVE) {
        //     writefln("\t\t tides=%s", tides.byValue);
        // }
        // scope(exit) {
        //     if (print_flag && state is ExchangeState.SECOND_WAVE) {
        //         writefln("\t\t events.length=%s", result.length);

        //     }
        // }
        Tides owner_tides;
        foreach(n; nodes) {
            if ( n.channel in tides ) {
                const other_altitude=tides[n.channel];
                foreach(e; n[]) {
                    if (!higher(e.altitude, other_altitude)) {
                        owner_tides[n.channel]=e.altitude;
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
        return Wavefront(result, owner_tides, state);
    }

    void wavefront(
        const HiRPC.Receiver received,
        lazy const(sdt_t) time,
        void delegate(const(HiRPC.Sender) send_wave) @safe response,
        Document delegate() @safe payload) {

        alias consensus = consensusCheckArguments!(GossipConsensusException);
        immutable from_channel=received.pubkey;
        const received_wave=received.params!(Wavefront)(hirpc.net);

        check(valid_channel(from_channel), ConsensusFailCode.GOSSIPNET_ILLEGAL_CHANNEL);
        auto received_node=getNode(from_channel);
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

                    immutable epack=event_pack(time, null, payload());
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
                    immutable epack=event_pack(time, from_front_seat, payload());
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
                    immutable epack=event_pack(time, from_front_seat, payload());
                    const registrated=registerEventPackage(epack);
                    assert(registrated, "The event package has not been registered correct (The wave should be dumped)");
                }
                return buildWavefront(NONE);
            }
        }
        const return_wavefront=wavefront_response;
        if (return_wavefront.state !is ExchangeState.NONE) {
            const sender=hirpc.wavefront(return_wavefront);
            response(sender);
        }
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
        scope BitMask used_nodes;
        nodes.byValue.map!(a => a.node_id).each!((n) {used_nodes[n] = true;});
        return (~used_nodes)[].front;
    }

    bool disable_scrapping;

    enum max_package_size=0x1000;
    enum round_clean_limit=10;

    /++
     Dumps all events in the Hashgraph to a file
     +/
    @trusted
    void fwrite(string filename) {
        import tagion.hibon.HiBONRecord : fwrite;
        scope events=new HiBON;
        foreach(n; nodes) {
            n[]
                .filter!((e) => !e.isGrounded)
                .each!((e) => events[e.id]=EventView(e));
        }
        scope h=new HiBON;
        h[Params.size]=node_size;
        h[Params.events]=events;
        filename.fwrite(h);
    }

    @safe struct Compare {
        alias ErrorCallback=bool delegate(const Event e1, const Event e2, string msg) nothrow @safe;
        const HashGraph h1, h2;
        const ErrorCallback error_callback;
        int order_offset;
        int round_offset;
        this(const HashGraph h1, const HashGraph h2, const ErrorCallback error_callback) {
            this.h1=h1;
            this.h2=h2;
            this.error_callback=error_callback;
        }

        bool compare() @trusted {
            auto h1_nodes=h1.nodes
                .byValue
                .map!((n) => n[])
                .array;
            typeof(h1_nodes) h2_nodes;
            try {
                pragma(msg, typeof(h1_nodes));
                //pragma(msg, typeof(h1_nodes.front));
                h2_nodes=h1.nodes
                    .byValue
                    .map!((n) => h2.nodes[n.channel][])
                    .array;
            }
            catch (Exception e) {

                if (error_callback) {
                    error_callback(null, null, "Can't compare the graph because the do not share the same node channels");
                }
                return false;
            }

            foreach(ref h1_events, ref h2_events; lockstep(h1_nodes, h2_nodes)) {
                while (higher(h1_events.front.altitude, h1_events.front.altitude) && !h1_events.empty) {
                    h1_events.popFront;
                }
                while (higher(h2_events.front.altitude, h1_events.front.altitude) && !h2_events.empty) {
                    h2_events.popFront;
                }
                bool check(bool ok, string msg) {
                    if (!ok && error_callback) {
                        return error_callback(h1_events.front, h2_events.front, msg);
                    }
                    return ok;
                }

                if (!h1_events.empty && !h2_events.empty) {
                    order_offset = h1_events.front.received_order - h2_events.front.received_order;
                    round_offset = h1_events.front.round.number - h2_events.front.round.number;
                }
            while (!h1_events.empty && !h2_events.empty) {
                const e1=h1_events.front;
                const e2=h2_events.front;

                bool ok;
                ok=check(e1.fingerprint == e2.fingerprint,
                    "The fingerprint of the two events is not the same");
                ok=check(e1.event_body.mother == e2.event_body.mother,
                    "The mothers of the two events is not the same");
                ok=check(e1.event_body.father == e2.event_body.father,
                    "The fathers of the two events is not the same");
                ok=check(e1.altitude == e2.altitude,
                    "The fathers of the two events is not the same");
                ok=check(e1.received_order - e2.received_order == order_offset,
                    "The order of the two events is not the same");
                ok=check(e1.round.number - e2.round.number == round_offset,
                    "The round level of the two events is not the same");
                if (!ok) {
                    return ok;
                }
                h1_events.popFront;
                h2_events.popFront;
            }
            }
            return true;
        }
    }
    /++
       This function makes sure that the HashGraph has all the events connected to this event
    +/
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

            class UnittestAuthorising  : GossipNet {
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

                const(Pubkey) select_channel(ChannelFilter channel_filter) {
                    foreach(count; 0..channel_queues.length/2) {
                        const node_index=random.value(0, channel_queues.length);
                        const send_channel = channel_queues
                            .byKey
                            .dropExactly(node_index)
                            .front;
                        if (channel_filter(send_channel)) {
                            return send_channel;
                        }
                    }
                    return Pubkey();
                }

                const(Pubkey) gossip(
                    ChannelFilter channel_filter, SenderCallBack sender) {
                    const send_channel=select_channel(channel_filter);
                    if (send_channel.length) {
                        send(send_channel, sender());
                    }
                    return send_channel;
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

                        if (eva_event is null) {
                            log.error("The channel of this oner is not valid");
                            return;
                        }
                    }
                    uint count;
                    bool stop;
                    Document payload() @safe {
                        auto h=new HiBON;
                        h["node"]=format("%s-%d", name, count);
                        return Document(h);
                    }
                    while (!stop) {
                        while (!authorising.empty(_hashgraph.channel)) {
                            const received=_hashgraph.hirpc.receive(authorising.receive(_hashgraph.channel));
                            _hashgraph.wavefront(
                                received,
                                time,
                                (const(HiRPC.Sender) return_wavefront) @safe {
                                    authorising.send(received.pubkey, return_wavefront);
                                },
                                &payload
                                );
                            count++;
                        }
                        (() @trusted {
                            yield;
                        })();
                        const onLine=_hashgraph.areWeOnline;
                        const init_tide=random.value(0,2) is 1;
                        if (onLine && init_tide) {
                            _hashgraph.init_tide(&authorising.gossip, &payload, time);
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


            this() {
                import std.traits : EnumMembers;
                import std.conv : to;
                authorising=new UnittestAuthorising;
                immutable N=EnumMembers!NodeList.length;
                foreach(E; EnumMembers!NodeList) {
                    immutable passphrase=format("very secret %s", E);
                    auto net=new StdSecureNet();
                    net.generateKeyPair(passphrase);
                    auto h=new HashGraph(N, net, &authorising.isValidChannel, null);
                    h.scrap_depth=0;
                    networks[net.pubkey]=new FiberNetwork(h, E.to!string);
                }
                networks.byKey.each!((a) => authorising.add_channel(a));
            }
        }

    }

    unittest {
        import tagion.hashgraph.Event;
        import std.stdio;
        import std.traits;
        import std.conv;
        import std.datetime;
        import tagion.hibon.HiBONJSON;
        import tagion.basic.Logger : log, LoggerType;
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

        const channels=network.channels;

        try {
            foreach(i; 0..3776) {
                const channel_number=network.random.value(0, channels.length);
                const channel=channels[channel_number];
                auto current=network.networks[channel];
                (() @trusted {
                    current.call;
                })();
            }
        }
        catch (Exception e) {
            (() @trusted {
                writefln("%s", e);
                assert(0, e.msg);
            })();
        }

        writefln("Save Alice");
        foreach(_net; network.networks) {
            if (_net.name == "Alice") {
                const filename=fileId(_net.name);
                _net._hashgraph.fwrite(filename.fullpath);
            }
        }

        HashGraph h1, h2;
        foreach(_net; network.networks) {
            if (_net.name == "Alice") {
                h1=_net._hashgraph;
            }
            if (_net.name == "Bob") {
                h2=_net._hashgraph;
            }
        }

        // bool
        // auto comp=Compare(h1, h2,
    }
}


version(unittest) {
    import Basic=tagion.basic.Basic;
    const(Basic.FileNames) fileId(T=HashGraph)(string prefix=null) @safe {
        import basic=tagion.basic.Basic;
        return basic.fileId!T("hibon", prefix);
    }
}
