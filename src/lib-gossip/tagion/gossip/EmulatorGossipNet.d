module tagion.gossip.EmulatorGossipNet;

import std.stdio;
import std.concurrency;
import std.format;
import std.array : join;
import std.conv : to;

import tagion.revision;
import tagion.Options;
import tagion.basic.Basic : EnumText, Buffer, Pubkey, Payload, buf_idup,  basename, isBufferType;
//import tagion.TagionExceptions : convertEnum, consensusCheck, consensusCheckArguments;
import tagion.utils.Miscellaneous: cutHex;
import tagion.utils.Random;
import tagion.utils.LRU;
import tagion.utils.Queue;
//import tagion.Keywords;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.gossip.GossipNet;
import tagion.gossip.InterfaceNet;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event;
import tagion.basic.ConsensusExceptions;

import tagion.basic.Logger;
import tagion.ServiceNames : get_node_name;
import tagion.crypto.secp256k1.NativeSecp256k1;

@trusted
static uint getTids(Tid[] tids) {
    uint result=uint.max;
    foreach(i, ref tid ; tids) {
        immutable uint_i=cast(uint)i;
        immutable taskname=get_node_name(*options, uint_i);
        tid=locate(taskname);
        if ( tid == thisTid ) {
            result=uint_i;
        }
    }
    return result;
}


// string getfilename(string[] names) {
//     import std.path;
//     return buildPath(options.tmp, setExtension(names.join, options.logext));
// }


@safe
class EmulatorGossipNet : StdGossipNet {
    private Tid[immutable(Pubkey)] _tids;
    private immutable(Pubkey)[] _pkeys;
    protected uint _send_node_id;

    Random!uint random;

    this(HashGraph hashgraph) {
        super(hashgraph);
    }

    void set(immutable(Pubkey)[] pkeys)
        in {
            assert(_tids is null);
        }
    do {
//        log("_pkeys.length=%d", pkeys.length);
        _pkeys=pkeys;
        auto tids=new Tid[pkeys.length];
        getTids(tids);
        foreach(i, p; pkeys) {
            _tids[p]=tids[cast(uint)i];
        }
    }

    immutable(Pubkey) selectRandomNode(const bool active=true)
    out(result)  {
        assert(result != pubkey);
    }
    do {
        immutable N=cast(uint)_tids.length;
        //uint node_index;
//        Pubkey result;
//        do {
        for(;;) {
            const node_index=random.value(0, N);
            auto result=_pkeys[node_index];
            if (result != pubkey) {
                return result;
            }
        }
        assert(0);
//        return result;
    }


    void dump(const(HiBON[]) events) const {
        foreach(e; events) {
            auto pack_doc=Document(e.serialize);
            immutable pack=new immutable(EventPackage)(this, pack_doc);
            immutable fingerprint=calcHash(pack.event_body.serialize);
            log("\tsending %s f=%s a=%d", pack.pubkey.cutHex, fingerprint.cutHex, pack.event_body.altitude);
        }
    }

    @trusted
    override void trace(string type, immutable(ubyte[]) data) {
        debug {
            if ( options.trace_gossip ) {
                import std.file;
//                immutable packfile=format("%s/%s_%d_%s.hibon", options.tmp, options.node_name, _send_count, type); //.to!string~"_receive.hibon";
                log.trace("%s/%s_%d_%s.hibon", options.tmp, options.node_name, _send_count, type);
//                write(packfile, data);
                _send_count++;
            }
        }
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
//        trace("send", data);
        log.trace("send %s bytes", data.length);
        if ( callbacks ) {
            callbacks.send(channel, data);
        }
        log("Send %s data=%d", channel.cutHex, data.length);
        _tids[channel].send(data);
    }

//    private uint eva_count;

}
