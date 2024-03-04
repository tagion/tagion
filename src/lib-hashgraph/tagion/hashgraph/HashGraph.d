/// Consensus HashGraph main object 
module tagion.hashgraph.HashGraph;

import std.algorithm;
import std.array : array;
import std.conv;
import std.exception : assumeWontThrow;
import std.format;
import std.range;
import std.stdio;
import std.typecons : Flag, No, Yes;
import tagion.basic.Debug : __format;
import tagion.basic.Types : Buffer;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.Types : Privkey, Pubkey, Signature;
import tagion.gossip.GossipNet;
import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraph.RefinementInterface;
import tagion.hashgraph.Round;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : isHiBONRecord;
import tagion.logger.Logger;
import tagion.utils.BitMask;
import tagion.utils.StdTime;

// debug
import tagion.basic.Debug;
import tagion.hibon.HiBONJSON;
import tagion.utils.Miscellaneous : cutHex;

@safe
class HashGraph {
    enum default_scrap_depth = 10;
    //bool print_flag;
    int scrap_depth = default_scrap_depth;
    import tagion.basic.ConsensusExceptions;

    bool __debug_print;

    protected alias check = Check!HashGraphConsensusException;
    //   protected alias consensus=consensusCheckArguments!(HashGraphConsensusException);
    import tagion.logger.Statistic;

    immutable size_t node_size; /// Number of active nodes in the graph
    immutable(string) name; // Only used for debugging
    Statistic!uint witness_search_statistic;
    Statistic!uint strong_seeing_statistic;
    Statistic!uint received_order_statistic;
    Statistic!uint mark_received_statistic;
    Statistic!uint order_compare_statistic;
    Statistic!uint rare_order_compare_statistic;
    Statistic!uint epoch_events_statistic;
    Statistic!uint wavefront_event_package_statistic;
    Statistic!uint wavefront_event_package_used_statistic;
    Statistic!uint live_events_statistic;
    Statistic!uint live_witness_statistic;
    Statistic!long epoch_delay_statistic;
    BitMask _excluded_nodes_mask;
    private {
        Node[Pubkey] _nodes; // List of participating _nodes T
        uint event_id;
        sdt_t last_epoch_time;
        Flag!"joining" _joining;
    }
    Refinement refinement;
    protected Node _owner_node;
    const(Node) owner_node() const pure nothrow @nogc {
        return _owner_node;
    }

    Flag!"joining" joining() const pure nothrow @nogc {
        return _joining;
    }

    /**
 * Get a map of all the nodes currently handled by the graph 
 * Returns: 
 */
    const(Node[Pubkey]) nodes() const pure nothrow @nogc {
        return _nodes;
    }

    const HiRPC hirpc;

    @nogc
    const(BitMask) excluded_nodes_mask() const pure nothrow {
        return _excluded_nodes_mask;
    }

    void excluded_nodes_mask(const(BitMask) mask) pure nothrow {
        _excluded_nodes_mask = mask;
    }

    package Round.Rounder _rounds; /// The rounder hold the round in the queue both decided and undecided rounds

    alias ValidChannel = bool delegate(const Pubkey channel);
    const ValidChannel valid_channel; /// Valiates of a node at channel is valid
    /**
 * Creates a graph with node_size nodes
 * Params:
 *   node_size = number of nodes handles byt the graph
 *   net = Securety element handles hash function, signing and signature validation
 *   valid_channel = call-back to check if a node is valid
 *   epoch_callback = call-back which is called when an epoch has been produced
 *   epack_callback = call-back call if when a package has been added to the cache.
 *   name = used for debuging label the node name
 */
    this(const size_t node_size,
            const SecureNet net,
            Refinement refinement,
            const ValidChannel valid_channel,
            const Flag!"joining" joining,
            string name = null)
    in (node_size >= 4)
    do {
        hirpc = HiRPC(net);
        this.node_size = node_size;
        this._owner_node = getNode(hirpc.net.pubkey);
        this.refinement = refinement;
        this.refinement.setOwner(this);
        this.valid_channel = valid_channel;

        this._joining = joining;
        this.name = name;
        _rounds = Round.Rounder(this);
    }

