module tagion.gossip.GossipNet;

import std.concurrency;
import std.stdio : File;
import std.format;
import std.exception : assumeUnique;
import std.string : representation;
import core.time : MonoTime;

import tagion.Options;
import tagion.basic.Basic : EnumText, Pubkey, Buffer, buf_idup, basename;
import tagion.basic.ConsensusExceptions : convertEnum;
//, consensusCheck, consensusCheckArguments;
import tagion.utils.Miscellaneous: cutHex;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord : HiBONPrefix;


import tagion.utils.LRU;
import tagion.utils.Queue;

import tagion.gossip.InterfaceNet;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event;
import tagion.basic.ConsensusExceptions;


import tagion.crypto.aes.AESCrypto;
//import tagion.crypto.secp256k1.NativeSecp256k1;

import tagion.basic.Logger;

void scramble(scope ref ubyte[] data, scope ubyte[] xor=null) @safe {
    import std.random;
    auto gen = Mt19937(unpredictableSeed);
    foreach(ref s; data) { //, gen1, StoppingPolicy.shortest)) {
        s=gen.front & ubyte.max;
        gen.popFront;
    }
    foreach(i, x; xor) {
        data[i]^=x;
    }
}

@safe
class StdHashNet : HashNet {
    protected enum HASH_SIZE=32;
    final uint hashSize() const pure nothrow {
        return HASH_SIZE;
    }

    final immutable(Buffer) calcHash(scope const(ubyte[]) data) const {
        import std.digest.sha : SHA256;
        import std.digest;
        return digest!SHA256(data).idup;
    }

    @trusted
    final immutable(Buffer) HMAC(scope const(ubyte[]) data) const {
        import std.exception : assumeUnique;
        import std.digest.sha : SHA256;
        import std.digest.hmac : digestHMAC=HMAC;
        scope hmac = digestHMAC!SHA256(data);
        auto result = hmac.finish.dup;
        pragma(msg, typeof(result));
        return assumeUnique(result);
    }

    immutable(Buffer) hashOf(scope const(ubyte[]) h1, scope const(ubyte[]) h2) const {
        return calcHash(h1~h2);
    }

    immutable(Buffer) hashOf(const(Document) doc) const {
        auto range=doc[];
        if (!range.empty && (range.front.key[0] is HiBONPrefix.HASH)) {
            pragma(msg, "FIXME(cbr): not working with integers");
            immutable value_data=range.front.data[range.front.dataPos..range.front.dataPos + range.front.dataSize];
            return calcHash(value_data);
        }
        return calcHash(doc.serialize);
    }
}

// @safe
// class StdHashNet : HashNet {
//     mixin StdHashNetT;
// }


alias check = consensusCheck!(GossipConsensusException);
alias consensus = consensusCheckArguments!(GossipConsensusException);

@safe
class StdSecureNet : StdHashNet, SecureNet  {
//    immutable(Buffer) calcHash(scope const(ubyte[]) data) const;

//    mixin StdHashNetT;
    import tagion.crypto.secp256k1.NativeSecp256k1;
    import tagion.basic.Basic : Pubkey;
    import tagion.crypto.aes.AESCrypto;
    import tagion.gossip.GossipNet : scramble;
//    import tagion.gossip.InterfaceNet : HashNet;
    import tagion.basic.ConsensusExceptions;

    alias check = consensusCheck!(GossipConsensusException);

    import std.format;
    import std.string : representation;


    private Pubkey _pubkey;
    /**
       This function
       returns
       If method is SIGN the signed message or
       If method is DRIVE it returns the drived privat key
     */
    @safe
    interface SecretMethods {
        immutable(ubyte[]) sign(immutable(ubyte[]) message) const;
        void tweakMul(const(ubyte[]) tweek_code, ref ubyte[] tweak_privkey);
        void tweakAdd(const(ubyte[]) tweek_code, ref ubyte[] tweak_privkey);
        Buffer mask(const(ubyte[]) _mask) const;
    }

    protected SecretMethods _secret;

    final Pubkey pubkey() pure const nothrow {
        return _pubkey;
    }

    final Buffer hmacPubkey() const {
        return HMAC(cast(Buffer)_pubkey);
    }

    final Pubkey drivePubkey(string tweak_word) const {
        const tweak_code=HMAC(tweak_word.representation);
        return drivePubkey(tweak_code);
    }

