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
    private Tid[immutable(Pubkey)] _tids;
    private immutable(Pubkey)[] _pkeys;
    protected uint _send_node_id;

    Random!uint random;

    this(NativeSecp256k1 crypt, HashGraph hashgraph) {
        super(crypt, hashgraph);
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

    @trusted
    override void trace(string type, immutable(ubyte[]) data) {
        debug {
            if ( options.trace_gossip ) {
                import std.file;
                immutable packfile=format("%s/%s_%d_%s.bson", options.tmp, options.node_name, _send_count, type); //.to!string~"_receive.bson";
                write(packfile, data);
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
        trace("send", data);
        if ( callbacks ) {
            callbacks.send(channel, data);
        }
        fout.writefln("Send %s data=%d", channel.cutHex, data.length);
        _tids[channel].send(data);
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
