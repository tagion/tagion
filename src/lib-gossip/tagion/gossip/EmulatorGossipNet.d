module tagion.gossip.EmulatorGossipNet;

import std.stdio;
import std.concurrency;
import std.format;
import std.array : join;
import std.conv : to;

import tagion.revision;
import tagion.Options;
import tagion.Base : EnumText, Buffer, Pubkey, Payload, buf_idup, convertEnum, consensusCheck, consensusCheckArguments, basename, isBufferType;
import tagion.utils.Miscellaneous: cutHex;
import tagion.utils.Random;
import tagion.utils.LRU;
import tagion.utils.Queue;
//import tagion.Keywords;


import tagion.utils.BSON;
import tagion.gossip.GossipNet;
import tagion.gossip.InterfaceNet;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event;
import tagion.hashgraph.ConsensusExceptions;

import tagion.crypto.secp256k1.NativeSecp256k1;
// alias ReceiveQueue = Queue!(immutable(ubyte[]));
// alias check=consensusCheck!(GossipConsensusException);
// alias consensus=consensusCheckArguments!(GossipConsensusException);

string getname(immutable size_t i) {
    return join([options.nodeprefix, to!string(i)]);
}

string getfilename(string[] names) {
    import std.path;
    return buildPath(options.tmp, setExtension(names.join, options.logext));
}

@trusted
uint getTids(Tid[] tids) {
    uint result=uint.max;
    foreach(i, ref tid ; tids) {
        immutable uint_i=cast(uint)i;
        immutable taskname=getname(uint_i);
        tid=locate(taskname);
        if ( tid == thisTid ) {
            result=uint_i;
        }
    }
    return result;
}

@safe
class EmulatorGossipNet : StdGossipNet {
    version(none)
    void onEvict(const(ubyte[]) key, EventPackageCache.Element* e) @safe {
        //fout.writefln("Evict %s", typeid(e.entry));
    }

    version(none)
    bool online() const  {
        // Does my own node exist and do the node have an event
        auto own_node=_hashgraph.getNode(pubkey);
        return (own_node !is null) && (own_node.event !is null);
        // return _hashgraph.isNodeActive(0) && (_hashgraph.getNode(0).isOnline);
    }

    version(node) {
        private ReceiveQueue _queue;
        bool queue_empty() {
            return _queue.empty;
        }

        immutable(ubyte[]) queue_read() {
            return _queue.read;
        }
    }

    private Tid[immutable(Pubkey)] _tids;
    private immutable(Pubkey)[] _pkeys;
    version(none)
    debug {
        protected string _node_name;
        @property void node_name(string name)
            in {
                assert(_node_name is null, format("%s is already set", __FUNCTION__));
            }
        do {
            _node_name=name;
        }

        @property string node_name() pure const nothrow {
            return _node_name;
        }
    }
    protected uint _send_node_id;
//    protected ulong _current_time;
//    protected HashGraph _hashgraph;

    version(none) {
    protected Tid _transcript_tid;
    @property void transcript_tid(Tid tid)
    @trusted in {
        assert(_transcript_tid != _transcript_tid.init, format("%s hash already been set", __FUNCTION__));
    }
    do {
        _transcript_tid=tid;
    }

    @property Tid transcript_tid() pure nothrow {
        return _transcript_tid;
    }

    protected Tid _scripting_engine_tid;
    @property void scripting_engine_tid(Tid tid) @trusted in {
        assert(_scripting_engine_tid != _scripting_engine_tid.init, format("%s hash already been set", __FUNCTION__));
    }
    do {
        _scripting_engine_tid=tid;
    }

    @property Tid scripting_engine_tid() pure nothrow {
        return _scripting_engine_tid;
    }
    }
    version(none)
    static bool isNetMajority(const(uint) voting, const(uint) nodes) pure nothrow {
        return voting*3 > nodes*2;
    }

    Random!uint random;