    final Pubkey drivePubkey(const(ubyte[]) tweak_code) const {
        Pubkey result;
        const pkey=cast(const(ubyte[]))_pubkey;
        result=_crypt.pubKeyTweakMul(pkey, tweak_code);
        return result;
    }

    final bool verify(T)(T pack, immutable(ubyte)[] signature, Pubkey pubkey) const if ( __traits(compiles, pack.serialize) ) {
        auto message=calcHash(pack.serialize);
        return verify(message, signature, pubkey);
    }

    protected NativeSecp256k1 _crypt;
    final bool verify(immutable(ubyte[]) message, immutable(ubyte)[] signature, Pubkey pubkey) const {
        consensusCheck!(SecurityConsensusException)(signature.length != 0 && signature.length <= 520,
            ConsensusFailCode.SECURITY_SIGNATURE_SIZE_FAULT);
        return _crypt.verify(message, signature, cast(Buffer)pubkey);
    }

    final immutable(ubyte[]) sign(T)(T pack) const if ( __traits(compiles, pack.serialize) ) {
        auto message=calcHash(pack.serialize);
        auto result=sign(message);
        return result;
    }

    final immutable(ubyte[]) sign(immutable(ubyte[]) message) const
    in {
        assert(_secret !is null, format("Signature function has not been intialized. Use the %s function", basename!generatePrivKey));
        assert(message.length == 32);
    }
    do {
        import std.traits;
        assert(_secret !is null, format("Signature function has not been intialized. Use the %s function", fullyQualifiedName!generateKeyPair));

        return _secret.sign(message);
    }

    void drive(string tweak_word, ref ubyte[] tweak_privkey) {
        const data = HMAC(tweak_word.representation);
        drive(data, tweak_privkey);
    }

    void drive(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey)
        in {
            assert(tweak_privkey.length >= 32);
        }
    do {
        _secret.tweakMul(tweak_code, tweak_privkey);
    }

    final Buffer mask(const(ubyte[]) _mask) const {
        return _secret.mask(_mask);
    }

    @trusted
    void drive(string tweak_word, shared(SecureNet) secure_net) {
        const tweak_code=HMAC(tweak_word.representation);
        drive(tweak_code, secure_net);
    }

    @trusted
    void drive(const(ubyte[]) tweak_code, shared(SecureNet) secure_net)
        in {
            assert(_secret);
        }
    do {
        synchronized(secure_net) {
            ubyte[] tweak_privkey = tweak_code.dup;
            auto unshared_secure_net = cast(SecureNet)secure_net;
            unshared_secure_net.drive(tweak_code, tweak_privkey);
            createKeyPair(tweak_privkey);
        }
    }

    final void createKeyPair(ref ubyte[] privkey)
        in {
            assert(_crypt.secKeyVerify(privkey));
            assert(_secret is null);
        }
    do {
        import std.digest.sha : SHA256;
        import std.string : representation;
        alias AES=AESCrypto!256;
        _pubkey = _crypt.computePubkey(privkey);
        // Generate scramble key for the private key
        import std.random;

        auto seed=new ubyte[32];

        scramble(seed);
        // CBR: Note AES need to be change to beable to handle const keys
        auto aes_key=calcHash(seed).dup;

        scramble(seed);

        // Encrypt private key
        auto encrypted_privkey=new ubyte[privkey.length];
        AES.encrypt(aes_key, privkey, encrypted_privkey);

        AES.encrypt(calcHash(seed), encrypted_privkey, privkey);
        scramble(seed);

        AES.encrypt(aes_key, encrypted_privkey, privkey);

        AES.encrypt(aes_key, privkey, seed);

        AES.encrypt(aes_key, encrypted_privkey, privkey);

        @safe
        void do_secret_stuff(scope void delegate(const(ubyte[]) privkey) @safe dg) {
            // CBR:
            // Yes I know it is security by obscurity
            // But just don't want to have the private in clear text in memory
            // for long period of time
            auto privkey=new ubyte[encrypted_privkey.length];
            scope(exit) {
                auto seed=new ubyte[32];
                scramble(seed, aes_key);
                AES.encrypt(aes_key, privkey, encrypted_privkey);
                AES.encrypt(calcHash(seed), encrypted_privkey, privkey);
            }
            AES.decrypt(aes_key, encrypted_privkey, privkey);
            dg(privkey);
        }

        @safe class LocalSecret : SecretMethods {
            immutable(ubyte[]) sign(immutable(ubyte[]) message) const {
                immutable(ubyte)[] result;
                do_secret_stuff((const(ubyte[]) privkey) {
                        result = _crypt.sign(message, privkey);
                    });
                return result;
            }
            void tweakMul(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey) {
                do_secret_stuff((const(ubyte[]) privkey) @safe {
                        // scope hmac = HMAC!SHA256(tweek_code.representation);
                        // auto data = hmac.finish.dup;
                        _crypt.privKeyTweakMul(privkey, tweak_code, tweak_privkey);
                    });
            }
            void tweakAdd(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey) {
                do_secret_stuff((const(ubyte[]) privkey) @safe {
                        // scope hmac = HMAC!SHA256(tweek_code.representation);
                        // auto data = hmac.finish.dup;
                        _crypt.privKeyTweakAdd(privkey, tweak_code, tweak_privkey);
                    });
            }
            Buffer mask(const(ubyte[]) _mask) const {
                import std.algorithm.iteration : sum;
                check(sum(_mask) != 0, ConsensusFailCode.SECURITY_MASK_VECTOR_IS_ZERO);
                Buffer result;
                do_secret_stuff((const(ubyte[]) privkey) @safe {
                        import tagion.utils.Miscellaneous : xor;
                        auto data = xor(privkey, _mask);
                        result=calcHash(calcHash(data));
                    });
                return result;
            }
        }
        _secret = new LocalSecret;
    }

