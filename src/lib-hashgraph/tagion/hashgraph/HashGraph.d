/// Consensus HashGraph main object 
module tagion.hashgraph.HashGraph;

import std.stdio;
import std.conv;
import std.format;
import std.exception : assumeWontThrow;
import std.algorithm.sorting : sort;
import std.algorithm.searching : all;
import std.algorithm.iteration : map, each, filter;
import std.range : tee;
import std.array : array;

import tagion.hashgraph.Event;
import tagion.crypto.SecureInterfaceNet;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : isHiBONRecord;
import tagion.communication.HiRPC;
import tagion.utils.StdTime;

import tagion.basic.Debug : __format;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey, Signature, Privkey;
import tagion.hashgraph.HashGraphBasic;
import tagion.utils.BitMask;

import tagion.logger.Logger;
import tagion.gossip.InterfaceNet;

// debug
import tagion.hibon.HiBONJSON;

version (unittest) {
    version = hashgraph_fibertest;
}

@safe
class HashGraph {
    enum default_scrap_depth = 10;
    enum default_awake = 3;
    //bool print_flag;
    int scrap_depth = default_scrap_depth;
    uint awake = default_awake;
    import tagion.basic.ConsensusExceptions;

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
    private {
        BitMask _excluded_nodes_mask;
        Node[Pubkey] _nodes; // List of participating _nodes T
        uint event_id;
        sdt_t last_epoch_time;
    }
    protected Node _owner_node;
    const(Node) owner_node() const pure nothrow @nogc {
        return _owner_node;
    }

    /**
 * Get a map of all the nodes currently handled by the graph 
 * Returns: 
 */
    const(Node[Pubkey]) nodes() const pure nothrow @nogc {
        return _nodes;
    }

    const HiRPC hirpc;