    this(NativeSecp256k1 crypt, HashGraph hashgraph) {
        //_hashgraph=hashgraph;
        //_queue=new ReceiveQueue;
//        _event_package_cache=new EventPackageCache(&onEvict);
        super(crypt, hashgraph);
    }

    version(none)
    this(HashGraph hashgraph) {
        _hashgraph=hashgraph;
        _queue=new ReceiveQueue;
        _event_package_cache=new EventPackageCache(&onEvict);
        import tagion.crypto.secp256k1.NativeSecp256k1;
        super(new NativeSecp256k1());
    }

//    void set(ref Tid[] tids, immutable(Pubkey)[] pkeys)
    void set(immutable(Pubkey)[] pkeys)
        in {
            assert(_tids is null);
            // assert(tids.length == pkeys.length);
        }
    do {
        _pkeys=pkeys;
        auto tids=new Tid[pkeys.length];
        getTids(tids);
        foreach(i, p; pkeys) {
            _tids[p]=tids[cast(uint)i];
        }
    }

    immutable(Pubkey) selectRandomNode(const bool active=true) {
        immutable N=cast(uint)_tids.length;
        uint node_index;
        do {
            node_index=random.value(1, N);
        } while (_pkeys[node_index] == pubkey);
        return _pkeys[node_index];
    }


    void dump(const(HBSON[]) events) const {
        foreach(e; events) {
            auto pack_doc=Document(e.serialize);
            auto pack=EventPackage(pack_doc);
            immutable fingerprint=calcHash(pack.event_body.serialize);
            fout.writefln("\tsending %s f=%s a=%d", pack.pubkey.cutHex, fingerprint.cutHex, pack.event_body.altitude);
        }
    }

    version(none)
    static void dump(const(Tides) tides) {
        foreach(pkey, alt; tides) {
            fout.writefln("tide[%s]=%d", pkey.cutHex, alt);
        }
    }


    version(none)
    static NetCallbacks callbacks() {
        return (cast(NetCallbacks)Event.callbacks);
        // return Event.callbacks;
    }


    @trusted
    override void trace(string type, immutable(ubyte[]) data) {
        debug {
            if ( options.trace_gossip ) {
                import std.file;
                immutable packfile=format("%s/%s_%d_%s.bson", options.tmp, node_name, _send_count, type); //.to!string~"_receive.bson";
                write(packfile, data);
                _send_count++;
            }
        }
    }