    final void generateKeyPair(string passphrase)
        in {
            assert(_secret is null);
        }
    do {
        import std.digest.sha : SHA256;
        import std.digest.hmac : digestHMAC=HMAC;
        import std.string : representation;
        alias AES=AESCrypto!256;

        scope hmac = digestHMAC!SHA256(passphrase.representation);
        auto data = hmac.finish.dup;

        // Generate Key pair
        do {
            data = hmac.put(data).finish.dup;
        } while (!_crypt.secKeyVerify(data));

        createKeyPair(data);
    }

    this() {
        this._crypt = new NativeSecp256k1;
    }
}

@safe
abstract class StdGossipNet : StdSecureNet, GossipNet { //GossipNet {
//    static File fout;
    static private shared uint _next_global_id;
    static private shared uint[immutable(Pubkey)] _node_id_pair;

    uint globalNodeId(immutable(Pubkey) channel) {
        if ( channel in _node_id_pair ) {
            return _node_id_pair[channel];
        }
        else {
            return setGlobalNodeId(channel);
        }
    }

    @trusted
    static private uint setGlobalNodeId(immutable(Pubkey) channel) {
        import core.atomic;
        auto result = _next_global_id;
        _node_id_pair[channel] = _next_global_id;
        atomicOp!"+="(_next_global_id, 1);
        return result;
    }

    import tagion.hashgraph.Event : Event;
    this( HashGraph hashgraph) {
//        _transceiver=transceiver;
        _hashgraph=hashgraph;
        _queue=new ReceiveQueue;
        _event_package_cache=new EventPackageCache(&onEvict);
//        import tagion.crypto.secp256k1.NativeSecp256k1;
        super();
    }

    protected enum _params = [
        "type",
        "tidewave",
        "wavefront",
        "block"
        ];

    mixin(EnumText!("Params", _params));

    protected enum _gossip = [
        "waveFront",
        "tideWave",
        ];

    mixin(EnumText!("Gossips", _gossip));

    override NetCallbacks callbacks() {
        return (cast(NetCallbacks)Event.callbacks);
        // return Event.callbacks;
    }

    static struct Init {
        uint timeout;
        uint node_id;
        uint N;
        string monitor_ip_address;
        ushort monitor_port;
        uint seed;
        string node_name;
    }

    const(Package) buildEvent(const(HiBON) block, ExchangeState type) {
        return Package(this, block, type);
    }

    void onEvict(scope const(ubyte[]) key, EventPackageCache.Element* e) nothrow @safe {
        //fout.writefln("Evict %s", typeid(e.entry));
    }

    bool online() const  {
        // Does my own node exist and do the node have an event
        auto own_node=_hashgraph.getNode(pubkey);
        log("own node exists: %s, own node event exists: %s", own_node !is null, own_node.event !is null);
        return (own_node !is null) && (own_node.event !is null);
        // return _hashgraph.isNodeActive(0) && (_hashgraph.getNode(0).isOnline);
    }

    private ReceiveQueue _queue;
    @property
    ReceiveQueue queue() {
        return _queue;
    }

    alias EventPackageCache=LRU!(const(ubyte[]), EventPackage);
    protected EventPackageCache _event_package_cache;

