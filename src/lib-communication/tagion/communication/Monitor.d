module tagion.communication.Monitor;

import std.bitmanip : BitArray;

import tagion.communication.ListenerSocket;

import tagion.hashgraph.Event : Event, Round;
//import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.HashGraphBasic : Tides, HashGraphI;
import tagion.gossip.InterfaceNet : NetCallbacks;
//import tagion.gossip.GossipNet : StdGossipNet;
import tagion.basic.ConsensusExceptions : ConsensusException;

import tagion.basic.Basic : Control, basename, Pubkey, DataFormat;
import tagion.basic.Message;

import tagion.hibon.HiBON;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.basic.TagionExceptions : TagionException;

import tagion.Keywords;

@safe
class MonitorException : TagionException {
    this( immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__ ) pure {
        super( msg, file, line );
    }
}

HiBON bitarray2bool(ref const(BitArray) bits) @trusted {
    auto mask=new HiBON;
    foreach(i, m; bits) {
        if (m) {
            mask[i]=true;
        }
    }
    return mask;
}


//import core.thread : dur, msecs, seconds;
import std.concurrency;
import std.stdio : writeln, writefln;
// import std.format : format;
// import std.bitmanip : write;
import std.socket;
import core.thread;

@safe
class MonitorCallBacks : NetCallbacks {
    protected {
        Tid _socket_thread_id;
        Tid _network_socket_tread_id;
    }
    immutable uint _local_node_id;
    immutable uint _global_node_id;
    immutable DataFormat dataformat;

    @trusted
    void socket_send(const(HiBON) hibon) {
        const doc=Document(hibon.serialize);
        with(DataFormat) {
            switch (dataformat) {
            case json:
                _socket_thread_id.send(doc.toJSON.toString);
                break;
            case hibon:
                _socket_thread_id.send(doc);
                break;
            default:
                throw new MonitorException(message("Bad dataformat %s. Only %s and %s allowed", json, hibon));
            }
        }
    }

    static HiBON createHiBON(const(Event) e) {
        auto hibon=new HiBON;
        hibon[basename!(e.id)]=e.id;
        hibon[basename!(e.node_id)]=e.node_id;
        return hibon;
    }

    void create(const(Event) e) {
        // if(e.mother !is null) {
        //     // writeln("Mother id", e.mother.id);
        // }

        immutable _witness=e.witness !is null;

        auto hibon=createHiBON(e);
        hibon[basename!(Event.Params.altitude)]=e.altitude;
        hibon[basename!(Keywords.received_order)]=e.received_order;
        if ( e.mother !is null ) {
            hibon[Keywords.mother]=e.mother.id;
        }
        if ( e.father !is null ) {
            hibon[Keywords.father]=e.father.id;
        }
        if ( e.payload !is null ) {
            hibon[Keywords.payload]=e.payload;
        }

        socket_send(hibon);
    }


    void witness(const(Event) e) {
        immutable _witness=e.witness !is null;

        auto hibon=createHiBON(e);
        hibon[Keywords.witness]=_witness;
        socket_send(hibon);
    }


    void witness_mask(const(Event) e) {

        auto hibon=createHiBON(e);
        hibon[Keywords.witness_mask]=bitarray2bool(e.witness_mask);
        socket_send(hibon);
    }

    void round_seen(const(Event) e) {
        auto hibon=createHiBON(e);
        hibon[Keywords.round_seen]=bitarray2bool(e.witness.round_seen_mask);
        socket_send(hibon);
    }

    void round_received(const(Event) e) {
        auto hibon=createHiBON(e);
        hibon[Keywords.round_received]=e.round_received.number;
        socket_send(hibon);
    }

    void round_decided(const(Round.Rounder) rounder) {
        auto hibon=new HiBON;
        auto round=new HiBON;
        const r=rounder.last_decided_round;
        round[Keywords.number]=r.number;
        round[Keywords.decided]=true;
        round[Keywords.decided_count]=rounder.cached_decided_count;// decided_count;
        hibon[Keywords.round]=round;
        socket_send(hibon);
    }

    void coin_round(const(Round) r) {
        auto hibon=new HiBON;
        auto round=new HiBON;
        round[Keywords.number]=r.number;
        round[Keywords.coin]=true;
        hibon[Keywords.round]=round;
        socket_send(hibon);
    }

    void looked_at(const(Event) e) {
        auto hibon=createHiBON(e);
        auto round=new HiBON;
        round[Keywords.number]=e.round.number;
        round[Keywords.looked_at_mask]=bitarray2bool(e.round.looked_at_mask);
        round[Keywords.looked_at_count]=cast(int)e.round.looked_at_count;
        round[Keywords.seeing_completed]=cast(int)e.round.seeing_completed;
        round[Keywords.completed]=cast(int)e.round.completed;

        hibon[Keywords.round]=round;
        socket_send(hibon);
    }