    void initialize_witness(const(immutable(EventPackage)*[]) epacks)
    in {
        assert(_nodes.length > 0 && (channel in _nodes),
                "Owen Eva event needs to be create before witness can be initialized");
        assert(_owner_node !is null);
    }
    do {
        version (EPOCH_LOG) {
            log("INITTING WITNESSES %s", _owner_node.channel.cutHex);
        }
        Node[Pubkey] recovered_nodes;
        scope (success) {
            void init_event(immutable(EventPackage*) epack) {
                auto event = new Event(epack, this);
                _event_cache[event.fingerprint] = event;
                event.witness_event(node_size);
                version (EPOCH_LOG) {
                    log("init_event time %s", event.event_body.time);
                }
                _rounds.last_round.add(event);
                front_seat(event);
                event._round_received = _rounds.last_round;
            }

            _rounds.erase;
            _rounds = Round.Rounder(this);
            _rounds.last_decided_round = _rounds.last_round;
            (() @trusted { _event_cache.clear; })();
            init_event(_owner_node.event.event_package);
            // front_seat(owen_event);
            foreach (epack; epacks) {
                if (epack.pubkey != channel) {
                    init_event(epack);
                }
            }
            foreach (channel, recovered_node; recovered_nodes) {
                if (!(channel in _nodes)) {
                    if (recovered_node.event) {
                        init_event(recovered_node.event.event_package);
                    }
                }
            }

            _nodes.byValue
                .map!(n => n.event)
                .each!(e => e.initializeOrder);
        }
        scope (failure) {
            _nodes = recovered_nodes;
        }
        recovered_nodes = _nodes;
        _nodes = null;
        check(isMajority(cast(uint) epacks.length), ConsensusFailCode.HASHGRAPH_EVENT_INITIALIZE);
        // consensus(epacks.length)
        //     .check(epacks.length <= node_size, ConsensusFailCode.HASHGRAPH_EVENT_INITIALIZE);
        // getNode(channel); // Make sure that node_id == 0 is owner node
        foreach (epack; epacks) {
            if (epack.pubkey != channel) {
                check(!(epack.pubkey in _nodes), ConsensusFailCode.HASHGRAPH_DUPLICATE_WITNESS);
                auto node = getNode(epack.pubkey);
            }
        }
    }

    @nogc
    const(Round.Rounder) rounds() const pure nothrow {
        return _rounds;
    }

    bool areWeInGraph() const pure nothrow {
        return _rounds.last_decided_round !is null;
    }

    final Pubkey channel() const pure nothrow {
        return hirpc.net.pubkey;
    }

    const(Pubkey[]) channels() const pure nothrow {
        return _nodes.keys;
    }

    bool not_used_channels(const(Pubkey) selected_channel) {
        if (selected_channel == channel) {
            return false;
        }
        const node = _nodes.get(selected_channel, null);
        version(SEND_ALWAYS) {
            if (node) {
                return node.state is ExchangeState.NONE;
            }
        }
        return true;
    }

    alias GraphResonse = const(Pubkey) delegate(
            GossipNet.ChannelFilter channel_filter,
            GossipNet.SenderCallBack sender) @safe;
    alias GraphPayload = const(Document) delegate() @safe;

    void init_tide(
            const(GraphResonse) responde,
            const(GraphPayload) payload,
            lazy const sdt_t time) {
        const(HiRPC.Sender) payload_sender() @safe {
            const doc = payload();
            immutable epack = event_pack(time, null, doc);

            const registrated = registerEventPackage(epack);

            assert(registrated, "Should not fail here");
            const sender = hirpc.wavefront(tidalWave);
            return sender;
        }

        const(HiRPC.Sender) sharp_sender() @safe {
            version (EPOCH_LOG) {
                log("SENDING sharp sender: %s", owner_node.channel.cutHex);
            }

            const sharp_wavefront = sharpWave();
            const sender = hirpc.wavefront(sharp_wavefront);
            return sender;
        }

        if (areWeInGraph) {
            const send_channel = responde(
                    &not_used_channels,
                    &payload_sender);
            if (send_channel !is Pubkey.init) {
                getNode(send_channel).state = ExchangeState.INIT_TIDE;
            }
        }
        else {
            const send_channel = responde(
                    &not_used_channels,
                    &sharp_sender);
        }
    }