    protected ulong _current_time;
    protected HashGraph _hashgraph;

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

    static struct EventPackage {
        immutable(ubyte[]) signature;
        immutable(Pubkey) pubkey;
        immutable(EventBody) event_body;
        this(Document doc) {
            signature=(doc[Event.Params.signature].get!(Buffer)).idup;
            pubkey=buf_idup!Pubkey(doc[Event.Params.pubkey].get!Buffer);
            auto doc_ebody=doc[Event.Params.ebody].get!Document;
            event_body=immutable(EventBody)(doc_ebody);
        }
        static EventPackage undefined() {
            check(false, ConsensusFailCode.GOSSIPNET_EVENTPACKAGE_NOT_FOUND);
            assert(0);
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
    Tides tideWave(HiBON hibon, bool build_tides) {
        HiBON[] fronts;
        Tides tides;
        pragma(msg, typeof(_hashgraph[].front));
        foreach(n; _hashgraph[]) {
            pragma(msg, typeof(n));
            if ( n.isOnline ) {
                auto node=new HiBON;
                node[Event.Params.pubkey]=n.pubkey;
                node[Event.Params.altitude]=n.altitude;
                fronts~=node;
                if ( build_tides ) {
                    tides[n.pubkey] = n.altitude;
                }
            }
        }
        hibon[Params.tidewave] = fronts;
        return tides;
    }


    /++
     This function collects the tide wave
     Between the current Hashgraph and the wave-front
     Returns the top most event on node received_pubkey
     +/
    immutable(ubyte[]) waveFront(Pubkey received_pubkey, Document doc, ref Tides tides) {
        immutable(ubyte)[] result;
        int result_altitude;
        immutable is_tidewave=doc.hasElement(Params.tidewave);
        scope(success) {
            if ( callbacks ) {
                callbacks.received_tidewave(received_pubkey, tides);
            }
        }
        if ( is_tidewave ) {
            auto tidewave=doc[Params.tidewave].get!Document;
            foreach(pack; tidewave) {
                auto pack_doc=pack.get!Document;
                immutable _pkey=cast(Pubkey)(pack_doc[Event.Params.pubkey].get!(Buffer));
                immutable altitude=pack_doc[Event.Params.altitude].get!int;
                tides[_pkey]=altitude;
            }
        }
        else {
            auto wavefront=doc[Params.wavefront].get!Document;
            import tagion.hibon.HiBONJSON;
            // log("wavefront: \n%s\n", wavefront.toJSON);
            foreach(pack; wavefront) {
                auto pack_doc=pack.get!Document;

                // Create event package and cache it
                auto event_package=EventPackage(pack_doc);
                // The message is the hashpointer to the event body
                immutable fingerprint=calcHash(event_package.event_body.serialize);
                if ( !_hashgraph.isRegistered(fingerprint) && !_event_package_cache.contains(fingerprint)) {
                    check(verify(fingerprint, event_package.signature, event_package.pubkey), ConsensusFailCode.EVENT_SIGNATURE_BAD);
//                    log("add event_package %s", fingerprint.cutHex);
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

    HiBON[] buildWavefront(Tides tides, bool is_tidewave) const {
        HiBON[] events;
        foreach(n; _hashgraph[]) {
            auto other_altitude_p=n.pubkey in tides;
            if ( other_altitude_p ) {
                immutable other_altitude=*other_altitude_p;
                foreach(e; n[]) {
                    if ( higher( other_altitude, e.altitude) ) {
                        break;
                    }
                    events~=e.toHiBON;
                }
            }
            else if ( is_tidewave ) {
                foreach(e; n) {
                    events~=e.toHiBON;
                }
            }
        }
        return events;
    }


    alias convertState=convertEnum!(ExchangeState, GossipConsensusException);

    @trusted
    void trace(string type, immutable(ubyte[]) data);

    override Event receive(immutable(ubyte[]) data,
        Event delegate(immutable(ubyte)[] father_fingerprint) @safe register_leading_event ) {
        // trace("receive", data);
        // log("RECEIVE #@#@#@#");
        if ( callbacks ) {
            callbacks.receive(data);
        }

        Event result;
        auto doc=Document(data);
        Pubkey received_pubkey=doc[Event.Params.pubkey].get!(immutable(ubyte)[]);
        check(received_pubkey != pubkey, ConsensusFailCode.GOSSIPNET_REPLICATED_PUBKEY);

        immutable type=doc[Params.type].get!uint;
        immutable received_state=convertState(type);
        // log("Receive %s %s data=%d", received_state, received_pubkey.cutHex, data.length);
        // import tagion.hibon.HiBONJSON;
        // log("%s", doc.toJSON);
        // This indicates when a communication sequency ends
        bool end_of_sequence=false;

        // This repesents the current state of the local node
        // log("Get node: %s", received_pubkey.cutHex);
        auto received_node=_hashgraph.getNode(received_pubkey);
        //auto _node=_hashgraph.getNode(pubkey);
        if ( !online ) {
            log("online: %s", online);
            // Queue the package if we still are busy
            // with the current package
            _queue.write(data);
        }
        else {
            auto signature=doc[Event.Params.signature].get!(immutable(ubyte)[]);
            auto block=doc[Params.block].get!Document;
            immutable message=calcHash(block.data);
            if ( verify(message, signature, received_pubkey) ) {
                if ( callbacks ) {
                    callbacks.wavefront_state_receive(received_node);
                }
                with(ExchangeState) final switch (received_state) {
                    case NONE:
                    case INIT_TIDE:
                        consensus(received_state).check(false, ConsensusFailCode.GOSSIPNET_ILLEGAL_EXCHANGE_STATE);
                        break;
                    case TIDAL_WAVE:
                        // Receive the tide wave
                        consensus(received_node.state, INIT_TIDE, NONE).
                            check((received_node.state == INIT_TIDE) || (received_node.state == NONE),  ConsensusFailCode.GOSSIPNET_EXPECTED_OR_EXCHANGE_STATE);
                        Tides tides;
                        immutable father_fingerprint=waveFront(received_pubkey, block, tides);
                        // dump(tides);
                        assert(father_fingerprint is null); // This should be an exception
                        result=register_leading_event(null);
                        HiBON[] events=buildWavefront(tides, true);
                        check(events.length > 0, ConsensusFailCode.GOSSIPNET_MISSING_EVENTS);

                        // Add the new leading event
                        auto wavefront=new HiBON;
                        wavefront[Params.wavefront]=events;
                        // If the this node already have INIT and tide a braking wave is send
                        const exchange=(received_node.state is INIT_TIDE)?BREAKING_WAVE:FIRST_WAVE;
                        auto wavefront_pack=buildEvent(wavefront, exchange);
                        send(received_pubkey, wavefront_pack.serialize);

                        received_node.state=/*exchange == BREAKING_WAVE? INIT_TIDE :*/ received_state;
                        break;
                    case FIRST_WAVE:
                    case BREAKING_WAVE:
                        // consensus(INIT_TIDE, received_node.state).check(received_node.state == INIT_TIDE,  ConsensusFailCode.GOSSIPNET_EXPECTED_EXCHANGE_STATE);
                        consensus(received_node.state, INIT_TIDE, TIDAL_WAVE).
                            check((received_node.state is INIT_TIDE) || (received_node.state is TIDAL_WAVE),  ConsensusFailCode.GOSSIPNET_EXPECTED_OR_EXCHANGE_STATE);

                        Tides tides;
                        immutable father_fingerprint=waveFront(received_pubkey, block, tides);
                        // dump(tides);
                        result=register_leading_event(father_fingerprint);
                        immutable send_second_wave=(received_state == FIRST_WAVE);
                        if ( send_second_wave ) {
                            assert(result !is null);
                            assert(result is _hashgraph.getNode(pubkey).event);
                            HiBON[] events=buildWavefront(tides, true);
                            auto wavefront=new HiBON;
                            wavefront[Params.wavefront]=events;

                            // Receive the tide wave and return the wave front
                            auto wavefront_pack=buildEvent(wavefront, SECOND_WAVE);
                            send(received_pubkey, wavefront_pack.serialize);
                        }
                        end_of_sequence=true;
                        received_node.state=NONE;
                        break;
                    case SECOND_WAVE:
                        consensus(received_node.state, TIDAL_WAVE).check( received_node.state is TIDAL_WAVE,
                            ConsensusFailCode.GOSSIPNET_EXPECTED_EXCHANGE_STATE);
                        Tides tides;

                        // log("calc father fp");
                        immutable father_fingerprint=waveFront(received_pubkey, block, tides);
                        // log("calculeted father fp");
                        result=register_leading_event(father_fingerprint);
                        // log("registered");
                        received_node.state=NONE;
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


    @property
    void time(const(ulong) t) {
        _current_time=t;
    }

    @property
    const(ulong) time() pure const {
        return _current_time;
    }

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