    // function not used
    @nogc
    bool active() pure const nothrow {
        return true;
    }

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
    alias EpochCallback = void delegate(const(Event[]) events, const sdt_t epoch_time) @safe;
    alias ExcludedNodesCallback = void delegate(ref BitMask mask, const(HashGraph) hashgraph) @safe;
    alias EventPackageCallback = void delegate(immutable(EventPackage*) epack) @safe;
    const EpochCallback epoch_callback; /// Call when an epoch has been produced
    const EventPackageCallback epack_callback; /// Call back which is called when an event-package has been added to the event chache.
    const ExcludedNodesCallback excluded_nodes_callback;

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
            const ValidChannel valid_channel,
            const EpochCallback epoch_callback,
            const EventPackageCallback epack_callback = null,
            const ExcludedNodesCallback excluded_nodes_callback = null,
            string name = null) {
        hirpc = HiRPC(net);
        this._owner_node = getNode(hirpc.net.pubkey);
        this.node_size = node_size;
        this.valid_channel = valid_channel;
        this.epoch_callback = epoch_callback;
        this.epack_callback = epack_callback;
        this.excluded_nodes_callback = excluded_nodes_callback;
        this.name = name;
        _rounds = Round.Rounder(this);
    }

    void initialize_witness(const(immutable(EventPackage)*[]) epacks)
    in {
        assert(_nodes.length > 0 && (channel in _nodes),
                "Owen Eva event needs to be create before witness can be initialized");
    }
    do {
        Node[Pubkey] recovered_nodes;
        auto owner_node = getNode(channel);
        scope (success) {
            void init_event(immutable(EventPackage*) epack) {
                auto event = new Event(epack, this);
                _event_cache[event.fingerprint] = event;
                event.witness_event;
                writefln("init_event time %s", event.event_body.time);
                _rounds.last_round.add(event);
                front_seat(event);
            }

            _rounds.erase;
            _rounds = Round.Rounder(this);
            _rounds.last_decided_round = _rounds.last_round;
            (() @trusted { _event_cache.clear; })();
            init_event(owner_node.event.event_package);
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
        }
        scope (failure) {
            _nodes = recovered_nodes;
        }
        recovered_nodes = _nodes;
        _nodes = null;
        check(isMajority(cast(uint) epacks.length), ConsensusFailCode.HASHGRAPH_EVENT_INITIALIZE);
        consensus(epacks.length)
            .check(epacks.length <= node_size, ConsensusFailCode.HASHGRAPH_EVENT_INITIALIZE);
        getNode(channel); // Make sure that node_id == 0 is owner node
        foreach (epack; epacks) {
            if (epack.pubkey != channel) {
                check(!(epack.pubkey in _nodes), ConsensusFailCode.HASHGRAPH_DUBLICATE_WITNESS);
                auto node = getNode(epack.pubkey);
            }
        }
    }

    package bool can_round_be_decided(const Round r) nothrow {
        const result = _nodes
            .byValue
            .filter!((n) => (r.events[n.node_id] is null))
            .filter!((n) => !excluded_nodes_mask[n.node_id])
            .tee!((n) => n.asleep)
            .all!((n) => n.sleeping);
        return result;
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

    @trusted
    const(Pubkey[]) channels() const pure nothrow {
        return _nodes.keys;
    }

    bool not_used_channels(const(Pubkey) selected_channel) {
        if (selected_channel == channel) {
            return false;
        }
        const node = _nodes.get(selected_channel, null);
        if (node) {
            return node.state is ExchangeState.NONE;
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
            // writefln("init_tide time: %s", time);
            immutable epack = event_pack(time, null, doc);
            const registrated = registerEventPackage(epack);
            assert(registrated, "Should not fail here");
            const sender = hirpc.wavefront(tidalWave);
            return sender;
        }

        const(HiRPC.Sender) ripple_sender() @safe {
            log("Send ripple");
            writefln("SENDING RIPPLE");
            const ripple_wavefront = rippleWave(Wavefront());
            const sender = hirpc.wavefront(ripple_wavefront);
            return sender;
        }

        if (areWeInGraph) {
            const send_channel = responde(
                    &not_used_channels,
                    &payload_sender);
            if (send_channel !is Pubkey(null)) {
                getNode(send_channel).state = ExchangeState.INIT_TIDE;
            }
        }
        else {
            const send_channel = responde(
                    &not_used_channels,
                    &ripple_sender);
        }
    }

    immutable(EventPackage*) event_pack(lazy const sdt_t time, const(Event) father_event, const Document doc) @trusted {
        const mother_event = getNode(channel).event;
        immutable ebody = EventBody(doc, mother_event, father_event, time);
        return cast(immutable) new EventPackage(hirpc.net, ebody);
    }

    immutable(EventPackage*) eva_pack(lazy const sdt_t time, const Buffer nonce) @trusted {
        const payload = EvaPayload(channel, nonce);
        immutable eva_event_body = EventBody(payload.toDoc, null, null, time);
        immutable epack = cast(immutable) new EventPackage(hirpc.net, eva_event_body);
        return epack;
    }

    Event createEvaEvent(lazy const sdt_t time, const Buffer nonce) {
        immutable eva_epack = eva_pack(time, nonce);
        auto eva_event = new Event(eva_epack, this);

        _event_cache[eva_event.fingerprint] = eva_event;
        front_seat(eva_event);
        return eva_event;
    }

    alias EventPackageCache = immutable(EventPackage)*[Buffer];
    alias EventCache = Event[Buffer];

    protected {
        EventCache _event_cache;
    }

    void eliminate(scope const(Buffer) fingerprint) {
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

    package void epoch(const(Event)[] events, const sdt_t epoch_time, const Round decided_round) {
        log.trace("%s Epoch round %d event.count=%d witness.count=%d event in epoch=%d time=%s",
                name, decided_round.number,
                Event.count, Event.Witness.count, events.length, epoch_time);
        if (epoch_callback !is null) {
            epoch_callback(events, epoch_time);
        }
        if (excluded_nodes_callback !is null) {
            excluded_nodes_callback(_excluded_nodes_mask, this);
        }
        if (scrap_depth > 0) {
            live_events_statistic(Event.count);
            mixin Log!(live_events_statistic);
            live_witness_statistic(Event.Witness.count);
            mixin Log!(live_witness_statistic);
            _rounds.dustman;
        }
    }

    /++
     @return true if the event package has been register correct
     +/
    Event registerEventPackage(
            immutable(EventPackage*) event_pack)
    in {
        import tagion.utils.Miscellaneous : toHexString;

        assert(event_pack.fingerprint !in _event_cache, format("Event %s has already been registerd", event_pack
                .fingerprint.toHexString));
    }
    do {
        if (valid_channel(event_pack.pubkey)) {
            auto event = new Event(event_pack, this);
            _event_cache[event.fingerprint] = event;
            if (epack_callback) {
                epack_callback(event_pack);
            }
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
                if (e.fingerprint in _event_cache) {
                    const event = _event_cache[e.fingerprint];
                }
                if (!(e.fingerprint in event_package_cache || e.fingerprint in _event_cache)) {
                    event_package_cache[e.fingerprint] = e;
                }
            }
        }

        final Event lookup(const(Buffer) fingerprint) {
            if (fingerprint in _event_cache) {
                return _event_cache[fingerprint];
            }
            else if (fingerprint in event_package_cache) {
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
            if (fingerprint) {
                event = lookup(fingerprint);
                Event.check(event !is null, ConsensusFailCode.EVENT_MISSING_IN_CACHE);
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
        scope event_ptr = fingerprint in _event_cache;
        if (event_ptr) {
            return *event_ptr;
        }
        return null;
    }

    /++
     Returns:
     The front event of the send channel
     +/
    const(Event) register_wavefront(
            const Wavefront received_wave,
            const Pubkey from_channel) {
        _register = new Register(received_wave);
        scope (exit) {
            mixin Log!(wavefront_event_package_statistic);
            mixin Log!(wavefront_event_package_used_statistic);
            _register = null;
        }
        assert(_register.event_package_cache.length);
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
            else {
                n[].each!((e) => result ~= e.event_package);
            }
        }
        assert(result.length);
        return Wavefront(result, owner_tides, state);
    }

    const(Wavefront) rippleWave(const Wavefront received_wave)
    in {
        assert(
                received_wave.state is ExchangeState.NONE ||
                received_wave.state is ExchangeState.RIPPLE);
    }
    do {
        if (areWeInGraph) {
            immutable(EventPackage)*[] result = _rounds.last_decided_round
                .events
                .filter!((e) => (e !is null))
                .map!((e) => cast(immutable(EventPackage)*) e.event_package)
                .array;
            return Wavefront(result, null, ExchangeState.COHERENT);
        }
        // writefln("rippleWave: %s", received_wave.toDoc.toPretty);
        foreach (epack; received_wave.epacks) {
            if (getNode(epack.pubkey).event is null) {
                writefln("epack time: %s", epack.event_body.time);
                auto first_event = new Event(epack, this);
                writefln("foreach event %s", first_event.event_package.event_body.time);
                check(first_event.isEva, ConsensusFailCode.GOSSIPNET_FIRST_EVENT_MUST_BE_EVA);
                _event_cache[first_event.fingerprint] = first_event;
                front_seat(first_event);
            }
        }
        auto result = _nodes.byValue
            .filter!((n) => (n._event !is null))
            .map!((n) => cast(immutable(EventPackage)*) n._event.event_package)
            .array;

        const contain_all =
            _nodes
                .byValue
                .all!((n) => n._event !is null);

        const state = (_nodes.length is node_size && contain_all) ? ExchangeState.COHERENT : ExchangeState.RIPPLE;

        return Wavefront(result, null, state);
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
        if (Event.callbacks) {
            Event.callbacks.receive(received_wave);
        }
        log.trace("received_wave(%s <- %s)", received_wave.state, received_node.state);
        scope (exit) {
            log.trace("next <- %s", received_node.state);
        }
        const(Wavefront) wavefront_response() @safe {
            with (ExchangeState) {
                final switch (received_wave.state) {
                case NONE:
                case INIT_TIDE:
                    consensus(received_wave.state)
                        .check(false, ConsensusFailCode.GOSSIPNET_ILLEGAL_EXCHANGE_STATE);
                    break;
                case RIPPLE: ///
                    received_node.state = NONE;
                    received_node.sticky_state = RIPPLE;
                    // writefln("received wave: %s", received_wave.toDoc.toPretty);
                    const ripple_wave = rippleWave(received_wave);
                    return ripple_wave;
                case COHERENT:
                    received_node.state = NONE;
                    received_node.sticky_state = COHERENT;
                    if (!areWeInGraph) {
                        try {
                            initialize_witness(received_wave.epacks);
                            _owner_node.sticky_state = COHERENT;
                        }
                        catch (ConsensusException e) {
                            // initialized witness not correct
                        }
                    }
                    break;
                case TIDAL_WAVE: ///
                    if (received_node.state !is NONE || !areWeInGraph) {
                        received_node.state = NONE;
                        return buildWavefront(BREAKING_WAVE);
                    }
                    check(received_wave.epacks.length is 0, ConsensusFailCode
                            .GOSSIPNET_TIDAL_WAVE_CONTAINS_EVENTS);
                    received_node.state = received_wave.state;
                    immutable epack = event_pack(time, null, payload());
                    const registered = registerEventPackage(epack);
                    assert(registered);
                    return buildWavefront(FIRST_WAVE, received_wave.tides);
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
                    if (received_node.state !is TIDAL_WAVE || !areWeInGraph) {
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
        @nogc
        this(const Pubkey channel, const size_t node_id) pure nothrow {
            this.node_id = node_id;
            this.channel = channel;
        }

        protected ExchangeState _sticky_state = ExchangeState.RIPPLE;

        void sticky_state(const(ExchangeState) state) pure nothrow @nogc {

            if (state > _sticky_state) {
                _sticky_state = state;
            }
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
                Event.check(event.mother !is null, ConsensusFailCode.EVENT_MOTHER_LESS);
                _event = event;
            }
            awake = this.outer.awake;
        }

        private Event _event; /// This is the last event in this Node

        @nogc
        void asleep() pure nothrow {
            awake = (awake is 0) ? 0 : awake - 1;
        }

        @nogc
        bool sleeping() const pure nothrow {
            return awake is 0;
        }

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
    bool isMajority(const uint voting) const pure nothrow {
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

    @nogc
    uint next_event_id() pure nothrow {
        event_id++;
        if (event_id is event_id.init) {
            return event_id.init + 1;
        }
        return event_id;
    }

    @trusted
    size_t next_node_id() const pure nothrow {
        if (_nodes.length is 0) {
            return 0;
        }
        scope BitMask used_nodes;
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
    //   @trusted
    void fwrite(string filename, Pubkey[string] node_labels = null) {
        import tagion.hibon.HiBONRecord : fwrite;
        import tagion.hashgraphview.EventView;

        size_t[Pubkey] node_id_relocation;
        if (node_labels.length) {
            assert(node_labels.length is _nodes.length);
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

    import tagion.hashgraphview.Compare;

    /++
     This function makes sure that the HashGraph has all the events connected to this event
     +/
    version (hashgraph_fibertest) {
        static class TestNetwork { //(NodeList) if (is(NodeList == enum)) {
            import core.thread.fiber : Fiber;
            import tagion.crypto.SecureNet : StdSecureNet;
            import tagion.gossip.InterfaceNet : GossipNet;
            import tagion.utils.Random;
            import tagion.utils.Queue;
            import tagion.hibon.HiBONJSON;
            import std.datetime.systime : SysTime;
            import core.time;

            TestGossipNet authorising;
            Random!size_t random;
            SysTime global_time;
            enum timestep {
                MIN = 50,
                MAX = 150
            }

            alias ChannelQueue = Queue!Document;

            class TestGossipNet : GossipNet {
                protected {
                    ChannelQueue[Pubkey] channel_queues;
                    sdt_t _current_time;
                }
                void start_listening() {
                    // empty
                }

                @property
                void time(const(sdt_t) t) {
                    _current_time = sdt_t(t);
                }

                @property
                const(sdt_t) time() pure const {
                    return _current_time;
                }

                bool isValidChannel(const(Pubkey) channel) const pure nothrow {
                    return (channel in channel_queues) !is null;
                }

                void send(const(Pubkey) channel, const(HiRPC.Sender) sender) {
                    channel_queues[channel].write(sender.toDoc);
                }

                void send(const(Pubkey) channel, const(Document) doc) nothrow {
                    log.trace("send to %s %d bytes", channel.cutHex, doc.serialize.length);
                    if (Event.callbacks) {
                        Event.callbacks.send(channel, doc);
                    }
                    channel_queues[channel].write(doc);
                }

                final void send(T)(const(Pubkey) channel, T pack) if (isHiBONRecord!T) {
                    send(channel, pack.toDoc);
                }

                const(Document) receive(const Pubkey channel) nothrow {
                    return channel_queues[channel].read;
                }

                void close() {
                    // Dummy empty
                }

                const(Pubkey) select_channel(ChannelFilter channel_filter) {
                    foreach (count; 0 .. channel_queues.length / 2) {
                        const node_index = random.value(0, channel_queues.length);
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
                        ChannelFilter channel_filter,
                        SenderCallBack sender) {
                    const send_channel = select_channel(channel_filter);
                    if (send_channel.length) {
                        send(send_channel, sender());
                    }
                    return send_channel;
                }

                bool empty(const Pubkey channel) const pure nothrow {
                    return channel_queues[channel].empty;
                }

                void add_channel(const Pubkey channel) {
                    channel_queues[channel] = new ChannelQueue;
                }

                void remove_channel(const Pubkey channel) {
                    channel_queues.remove(channel);
                }
            }

            class FiberNetwork : Fiber {
                HashGraph _hashgraph;
                //immutable(string) name;
                @trusted
                this(HashGraph h) nothrow
                in {
                    assert(_hashgraph is null);
                }
                do {
                    super(&run);
                    _hashgraph = h;
                }

                const(HashGraph) hashgraph() const pure nothrow {
                    return _hashgraph;
                }

                sdt_t time() {
                    const systime = global_time + random.value(timestep.MIN, timestep.MAX).msecs;
                    return sdt_t(systime.stdTime);
                }

                private void run() {
                    { // Eva Event
                        immutable buf = cast(Buffer) _hashgraph.channel;
                        const nonce = cast(Buffer) _hashgraph.hirpc.net.calcHash(buf);
                        auto eva_event = _hashgraph.createEvaEvent(time, nonce);

                        if (eva_event is null) {
                            log.error("The channel of this oner is not valid");
                            return;
                        }
                    }
                    uint count;
                    bool stop;
                    const(Document) payload() @safe {
                        auto h = new HiBON;
                        h["node"] = format("%s-%d", _hashgraph.name, count);
                        return Document(h);
                    }

                    while (!stop) {
                        while (!authorising.empty(_hashgraph.channel)) {
                            const received = _hashgraph.hirpc.receive(
                                    authorising.receive(_hashgraph.channel));
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
                        (() @trusted { yield; })();
                        //const onLine=_hashgraph.areWeOnline;
                        const init_tide = random.value(0, 2) is 1;
                        if (init_tide) {
                            _hashgraph.init_tide(
                                    &authorising.gossip,
                                    &payload,
                                    time);
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

            this(const(string[]) node_names) {
                authorising = new TestGossipNet;
                immutable N = node_names.length; //EnumMembers!NodeList.length;
                foreach (name; node_names) {
                    immutable passphrase = format("very secret %s", name);
                    auto net = new StdSecureNet();
                    net.generateKeyPair(passphrase);
                    auto h = new HashGraph(N, net, &authorising.isValidChannel, null, null, null, name);
                    h.scrap_depth = 0;
                    networks[net.pubkey] = new FiberNetwork(h);
                }
                networks.byKey.each!((a) => authorising.add_channel(a));
            }
        }

    }

    import std.compiler;

    static if (!vendor.llvm || !(version_major == 2 && version_minor == 99)) {
        // Unittest segfaults in LDC 1.29 (2.099)
        version (none) unittest {
            import tagion.hashgraph.Event;
            import std.stdio;
            import std.traits;
            import std.conv;
            import std.datetime;
            import tagion.hibon.HiBONJSON;
            import tagion.logger.Logger : log, LogLevel;

            log.push(LogLevel.NONE);

            enum NodeLabel {
                Alice,
                Bob,
                Carol,
                Dave,

                Elisa,
                Freja,
                George, // Hermine,

                // Illa,
                // Joella,
                // Kattie,
                // Laureen,
                // Manual,
                // Niels,
                // Ove,
                // Poul,
                // Roberto,
                // Samatha,
                // Tamekia,

            }

            auto node_labels = [EnumMembers!NodeLabel].map!((E) => E.to!string).array;
            auto network = new TestNetwork(node_labels); //!NodeLabel();
            network.networks.byValue.each!((ref _net) => _net._hashgraph.scrap_depth = 0);
            network.random.seed(123456789);

            network.global_time = SysTime.fromUnixTime(1_614_355_286); //SysTime(DateTime(2021, 2, 26, 15, 59, 46));

            const channels = network.channels;

            try {
                foreach (i; 0 .. 550) {
                    const channel_number = network.random.value(0, channels.length);
                    const channel = channels[channel_number];
                    auto current = network.networks[channel];
                    (() @trusted { current.call; })();
                }
            }
            catch (Exception e) {
                (() @trusted { writefln("%s", e); assert(0, e.msg); })();
            }

            version (none) {
                writefln("Save Alice");
                Pubkey[string] node_labels;

                foreach (channel, _net; network.networks) {
                    node_labels[_net._hashgraph.name] = channel;
                }
                foreach (_net; network.networks) {
                    const filename = fileId(_net._hashgraph.name);
                    _net._hashgraph.fwrite(filename.fullpath, node_labels);
                }
            }

            bool event_error(const Event e1, const Event e2, const Compare.ErrorCode code) @safe nothrow {
                static string print(const Event e) nothrow {
                    if (e) {
                        const round_received = (e.round_received) ? e.round_received.number.to!string : "#";
                        return assumeWontThrow(format("(%d:%d:%d:r=%d:rr=%s:%s)",
                                e.id, e.node_id, e.altitude, e.round.number, round_received,
                                e.fingerprint.cutHex));
                    }
                    return assumeWontThrow(format("(%d:%d:%s:%s)", 0, -1, 0, "nil"));
                }

                assumeWontThrow(writefln("Event %s and %s %s", print(e1), print(e2), code));
                return false;
            }

            auto names = network.networks.byValue
                .map!((net) => net._hashgraph.name)
                .array.dup
                .sort
                .array;

            HashGraph[string] hashgraphs;
            foreach (net; network.networks) {
                hashgraphs[net._hashgraph.name] = net._hashgraph;
            }

            foreach (i, name_h1; names[0 .. $ - 1]) {
                const h1 = hashgraphs[name_h1];
                foreach (name_h2; names[i + 1 .. $]) {
                    const h2 = hashgraphs[name_h2];
                    auto comp = Compare(h1, h2, &event_error);
                    // writefln("%s %s round_offset=%d order_offset=%d",
                    //     h1.name, h2.name, comp.round_offset, comp.order_offset);
                    const result = comp.compare;
                    assert(result, format("HashGraph %s and %s is not the same", h1.name, h2.name));
                }
            }
        }
    }
}

version (unittest) {
    import basic = tagion.basic.basic;
    import std.range : dropExactly;
    import tagion.utils.Miscellaneous : cutHex;

    const(basic.FileNames) fileId(T = HashGraph)(string prefix = null) @safe {
        import basic = tagion.basic.basic;

        return basic.fileId!T("hibon", prefix);
    }
}
