module tagion.gossip.EmulatorGossipNet;

import std.stdio;
import std.concurrency;
import std.format;
import std.array : join;
import std.conv : to;

import tagion.revision;
import tagion.Options;
import tagion.basic.Basic : EnumText, Buffer, Pubkey, buf_idup,  basename, isBufferType;
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
//import tagion.hashgraph.HashGraph;
import tagion.hashgraph.HashGraphBasic : buildEventPackage, HashGraphI;
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


@safe
class EmulatorGossipNet : StdGossipNet {
    private Tid[immutable(Pubkey)] _tids;
    private immutable(Pubkey)[] _pkeys;
    protected uint _send_node_id;

    Random!uint random;

    this() {
        super();
    }

    void set(immutable(Pubkey)[] pkeys)
        in {
            assert(_tids is null);
        }
    do {
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
        for(;;) {
            const node_index=random.value(0, N);
            auto result=_pkeys[node_index];
            if (result != pubkey) {
                return result;
            }
        }
        assert(0);
    }


    void dump(const(HiBON[]) events) const {
        foreach(e; events) {
            auto pack_doc=Document(e.serialize);
            immutable pack=buildEventPackage(this, pack_doc);
//            immutable fingerprint=pack.event_body.fingerprint;
            log("\tsending %s f=%s a=%d", pack.pubkey.cutHex, pack.fingerprint.cutHex, pack.event_body.altitude);
        }
    }

    protected uint _send_count;
    @trusted
    void send(immutable(Pubkey) channel, const(Document) doc) {
        log.trace("send to %s %d bytes", channel.cutHex, doc.serialize.length);
        if ( callbacks ) {
            callbacks.send(channel, doc);
        }
        _tids[channel].send(doc);
    }
}