    immutable(EventPackage)* event_pack(
            lazy const sdt_t time,
            const(Event) father_event,
            const Document doc) {

        const mother_event = getNode(channel).event;

        immutable ebody = EventBody(doc, mother_event, father_event, time);

        immutable result = new immutable(EventPackage)(hirpc.net, ebody);
        return result;
    }

    immutable(EventPackage*) eva_pack(lazy const sdt_t time, const Buffer nonce) {
        const payload = EvaPayload(channel, nonce);
        immutable eva_event_body = EventBody(payload.toDoc, null, null, time);
        immutable epack = new immutable(EventPackage)(hirpc.net, eva_event_body);
        return epack;
    }

    Event createEvaEvent(lazy const sdt_t time, const Buffer nonce) {
        immutable eva_epack = eva_pack(time, nonce);
        auto eva_event = new Event(eva_epack, this);

        _event_cache[eva_event.fingerprint] = eva_event;
        front_seat(eva_event);
        // set_strongly_seen_mask(eva_event);
        return eva_event;
    }

    alias EventPackageCache = immutable(EventPackage)*[Buffer]; /// EventPackages received from another node in the hashgraph.
    alias EventCache = Event[Buffer]; /// Events already connected to this hashgraph. 

    protected {
        EventCache _event_cache;
    }

    void eliminate(scope const(Buffer) fingerprint) pure nothrow {
        _event_cache.remove(fingerprint);
    }

    @nogc
    size_t number_of_registered_event() const pure nothrow {
        return _event_cache.length;
    }

    // function not used
    @nogc
    bool isRegistered(scope const(ubyte[]) fingerprint) const pure nothrow {
        return (fingerprint in _event_cache) !is null;
    }

    Topic topic = Topic("hashgraph_event");
    package void epoch(Event[] event_collection, const Round decided_round) {
        refinement.epoch(event_collection, decided_round);
        if (scrap_depth > 0) {
            live_events_statistic(Event.count);
            log.event(topic, live_events_statistic.stringof, live_events_statistic);
            live_witness_statistic(Event.Witness.count);
            log.event(topic, live_witness_statistic.stringof, live_events_statistic);
            _rounds.dustman;
        }
    }

    /++
     @return true if the event package has been register correct
     +/
    Event registerEventPackage(
            immutable(EventPackage*) event_pack)
    in (event_pack.fingerprint !in _event_cache,
        format("Event %(%02x%) has already been registerd",
            event_pack.fingerprint))
    do {
        if (valid_channel(event_pack.pubkey)) {
            auto event = new Event(event_pack, this);
            _event_cache[event.fingerprint] = event;
            refinement.epack(event_pack);
            event.connect(this);
            return event;
        }
        return null;
    }

    class Register {
        private EventPackageCache event_package_cache;

        this(const Wavefront received_wave) pure nothrow {
            uint count_events;
            scope (exit) {
                wavefront_event_package_statistic(count_events);
                wavefront_event_package_used_statistic(cast(uint) event_package_cache.length);
            }
            foreach (e; received_wave.epacks) {
                count_events++;
                if (!(e.fingerprint in event_package_cache || e.fingerprint in _event_cache)) {
                    event_package_cache[e.fingerprint] = e;
                }
            }
        }

        final Event lookup(const(Buffer) fingerprint) {
            if (fingerprint in _event_cache) {
                return _event_cache[fingerprint];
            }

            if (fingerprint in event_package_cache) {
                immutable event_pack = event_package_cache[fingerprint];
                if (valid_channel(event_pack.pubkey)) {
                    auto event = new Event(event_pack, this.outer);
                    _event_cache[fingerprint] = event;
                    return event;
                }
            }
            return null;
        }

