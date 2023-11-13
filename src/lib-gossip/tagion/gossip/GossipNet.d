module tagion.gossip.GossipNet;

import core.time : MonoTime;
import std.concurrency;
import std.exception : assumeUnique;
import std.format;
import std.string : representation;
import tagion.basic.ConsensusExceptions;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.crypto.Types : Pubkey;
import tagion.gossip.InterfaceNet;
import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.HashGraphBasic;
import tagion.hibon.Document : Document;

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