    version(none)
    override Event receive(immutable(ubyte[]) data,
        Event delegate(immutable(ubyte)[] father_fingerprint) @safe register_leading_event ) {
        trace("receive", data);
        if ( callbacks ) {
            callbacks.receive(data);
        }

        Event result;
        auto doc=Document(data);
        Pubkey received_pubkey=doc[Keywords.pubkey].get!(immutable(ubyte)[]);
        fout.writefln("Receive %s data=%d", received_pubkey.cutHex, data.length);

        check(received_pubkey != pubkey, ConsensusFailCode.GOSSIPNET_REPLICATED_PUBKEY);

        immutable type=doc[Keywords.type].get!uint;
        immutable received_state=convertState(type);
        // This indicates when a communication sequency ends
        bool end_of_sequence=false;

        // This repesents the current state of the local node
        auto received_node=_hashgraph.getNode(received_pubkey);
        //auto _node=_hashgraph.getNode(pubkey);
        if ( !online ) {
            // Queue the package if we still are busy
            // with the current package
            _queue.write(data);
        }
        else {
            auto signature=doc[Keywords.signature].get!(immutable(ubyte)[]);
            auto block=doc[Keywords.block].get!Document;
            immutable message=calcHash(block.data);
            if ( verify(message, signature, received_pubkey) ) {
                if ( callbacks ) {
                    callbacks.wavefront_state_receive(received_node);
                }
                with(ExchangeState) final switch (received_state) {
                    case NON:
                    case INIT_TIDE:
                        consensus(received_state).check(false, ConsensusFailCode.GOSSIPNET_ILLEGAL_EXCHANGE_STATE);
                        break;
                    case TIDE_WAVE:
                        // Receive the tide wave
                        consensus(received_node.state, INIT_TIDE, NON).
                            check((received_node.state == INIT_TIDE) || (received_node.state == NON),  ConsensusFailCode.GOSSIPNET_EXPECTED_OR_EXCHANGE_STATE);
                        Tides tides;
                        immutable father_fingerprint=waveFront(received_pubkey, block, tides);
                        // dump(tides);
                        assert(father_fingerprint is null); // This should be an exception
                        result=register_leading_event(null);
                        HBSON[] events=buildWavefront(tides, true);
                        check(events.length > 0, ConsensusFailCode.GOSSIPNET_MISSING_EVENTS);

                        // Add the new leading event
                        auto wavefront=new HBSON;
                        wavefront[Keywords.wavefront]=events;
                        // If the this node already have INIT and tide the a braking wave is send
                        auto exchange=(received_node.state == INIT_TIDE)?BREAK_WAVE:FIRST_WAVE;
                        auto wavefront_pack=buildEvent(wavefront, exchange);

                        send(received_pubkey, wavefront_pack);
                        received_node.state=received_state;
                        break;
                    case FIRST_WAVE:
                    case BREAK_WAVE:
                        // consensus(INIT_TIDE, received_node.state).check(received_node.state == INIT_TIDE,  ConsensusFailCode.GOSSIPNET_EXPECTED_EXCHANGE_STATE);
                        consensus(received_node.state, INIT_TIDE, TIDE_WAVE).
                            check((received_node.state == INIT_TIDE) || (received_node.state == TIDE_WAVE),  ConsensusFailCode.GOSSIPNET_EXPECTED_OR_EXCHANGE_STATE);

                        Tides tides;
                        immutable father_fingerprint=waveFront(received_pubkey, block, tides);
                        // dump(tides);
                        result=register_leading_event(father_fingerprint);
                        immutable send_second_wave=(received_state == FIRST_WAVE);
                        if ( send_second_wave ) {
                            assert(result !is null);
                            assert(result is _hashgraph.getNode(pubkey).event);
                            HBSON[] events=buildWavefront(tides, true);
                            auto wavefront=new HBSON;
                            wavefront[Keywords.wavefront]=events;

                            // Receive the tide wave and return the wave front
                            auto wavefront_pack=buildEvent(wavefront, SECOND_WAVE);
                            send(received_pubkey, wavefront_pack);
                        }
                        end_of_sequence=true;
                        received_node.state=NON;
                        break;
                    case SECOND_WAVE:
                        consensus(received_node.state, TIDE_WAVE).check( received_node.state == TIDE_WAVE,  ConsensusFailCode.GOSSIPNET_EXPECTED_EXCHANGE_STATE);
                        Tides tides;

                        immutable father_fingerprint=waveFront(received_pubkey, block, tides);
                        result=register_leading_event(father_fingerprint);
                        received_node.state=NON;
                        end_of_sequence=true;
                    }

            }
        }
        if ( !_queue.empty && online ) {

            if ( end_of_sequence ) {
                auto d=_queue.read;
                receive(d, register_leading_event);
            }
        }
        return result;
    }



    protected uint _send_count;
    @trusted
    void send(immutable(Pubkey) channel, immutable(ubyte[]) data) {
        auto doc=Document(data);
        auto doc_body=doc[Params.block].get!Document;
        if ( doc_body.hasElement(Event.Params.ebody) ) {
            auto doc_ebody=doc_body[Event.Params.ebody].get!Document;
            auto event_body=immutable(EventBody)(doc_ebody);
        }
        trace("send", data);
        if ( callbacks ) {
            callbacks.send(channel, data);
        }
        fout.writefln("Send %s data=%d", channel.cutHex, data.length);
        _tids[channel].send(data);
    }


    void send(immutable(Pubkey) channel, ref const(Package) pack) {
        send(channel, pack.serialize);
    }

