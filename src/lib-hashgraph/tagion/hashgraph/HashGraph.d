/// Consensus HashGraph main object 
module tagion.hashgraph.HashGraph;

import std.stdio;
import std.conv;
import std.format;
import std.exception : assumeWontThrow;
import std.algorithm;
import std.range;
import std.array : array;

import tagion.hashgraph.Event;
import tagion.crypto.SecureInterfaceNet;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : isHiBONRecord;
import tagion.communication.HiRPC;
import tagion.utils.StdTime;
import tagion.hashgraph.RefinementInterface;

import tagion.basic.Debug : __format;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey, Signature, Privkey;
import tagion.hashgraph.HashGraphBasic;
import tagion.utils.BitMask;
import std.typecons : Flag, Yes, No;

import tagion.logger.Logger;
import tagion.gossip.InterfaceNet;

// debug
import tagion.hibon.HiBONJSON;
import tagion.basic.Debug;
import tagion.utils.Miscellaneous : cutHex;

version (unittest) {
    version = hashgraph_fibertest;
}

@safe
class HashGraph {
    enum default_scrap_depth = 10;
    //bool print_flag;
    int scrap_depth = default_scrap_depth;
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
    BitMask _excluded_nodes_mask;
    private {
        Node[Pubkey] _nodes; // List of participating _nodes T
        uint event_id;
        sdt_t last_epoch_time;
        Refinement refinement;
        Flag!"joining" _joining;
    }
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
            string name = null) {
        hirpc = HiRPC(net);
        this._owner_node = getNode(hirpc.net.pubkey);
        this.node_size = node_size;
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
        Node[Pubkey] recovered_nodes;
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
            _event_cache = null;
            // (() @trusted { _event_cache.clear; })();
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

            _nodes.byValue.map!(n => n.event).each!(e => e.initializeReceivedOrder);
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
                check(!(epack.pubkey in _nodes), ConsensusFailCode.HASHGRAPH_DUBLICATE_WITNESS);
                auto node = getNode(epack.pubkey);
            }
        }
    }

    package bool possible_round_decided(const Round r) nothrow {
        const witness_count = r.events
            .count!((e) => (e !is null) && e.isWitness);
        // __write("round=%s, witness count=%s", r.number, witness_count);
        if (!isMajority(witness_count)) {
            // __write("possible_round_decided !ismajority");
            return false;
        }
        const possible_decided = r.events
            .all!((e) => e is null || e.isWitness);
        // __write("possible_round_decided=%s", possible_decided);
        return possible_decided;

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

        const(HiRPC.Sender) sharp_sender() @safe {
            log("Send ripple");
            writefln("SENDING sharp sender: %s", owner_node.channel.cutHex);

            const sharp_wavefront = sharpWave();
            const sender = hirpc.wavefront(sharp_wavefront);
            return sender;
        }

        if (areWeInGraph) {
            const send_channel = responde(
                    &not_used_channels,
                    &payload_sender);
            if (send_channel !is Pubkey(null)) {
                
                getNode(send_channel).state = ExchangeState.INIT_TIDE;
                
                // assert(_nodes.length <= node_size, format("Node[] must not be greater than node_size %s", send_channel.cutHex)); // used for debug
            }
        }
        else {
            const send_channel = responde(
                    &not_used_channels,
                    &sharp_sender);
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
        writeln("creating eva event");
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

    package void epoch(Event[] event_collection, const Round decided_round) {
        // if (epoch_counts > 0) {
            refinement.epoch(event_collection, decided_round);
        // }
        // epoch_counts++;
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
            refinement.epack(event_pack);
            event.connect(this);
            return event;
        }
        return null;
    }

    class Register {
        private EventPackageCache event_package_cache;

        // bool isNewer(immutable(EventPackage*) event_package) const pure nothrow {
        //     const node = assumeWontThrow(_nodes.get(event_package.pubkey, Node.init));
        //     return (node !is Node.init) && higher(event_package.event_body.altitude, node.event.event_package.event_body.altitude);
        // }
        this(const Wavefront received_wave) pure nothrow {
            uint count_events;
            __write("calling CTOR");
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

                // if (event is null) {
                    
                //     const fingerprint_in_nodes = _nodes.events
                //         .filter!((e) => e !is null)
                //         .map!(e => e.event_package.fingerprint)
                //         .canFind(fingerprint);

                //     if (fingerprint_in_nodes) { return null; }                
                // }
                
                if (!(_joining || event !is null)) {
                    
                    writefln("register error: %s", fingerprint.cutHex);
                
                }
                // Event.check(_joining || event !is null, ConsensusFailCode.EVENT_MISSING_IN_CACHE);
                if (event !is null) {
                    event.connect(this.outer);
                }
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
        // assert(_register.event_package_cache.length);

        if (_owner_node.channel.cutHex == "037ba30f467d5de5") {
            writefln("register wavefront new node from %s", from_channel.cutHex);
            received_wave.epacks.map!((epack) => [epack.pubkey.cutHex, epack.event_body.altitude.to!string, epack.fingerprint.cutHex])
            .each!writeln;

            writefln("own altitudes");
            _nodes.byValue.map!(n => [n.event.event_package.pubkey.cutHex, n.event.event_package.event_body.altitude.to!string, n.event.event_package.fingerprint.cutHex])
            .each!writeln;
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
            writefln("sharp response ingraph:true");
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

        writefln("owner_epacks %s", own_epacks.length);
        if (!changes.empty) {
            // delta received from sharp should be added to our own node. 
            writefln("changes found");
            foreach (epack; changes) {
                const epack_node = getNode(epack.pubkey);
                auto first_event = new Event(epack, this);
                if (epack_node.event is null) {
                    check(first_event.isEva, ConsensusFailCode.GOSSIPNET_FIRST_EVENT_MUST_BE_EVA);
                }
                _event_cache[first_event.fingerprint] = first_event;
                front_seat(first_event);
            }
        }
        writefln("after owner_epacks %s", _nodes.byValue.map!((n) => n[]).joiner.array.length);

        auto result = setDifference!((a, b) => a.fingerprint < b.fingerprint)(own_epacks, received_epacks).array;

        const state = ExchangeState.RIPPLE;
        return Wavefront(result, Tides.init, state);

        // foreach (epack; received_wave.epacks) {
        //     if (getNode(epack.pubkey).event is null) {
        //         writefln("epack time: %s", epack.event_body.time);
        //         auto first_event = new Event(epack, this);
        //         writefln("foreach event %s", first_event.event_package.event_body.time);
        //         check(first_event.isEva, ConsensusFailCode.GOSSIPNET_FIRST_EVENT_MUST_BE_EVA);
        //         _event_cache[first_event.fingerprint] = first_event;
        //         front_seat(first_event);
        //     }
        // }
        // auto result = _nodes.byValue
        //     .filter!((n) => (n._event !is null))
        //     .map!((n) => cast(immutable(EventPackage)*) n._event.event_package)
        //     .array;

        // const contain_all =
        //     _nodes
        //         .byValue
        //         .all!((n) => n._event !is null);

        // const state = (_nodes.length is node_size && contain_all) ? ExchangeState.COHERENT : ExchangeState.RIPPLE;

        // return Wavefront(result, null, state);
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

        if (from_channel.cutHex == "037ba30f467d5de5") {
            writefln("Node: %s received wave: %s from NEWNODE: %s", _owner_node.channel.cutHex, received_wave.state, received_wave.toDoc.toPretty);

        }
        if (_owner_node.channel.cutHex == "037ba30f467d5de5") {
            writefln("NEWNODE received wave: %s from %s, %s", received_wave.state,from_channel.cutHex, received_wave.toDoc.toPretty);
        }
        
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

                case SHARP: ///
                    received_node.state = NONE;
                    received_node.sticky_state = SHARP;
                    writefln("received sharp %s", received_node.channel.cutHex);
                    const sharp_response = sharpResponse(received_wave);
                    return sharp_response;
                case RIPPLE:
                    received_node.state = RIPPLE;
                    received_node.sticky_state = RIPPLE;

                    if (areWeInGraph) {
                        break;
                    }

                    // if we receive a ripplewave, we must add the eva events to our own graph.
                    const received_epacks = received_wave.epacks;
                    foreach (epack; received_epacks) {
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
                        writefln("%s going to init witnesses, areweingraph %s", _owner_node.channel.cutHex, areWeInGraph);
                        initialize_witness(own_epacks);
                    }
                    break;
                case COHERENT:
                    received_node.state = NONE;
                    received_node.sticky_state = COHERENT;
                    writefln("received coherent from: %s, self %s", received_node.channel.cutHex, _owner_node.channel.cutHex);
                    if (!areWeInGraph) {
                        try {
                            received_wave.epacks
                                .map!(epack => epack.event_body)
                                .each!(ebody => ebody.toPretty.writeln);
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

                    if (from_channel.cutHex == "037ba30f467d5de5") {
                        writefln("Node: %s FIRST_WAVE response NEWNODE: %s", _owner_node.channel.cutHex, wave.toDoc.toPretty);
                    }
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
                    // if (joining) {
                    //     immutable(EventPackage)*[] result;
                    //     writefln("owner node id %s nodes length:%s", _owner_node.node_id,_nodes.length);
                    //     assert(_nodes.length == node_size);
                    //     foreach(n; _nodes.byKeyValue) {
                    //         const stored_event_altitude = _rounds.
                    //             last_decided_round
                    //             .events[n.value.node_id]
                    //             .event_package
                    //             .event_body
                    //             .altitude;

                    //         auto to_add = received_wave
                    //             .epacks
                    //             .filter!((epack) => epack !is null && epack.pubkey == n.key && highest(epack.event_body.altitude, stored_event_altitude));
                    //         // to_add.each!writeln;                            
                    //     }
                    //     writefln("AFTER nodes length:%s", _nodes.length);
                    //     return buildWavefront(BREAKING_WAVE);
                    // }

                    
                        
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

version (unittest) {
    import basic = tagion.basic.basic;
    import std.range : dropExactly;
    import tagion.utils.Miscellaneous : cutHex;

    const(basic.FileNames) fileId(T = HashGraph)(string prefix = null) @safe {
        import basic = tagion.basic.basic;

        return basic.fileId!T("hibon", prefix);
    }
}