    void strongly_seeing(const(Event) e) {
        auto hibon=createHiBON(e);
        hibon[Keywords.strongly_seeing]=e.strongly_seeing;
        hibon[Keywords.strong_mask]=bitarray2bool(e.witness.strong_seeing_mask);
        socket_send(hibon);
    }

    void famous(const(Event) e) {
        auto hibon=createHiBON(e);
        auto w=e.witness;
        hibon[Keywords.famous]=w.famous;
        hibon[Keywords.famous_votes]=w.famous_votes;
        socket_send(hibon);
    }

    void son(const(Event) e) {
        auto hibon=createHiBON(e);
        hibon[Keywords.son]=e.son.id;
        socket_send(hibon);
    }

    void daughter(const(Event) e) {
        auto hibon=createHiBON(e);
        hibon[Keywords.daughter]=e.daughter.id;
        socket_send(hibon);
    }

    void round(const(Event) e) {
        auto hibon=createHiBON(e);
        auto round=new HiBON;
        round[Keywords.number]=e.round.number;
        round[Keywords.completed]=e.round.completed;
        hibon[Keywords.round]=round;
        socket_send(hibon);
    }

    void forked(const(Event) e) {
        auto hibon=createHiBON(e);
        hibon[Keywords.forked]=e.forked;
        socket_send(hibon);
    }

    void remove(const(Event) e) {
        auto hibon=createHiBON(e);
        hibon[Keywords.remove]=true;
        socket_send(hibon);
    }

    void remove(const(Round) r) {
        auto hibon=new HiBON;
        auto round=new HiBON;
        round[Keywords.number]=r.number;
        round[Keywords.remove]=true;
        hibon[Keywords.round]=round;
        socket_send(hibon);
    }

    void strong_vote(const(Event) e, immutable uint votes) {
        auto hibon=createHiBON(e);
        hibon[Keywords.strong_votes]=votes;
        socket_send(hibon);
    }

    void iterations(const(Event) e, const uint count) {
        auto hibon=createHiBON(e);
        hibon[Keywords.iterations]=count;
        socket_send(hibon);
    }

    void epoch(const(Event[]) received_events) {
        auto epoch=new HiBON;
        auto hibon=new HiBON;
        auto list=new HiBON[received_events.length];
        foreach(i, e; received_events) {
            auto hibon_e=new HiBON;
            hibon_e[basename!(e.id)]=e.id;
            list[i]=hibon_e;
        }
        hibon[Keywords.list]=list;
        epoch[Keywords.epoch]=hibon;
        socket_send(epoch);
    }

    void consensus_failure(const(ConsensusException) e) {
        // writefln("Impl. needed. %s  msg=%s ",  __FUNCTION__, e.msg);
    }

    void wavefront_state_receive(const(Document) doc) {
        //import tagion.Base : cutHex;
        // writefln("Impl. needed. %s  node=%s ",  __FUNCTION__, n.pubkey.cutHex);
    }

    void sent_tidewave(immutable(Pubkey) receiving_channel, const(Tides) tides) {
        // writefln("Impl. needed. %s  tides=%d ",  __FUNCTION__, tides.length);
    }

    void received_tidewave(immutable(Pubkey) sending_channel, const(Tides) tides) {
        // writefln("Impl. needed. %s  tides=%d ",  __FUNCTION__, tides.length);
    }

    void receive(const(Document) doc) {
        // writefln("Impl. needed. %s  ",  __FUNCTION__);
    }

    void send(immutable(Pubkey) channel, const(Document) doc) {
        //import tagion.Base : cutHex;
        // writefln("Impl. needed. %s  channel=%s",  __FUNCTION__, channel.cutHex);
    }

    void exiting(const(Pubkey) owner_key, const(HashGraphI)) {
        //import tagion.Base : cutHex;
        // writefln("Impl. needed. %s  node=%s ",  __FUNCTION__, n.pubkey.cutHex);
    }

    @trusted
    this(Tid socket_thread_id,
        const uint local_node_id,
        const uint global_node_id,
        const DataFormat dataformat) {
        this._socket_thread_id = socket_thread_id;
        this._network_socket_tread_id = locate("network_socket_thread");
        this._local_node_id = local_node_id;
        this._global_node_id = global_node_id;
        this.dataformat = dataformat;
        // writefln("Created monitor socket with local node id: %s and global node id: %s. Has network socket %s", this._local_node_id, this._global_node_id, this._network_socket_tread_id != Tid.init);
    }

    @trusted
    void sendMessage(string msg) {
        _socket_thread_id.send(msg);
    }
}