    version(none)
    override void request(HashGraph hashgraph, immutable(ubyte[]) fingerprint) {
        if ( !_hashgraph.isRegistered(fingerprint) ) {
            immutable has_new_event=(fingerprint !is null);
            if ( has_new_event ) {
                EventPackage epack=_event_package_cache[fingerprint];
                _event_package_cache.remove(fingerprint);
                auto event=_hashgraph.registerEvent(this, epack.pubkey, epack.signature,  epack.event_body);
            }
        }
    }


    version(none)
    struct EventPackage {
        immutable(ubyte[]) signature;
        immutable(Pubkey) pubkey;
        immutable(EventBody) event_body;
        this(Document doc) {
            signature=(doc[Keywords.signature].get!(immutable(ubyte[]))).idup;
            pubkey=buf_idup!Pubkey(doc[Keywords.pubkey].get!Buffer);
//            pubkey=(doc[Keywords.pubkey].get!Buffer);
            auto doc_ebody=doc[Keywords.ebody].get!Document;
            event_body=immutable(EventBody)(doc_ebody);
        }
        static EventPackage undefined() {
            check(false, ConsensusFailCode.GOSSIPNET_EVENTPACKAGE_NOT_FOUND);
            assert(0);
        }
    }


    version(none)
    const(Package) buildPackage(const(HBSON) block, ExchangeState type) {
        return Package(this, block, type);
    }

    version(none)
    struct Package {
        private GossipNet net;
        private const(HBSON) block;
        private Pubkey pubkey;
        immutable ExchangeState type;
        immutable(ubyte[]) signature;

        this(GossipNet net, const(HBSON) block,  ExchangeState type) {
            this.net=net;
            this.block=block;
            this.type=type;
            this.pubkey=net.pubkey;
            immutable data=block.serialize;
            immutable message=net.calcHash(data);
            signature=net.sign(message);
        }

        HBSON toBSON() inout {
            auto bson=new HBSON;
            foreach(i, m; this.tupleof) {
                enum name=basename!(this.tupleof[i]);
                alias typeof(m) mtype;
                static if ( (name != basename!net) ) {
                    static if ( __traits(compiles, m.toBSON) ) {
                        bson[name]=m.toBSON;
                    }
                    else {
                        static if ( is(mtype == enum) ) {
                            bson[name]=cast(uint)m;
                        }
                        else static if ( isBufferType!mtype ) {
                            bson[name]=cast(Buffer)m;
                        }
                        else {
                            bson[name]=m;
                        }
                    }
                }
            }
            return bson;
        }

        immutable(ubyte[]) serialize() const {
            return toBSON.serialize;
        }

        unittest { // Sign and verify
            immutable passphrase="Very secret passphrase";
            auto net=new EmulatorGossipNet(null);
            net.generateKeyPair(passphrase);

            // Create test block
            auto send_block=new HBSON;
            send_block["hugh"]="Some data";
            send_block["age"]=42;
            send_block["height"]=155.7;

            auto pack=Package(net, send_block, ExchangeState.TIDE_WAVE);
            // Data package send
            auto send_pack=pack.serialize;

            // Received package
            auto receive_pack=Document(send_pack);

            auto signature=receive_pack[Keywords.signature].get!(immutable(ubyte)[]);
            auto receive_block=receive_pack[Keywords.block].get!Document;

            immutable message=net.calcHash(receive_block.data);
            assert(net.verify(message, signature, net.pubkey));

            assert(receive_pack.hasElement(Keywords.pubkey));
            assert(net.verify(message, signature, cast(Pubkey)(receive_pack[Keywords.pubkey].get!(Buffer))));

        }

    }