        // function not used
        final bool isCached(scope const(Buffer) fingerprint) const pure nothrow {
            return (fingerprint in event_package_cache) !is null;
        }

        final Event register(const(Buffer) fingerprint) {
            Event event;

            if (!fingerprint) {
                return event;
            }

            // event either from event_package_cache or event_cache.
            event = lookup(fingerprint);
            Event.check(_joining || event !is null, ConsensusFailCode.EVENT_MISSING_IN_CACHE);
            if (event !is null) {
                event.connect(this.outer);
            }
            return event;
        }
    }

    protected Register _register;

    package final Event register(const(Buffer) fingerprint) {
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
        _register = new Register(received_wave);

        scope (exit) {
            log.event(topic, wavefront_event_package_statistic.stringof, wavefront_event_package_statistic);
            log.event(topic, wavefront_event_package_used_statistic.stringof, wavefront_event_package_statistic);
            _register = null;
        }

        Event front_seat_event;
        foreach (fingerprint; _register.event_package_cache.byKey) {
            auto registered_event = register(fingerprint);
            if (registered_event.channel == from_channel) {
                if (front_seat_event is null) {
                    front_seat_event = registered_event;
                }
                else if (higher(registered_event.altitude, front_seat_event.altitude)) {
                    front_seat_event = registered_event;
                }
            }
        }

        return front_seat_event;
    }

    @HiRPCMethod const(HiRPC.Sender) wavefront(
            const Wavefront wave,
            const uint id = 0) {
        return hirpc.wavefront(wave, id);
    }

