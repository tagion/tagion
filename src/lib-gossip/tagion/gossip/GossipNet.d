module tagion.gossip.GossipNet;

import std.concurrency;
import std.format;
import std.exception : assumeUnique;
import std.string : representation;
import core.time : MonoTime;

import tagion.basic.Types : Pubkey;

//import tagion.basic.ConsensusExceptions : convertEnum;
//, consensusCheck, consensusCheckArguments;
//import tagion.utils.Miscellaneous: cutHex;
//import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;

//import tagion.hibon.HiBONRecord : HiBONPrefix, STUB, isStub;

// import tagion.utils.LRU;
// import tagion.utils.Queue;

import tagion.crypto.SecureNet : StdSecureNet;
import tagion.gossip.InterfaceNet;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event;
import tagion.basic.ConsensusExceptions;
import tagion.hashgraph.HashGraphBasic;

//import tagion.crypto.aes.AESCrypto;
//import tagion.crypto.secp256k1.NativeSecp256k1;

//import tagion.logger.Logger;

@safe
abstract class StdGossipNet : StdSecureNet, GossipNet {
    static private shared uint _next_global_id;
    static private shared uint[immutable(Pubkey)] _node_id_pair;

    uint globalNodeId(immutable(Pubkey) channel) {
        if (channel in _node_id_pair) {
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

    this() {
        super();
    }
    // this( HashGraph hashgraph) {
    //     _hashgraph=hashgraph;
    //     super();
    // }

    // override void hashgraph(HashGraphI h) nothrow
    //     in {
    //         assert(_hashgraph is null);
    //     }
    // do {
    //     _hashgraph=h;
    // }

    // override NetCallbacks callbacks() {
    //     return (cast(NetCallbacks)Event.callbacks);
    // }

    static struct Init {
        uint timeout;
        uint node_id;
        uint N;
        string monitor_ip_address;
        ushort monitor_port;
        uint seed;
        string node_name;
    }

    protected {
        ulong _current_time;
        //        HashGraphI _hashgraph;
    }

    // override void receive(const(Document) doc) {
    //     hashgraph.wavefront_machine(doc);
    // }

    protected Tid _transcript_tid;
    @property void transcript_tid(Tid tid)
    @trusted
    in {
        assert(_transcript_tid !is _transcript_tid.init, format("%s hash already been set", __FUNCTION__));
    }
    do {
        _transcript_tid = tid;
    }

    @property Tid transcript_tid() pure nothrow {
        return _transcript_tid;
    }

    protected Tid _scripting_engine_tid;
    @property void scripting_engine_tid(Tid tid) @trusted
    in {
        assert(_scripting_engine_tid !is _scripting_engine_tid.init, format(
                "%s hash already been set", __FUNCTION__));
    }
    do {
        _scripting_engine_tid = tid;
    }

    @property Tid scripting_engine_tid() pure nothrow {
        return _scripting_engine_tid;
    }
}