    /* to synchronize two nodes A and B
       1)
       Node A send it's wave front to B
       This is done via the waveFront function
       2)
       B collects all the events it has which is are in front of the
       wave front of A.
       This is done via the waveFront function
       B send the all the collected event to B including B's wave font of all
       the node which B know it leads in,
       The wave from is collect via the waveFront function by adding the remaining tides
       3)
       A send the rest of the event which is in front of B's wave-front

    */
    version(none)
    Tides tideWave(HBSON bson, bool build_tides) {
        HBSON[] fronts;
        Tides tides;
        foreach(n; _hashgraph.nodeiterator) {
            if ( n.isOnline ) {
                auto node=new HBSON;
                node[Keywords.pubkey]=n.pubkey;
                node[Keywords.altitude]=n.altitude;
                fronts~=node;
                if ( build_tides ) {
                    tides[n.pubkey] = n.altitude;
                }
            }
        }
        bson[Keywords.tidewave]=fronts;
        return tides;
    }

    // This function collects the tide wave
    // Between the current Hashgraph and the wave-front
    // Returns the top most event on node received_pubkey
    version(none)
    immutable(ubyte[]) waveFront(Pubkey received_pubkey, Document doc, ref Tides tides) {
        immutable(ubyte)[] result;
        int result_altitude;
        immutable is_tidewave=doc.hasElement(Keywords.tidewave);
        scope(success) {
            if ( callbacks ) {
                callbacks.received_tidewave(received_pubkey, tides);
            }
        }
        if ( is_tidewave ) {
            auto tidewave=doc[Keywords.tidewave].get!Document;
            foreach(pack; tidewave) {
                auto pack_doc=pack.get!Document;
                immutable _pkey=cast(Pubkey)(pack_doc[Keywords.pubkey].get!(immutable(Buffer)));
                immutable altitude=pack_doc[Keywords.altitude].get!int;
                tides[_pkey]=altitude;
            }
        }
        else {
            auto wavefront=doc[Keywords.wavefront].get!Document;
            foreach(pack; wavefront) {
                auto pack_doc=pack.get!Document;

                // Create event package and cache it
                auto event_package=EventPackage(pack_doc);
                // The message is the hashpointer to the event body
                immutable fingerprint=calcHash(event_package.event_body.serialize);
                if ( !_hashgraph.isRegistered(fingerprint) && !_event_package_cache.contains(fingerprint)) {
                    check(verify(fingerprint, event_package.signature, event_package.pubkey), ConsensusFailCode.EVENT_SIGNATURE_BAD);

                    _event_package_cache[fingerprint]=event_package;
                }

                // Altitude
                auto altitude_p=event_package.pubkey in tides;
                if ( altitude_p ) {
                    immutable altitude=*altitude_p;
                    tides[event_package.pubkey]=highest(altitude, event_package.event_body.altitude);
                }
                else {
                    tides[event_package.pubkey]=event_package.event_body.altitude;
                }
                if ( received_pubkey == event_package.pubkey  ) {
                    if ( (result is null) ||  lower(result_altitude, event_package.event_body.altitude) ) {
                        result_altitude = event_package.event_body.altitude;
                        result=fingerprint;
                    }
                }
                _hashgraph.setAltitude(event_package.pubkey, event_package.event_body.altitude);
            }
        }
        return result;
    }


    version(none)
    HBSON[] buildWavefront(Tides tides, bool is_tidewave) {
        HBSON[] events;
        foreach(i_n, n; _hashgraph.nodeiterator) {
            auto other_altitude_p=n.pubkey in tides;
            if ( other_altitude_p ) {
                immutable other_altitude=*other_altitude_p;
                foreach(e; n) {
                    if ( higher( other_altitude, e.altitude) ) {
                        break;
                    }
                    events~=e.toBSON;
                }
            }
            else if ( is_tidewave ) {
                foreach(e; n) {
                    events~=e.toBSON;
                }
            }
        }
        return events;
    }

    private uint eva_count;

    Payload evaPackage() {
        eva_count++;
        auto bson=new HBSON;
        bson["pubkey"]=pubkey;
        bson["git"]=HASH;
        bson["nonce"]="Should be implemented:"~to!string(eva_count);
        return Payload(bson.serialize);
    }

}
