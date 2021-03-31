// module tagion.gossip.GossipNet;

// import std.concurrency;
// import std.format;
// import std.exception : assumeUnique;
// import std.string : representation;
// import core.time : MonoTime;

// //import tagion.Options;
// import tagion.basic.Basic : Pubkey;
// //import tagion.basic.ConsensusExceptions : convertEnum;
// //, consensusCheck, consensusCheckArguments;
// //import tagion.utils.Miscellaneous: cutHex;
// //import tagion.hibon.HiBON : HiBON;
// import tagion.hibon.Document : Document;
// //import tagion.hibon.HiBONRecord : HiBONPrefix, STUB, isStub;


// // import tagion.utils.LRU;
// // import tagion.utils.Queue;

// import tagion.crypto.SecureNet : StdSecureNet;
// import tagion.gossip.InterfaceNet;
// import tagion.hashgraph.HashGraph;
// import tagion.hashgraph.Event;
// import tagion.basic.ConsensusExceptions;
// import tagion.hashgraph.HashGraphBasic;

// //import tagion.crypto.aes.AESCrypto;
// //import tagion.crypto.secp256k1.NativeSecp256k1;

// //import tagion.basic.Logger;

// @safe
// abstract class StdGossipNet : StdSecureNet {
//     this() {
//         super();
//     }

//     override NetCallbacks callbacks() {
//         return (cast(NetCallbacks)Event.callbacks);
//     }

//     static struct Init {
//         uint timeout;
//         uint node_id;
//         uint N;
//         string monitor_ip_address;
//         ushort monitor_port;
//         uint seed;
//         string node_name;
//     }

//     protected {
//         ulong _current_time;
// //        HashGraphI _hashgraph;
//     }

//     override void receive(const(Document) doc) {
//         hashgraph.wavefront_machine(doc);
//     }


//     @property
//     void time(const(ulong) t) {
//         _current_time=t;
//     }

//     @property
//     const(ulong) time() pure const {
//         return _current_time;
//     }

//     protected Tid _transcript_tid;
//     @property void transcript_tid(Tid tid)
//         @trusted in {
//         assert(_transcript_tid != _transcript_tid.init, format("%s hash already been set", __FUNCTION__));
//     }
//     do {
//         _transcript_tid=tid;
//     }

//     @property Tid transcript_tid() pure nothrow {
//         return _transcript_tid;
//     }

    // override void receive(const(Document) doc) {
    //     hashgraph.wavefront_machine(doc);
    // }

//     @property Tid scripting_engine_tid() pure nothrow {
//         return _scripting_engine_tid;
//     }
// }

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