    /++ to synchronize two _nodes A and B
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
        foreach (pkey, n; _nodes) {
            if (n.isOnline) {
                tides[pkey] = n.altitude;
                assert(n._event.isFront);
            }
        }
        return Wavefront(tides);
    }

    const(Wavefront) buildWavefront(const ExchangeState state, const Tides tides = null) {
        if (state is ExchangeState.NONE || state is ExchangeState.BREAKING_WAVE) {
            return Wavefront(null, null, state);
        }

        immutable(EventPackage)*[] result;
        Tides owner_tides;
        foreach (n; _nodes) {
            if (n.channel in tides) {
                const other_altitude = tides[n.channel];
                foreach (e; n[]) {
                    if (!higher(e.altitude, other_altitude)) {
                        owner_tides[n.channel] = e.altitude;
                        break;
                    }
                    result ~= e.event_package;

                }
            }
        }
        if (result.length == 0) {
            return Wavefront(null, null, state);
        }
        return Wavefront(result, owner_tides, state);
    }

    /** 
     * 
     * Params:
     *   received_wave = The sharp received wave
     * Returns: either coherent if in graph or rippleWave
     */
    const(Wavefront) sharpResponse(const Wavefront received_wave)
    in {
        assert(received_wave.state is ExchangeState.SHARP);
    }
    do {
        if (areWeInGraph) {
            // writefln("sharp response ingraph:true");
            immutable(EventPackage)*[] result = _rounds.last_decided_round
                .events
                .filter!((e) => (e !is null))
                .map!((e) => cast(immutable(EventPackage)*) e.event_package)
                .array;
            return Wavefront(result, null, ExchangeState.COHERENT);
        }

        // if we are not in graph ourselves, we put the delta information
        // in and return a RIPPLE.
        auto received_epacks = received_wave
            .epacks
            .map!((e) => cast(immutable(EventPackage)*) e)
            .array
            .sort!((a, b) => a.fingerprint < b.fingerprint);
        auto own_epacks = _nodes.byValue
            .map!((n) => n[])
            .joiner
            .map!((e) => cast(immutable(EventPackage)*) e.event_package)
            .array
            .sort!((a, b) => a.fingerprint < b.fingerprint);
        import std.algorithm.setops : setDifference;

        auto changes = setDifference!((a, b) => a.fingerprint < b.fingerprint)(received_epacks, own_epacks);

        version (EPOCH_LOG) {
            log("owner_epacks %s", own_epacks.length);
        }
        version (EPOCH_LOG) {
            if (!changes.empty) {
                log("changes found");
            }
        }
        // delta received from sharp should be added to our own node. 
        foreach (epack; changes) {
            const epack_node = getNode(epack.pubkey);
            auto first_event = new Event(epack, this);
            if (epack_node.event is null) {
                check(first_event.isEva, ConsensusFailCode.GOSSIPNET_FIRST_EVENT_MUST_BE_EVA);
            }
            _event_cache[first_event.fingerprint] = first_event;
            front_seat(first_event);
        }

        auto result = setDifference!((a, b) => a.fingerprint < b.fingerprint)(own_epacks, received_epacks).array;

        const state = ExchangeState.RIPPLE;
        return Wavefront(result, Tides.init, state);

    }

    /** 
     * First time it is called we only send our own eva since this is all we know.
     * Later we send everything it knows.  
     * Returns: the wavefront for a node that either wants to join or is booting.
     */
    const(Wavefront) sharpWave() {
        auto result = _nodes.byValue
            .filter!((n) => (n._event !is null))
            .map!((n) => cast(immutable(EventPackage)*) n._event.event_package)
            .array;

        return Wavefront(result, null, ExchangeState.SHARP);
    }

    void wavefront(
            const HiRPC.Receiver received,
            lazy const(sdt_t) time,
            void delegate(const(HiRPC.Sender) send_wave) @safe response,
            const(Document) delegate() @safe payload) {

        alias consensus = consensusCheckArguments!(GossipConsensusException);
        immutable from_channel = received.pubkey;
        const received_wave = received.params!(Wavefront)(hirpc.net);
        check(valid_channel(from_channel), ConsensusFailCode.GOSSIPNET_ILLEGAL_CHANNEL);
        auto received_node = getNode(from_channel);

        version (EPOCH_LOG) {
            log.trace("received_wave(%s <- %s)", received_wave.state, received_node.state);
        }
        scope (exit) {
            version (EPOCH_LOG) {
                log.trace("next <- %s", received_node.state);
            }
        }
        const(Wavefront) wavefront_response() @safe {
            with (ExchangeState) {
                final switch (received_wave.state) {
                case NONE:
                case INIT_TIDE:
                    consensus(received_wave.state)
                        .check(false, ConsensusFailCode.GOSSIPNET_ILLEGAL_EXCHANGE_STATE);
                    break;

                case SHARP: ///
                    received_node.state = NONE;
                    received_node.sticky_state = SHARP;
                    version (EPOCH_LOG) {
                        log("received sharp %s", received_node.channel.cutHex);
                    }
                    const sharp_response = sharpResponse(received_wave);
                    return sharp_response;
                case RIPPLE:
                    received_node.state = RIPPLE;
                    received_node.sticky_state = RIPPLE;

                    if (areWeInGraph) {
                        break;
                    }

                    // if we receive a ripplewave, we must add the eva events to our own graph.
                    auto received_epacks = received_wave
                        .epacks
                        .map!((e) => cast(immutable(EventPackage)*) e)
                        .array
                        .sort!((a,b) => a.fingerprint < b.fingerprint);
                    auto _own_epacks = _nodes.byValue
                        .map!((n) => n[])
                        .joiner
                        .map!((e) => cast(immutable(EventPackage)*) e.event_package)
                        .array
                        .sort!((a, b) => a.fingerprint < b.fingerprint);

                    auto changes = setDifference!((a, b) => a.fingerprint < b.fingerprint)(received_epacks, _own_epacks);

                    foreach (epack; changes) {
                        const epack_node = getNode(epack.pubkey);
                        auto first_event = new Event(epack, this);
                        if (epack_node.event is null) {
                            check(first_event.isEva, ConsensusFailCode.GOSSIPNET_FIRST_EVENT_MUST_BE_EVA);
                        }
                        _event_cache[first_event.fingerprint] = first_event;
                        front_seat(first_event);
                    }

                    const contain_all =
                        _nodes
                            .byValue
                            .all!((n) => n._event !is null);

                    if (contain_all && node_size == _nodes.length) {
                        const own_epacks = _nodes
                            .byValue
                            .map!((n) => n[])
                            .joiner
                            .map!((e) => e.event_package)
                            .array;
                        version (EPOCH_LOG) {
                            log("%s going to init witnesses, areweingraph %s", _owner_node.channel.cutHex, areWeInGraph);
                        }
                        initialize_witness(own_epacks);
                    }
                    break;
                case COHERENT:
                    received_node.state = NONE;
                    received_node.sticky_state = COHERENT;
                    version (EPOCH_LOG) {
                        log("received coherent from: %s, self %s", received_node.channel.cutHex, _owner_node.channel
                                .cutHex);
                    }
                    if (!areWeInGraph) {
                        try {
                            version (EPOCH_LOG) {
                                log("GOING to init");
                            }
                            initialize_witness(received_wave.epacks);
                            _owner_node.sticky_state = COHERENT;
                            _joining = No.joining;
                        }
                        catch (ConsensusException e) {
                            // initialized witness not correct
                        }
                    }
                    break;
                case TIDAL_WAVE: ///
                    if (received_node.state !is NONE || !areWeInGraph || joining) {
                        received_node.state = NONE;
                        return buildWavefront(BREAKING_WAVE);
                    }
                    check(received_wave.epacks.length is 0, ConsensusFailCode
                            .GOSSIPNET_TIDAL_WAVE_CONTAINS_EVENTS);
                    received_node.state = received_wave.state;
                    immutable epack = event_pack(time, null, payload());
                    const registered = registerEventPackage(epack);
                    assert(registered);

                    const wave = buildWavefront(FIRST_WAVE, received_wave.tides);

                    return wave;
                case BREAKING_WAVE:
                    received_node.state = NONE;
                    break;
                case FIRST_WAVE:
                    if (received_node.state !is INIT_TIDE || !areWeInGraph) {
                        received_node.state = NONE;
                        return buildWavefront(BREAKING_WAVE);
                    }
                    received_node.state = NONE;

                    const from_front_seat = register_wavefront(received_wave, from_channel);
                    immutable epack = event_pack(time, from_front_seat, payload());
                    const registreted = registerEventPackage(epack);
                    assert(registreted, "The event package has not been registered correct (The wave should be dumped)");
                    return buildWavefront(SECOND_WAVE, received_wave.tides);
                case SECOND_WAVE:
                    if (received_node.state !is TIDAL_WAVE || !areWeInGraph || joining) {
                        received_node.state = NONE;
                        return buildWavefront(BREAKING_WAVE);
                    }
                    received_node.state = NONE;
                    const from_front_seat = register_wavefront(received_wave, from_channel);
                    immutable epack = event_pack(time, from_front_seat, payload());
                    const registrated = registerEventPackage(epack);
                    assert(registrated, "The event package has not been registered correct (The wave should be dumped)");
                }
                return buildWavefront(NONE);
            }
        }

        const return_wavefront = wavefront_response;
        if (return_wavefront.state !is ExchangeState.NONE) {
            const sender = hirpc.wavefront(return_wavefront);
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
    class Node {
        ExchangeState state;
        immutable size_t node_id;
        immutable(Pubkey) channel;
        private bool _offline;
        private this(const Pubkey channel, const size_t node_id) pure nothrow {
            this.node_id = node_id;
            this.channel = channel;
        }

        protected ExchangeState _sticky_state = ExchangeState.RIPPLE;

        void sticky_state(const(ExchangeState) state) pure nothrow @nogc {

            if (state > _sticky_state) {
                _sticky_state = state;
            }
        }

        final bool offline() const pure nothrow @nogc {
            return _offline;
        }

        const(ExchangeState) sticky_state() const pure nothrow @nogc {
            return _sticky_state;
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
                // Event.check(event.mother !is null, ConsensusFailCode.EVENT_MOTHER_LESS);
                _event = event;
            }
        }

        private Event _event; /// This is the last event in this Node

        @nogc
        const(Event) event() const pure nothrow {
            return _event;
        }

        @nogc pure nothrow {
            package final Event event() {
                return _event;
            }

            final bool isOnline() const {
                return (_event !is null);
            }

            final int altitude() const
            in {
                assert(_event !is null, "This node has no events so the altitude is not set yet");
            }
            out {
                assert(_event.isFront);
            }
            do {
                return _event.altitude;
            }

            package Event.Range!false opSlice() {
                if (_event) {
                    return _event[];
                }
                return Event.Range!false(null);
            }

            Event.Range!true opSlice() const {
                if (_event) {
                    return _event[];
                }
                return Event.Range!true(null);
            }
        }
    }

    import std.traits : fullyQualifiedName;

    alias NodeRange = typeof((cast(const) _nodes).byValue);

    @nogc
    NodeRange opSlice() const pure nothrow {
        return _nodes.byValue;
    }

    @nogc
    size_t active_nodes() const pure nothrow {
        return _nodes.length;
    }

    @nogc
    const(SecureNet) net() const pure nothrow {
        return hirpc.net;
    }

    package Node getNode(Pubkey channel) pure {
        const next_id = next_node_id;
        return _nodes.require(channel, new Node(channel, next_id));
    }

    @nogc
    bool isMajority(const size_t voting) const pure nothrow {
        return .isMajority(voting, node_size);
    }

    private void remove_node(Node n) nothrow
    in {
        assert(n !is null);
        assert(n.channel in _nodes, __format("Node id %d is not removable because it does not exist", n
                .node_id));
    }
    do {
        _nodes.remove(n.channel);
    }

    bool remove_node(const Pubkey pkey) nothrow {
        if (pkey in _nodes) {
            _nodes.remove(pkey);
            return true;
        }
        return false;
    }

    void mark_offline(const(size_t) node_id) nothrow {

        auto mark_node = _nodes.byKeyValue
            .filter!((pair) => !pair.value._offline)
            .filter!((pair) => pair.value.node_id == node_id)
            .map!(pair => pair.value);
        if (mark_node.empty) {
            return;
        }
        mark_node.front._offline = true;
    }

    @nogc
    uint next_event_id() pure nothrow {
        event_id++;
        if (event_id is event_id.init) {
            return event_id.init + 1;
        }
        return event_id;
    }

    size_t next_node_id() const pure nothrow {
        if (_nodes.length is 0) {
            return 0;
        }
        BitMask used_nodes;
        _nodes.byValue
            .map!(a => a.node_id)
            .each!((n) { used_nodes[n] = true; });
        return (~used_nodes)[].front;
    }

    //bool disable_scrapping;

    enum max_package_size = 0x1000;
    enum round_clean_limit = 10;

    /++
     Dumps all events in the Hashgraph to a file
     +/
    void fwrite(string filename, Pubkey[string] node_labels = null) {
        import tagion.hashgraphview.EventView;
        import tagion.hibon.HiBONFile : fwrite;

        size_t[Pubkey] node_id_relocation;
        if (node_labels.length) {
            // assert(node_labels.length is _nodes.length);
            auto names = node_labels.keys;
            names.sort;
            foreach (i, name; names) {
                node_id_relocation[node_labels[name]] = i;
            }

        }
        auto events = new HiBON;
        (() @trusted {
            foreach (n; _nodes) {
                const node_id = (node_id_relocation.length is 0) ? size_t.max : node_id_relocation[n.channel];
                n[]
                    .filter!((e) => !e.isGrounded)
                    .each!((e) => events[e.id] = EventView(e, node_id));
            }
        })();
        auto h = new HiBON;
        h[Params.size] = node_size;
        h[Params.events] = events;
        filename.fwrite(h);
    }

}
