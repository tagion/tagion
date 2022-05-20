module tagion.monitor.Monitor;

//import std.bitmanip : BitArray;

import tagion.network.ListenerSocket;

import tagion.hashgraph.Event : Event, Round;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.HashGraphBasic : Tides, EventMonitorCallbacks;

//import tagion.hashg : EventMonitorCallbacks; //NetCallbacks;
//import tagion.gossip.GossipNet : StdGossipNet;
import tagion.basic.ConsensusExceptions : ConsensusException;

//import tagion.basic.Basic : Control, basename, Pubkey, DataFormat;
import tagion.basic.Types : Pubkey, FileExtension;
import tagion.basic.Basic : EnumText;
import tagion.basic.Message;

import tagion.hibon.HiBON;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.basic.TagionExceptions : TagionException;
import tagion.utils.BitMask;
import tagion.logger.Logger;

// import tagion.Keywords;

@safe
class MonitorException : TagionException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

HiBON bitarray2bool(const(BitMask) bits) @trusted {
    auto mask = new HiBON;
    uint i;
    foreach (n; bits[]) {
        mask[i++] = n;
    }
    return mask;
}

//import core.thread : dur, msecs, seconds;
import std.concurrency;
import std.stdio : writeln, writefln;
import std.exception : assumeWontThrow;

// import std.format : format;
// import std.bitmanip : write;
import std.socket;
import core.thread;

version (none) @safe
class MonitorCallBacks : EventMonitorCallbacks {
    protected enum _params = [
            "altitude",
            "mother",
            "father",
            "order",
            "number",
            "payload",
            "famous",
            "famous_votes",
            "remove",
            "list",
            "epoch",
            "strong_votes",
            "decided",
            "decided_count",
            "witness",
            "witness_mask",
            "received_number",
            "coin",
            "coin_round",
            "round"
        ];
    mixin(EnumText!("Params", _params));

    protected {
        Tid _socket_thread_id;
        Tid _network_socket_tread_id;
    }
    immutable uint _local_node_id;
    // immutable uint _global_node_id;
    immutable FileExtension ext;

    @trusted
    void socket_send(const(HiBON) hibon) nothrow {
        void inner_send() {
            const doc = Document(hibon);
            with (FileExtension) {
                switch (ext) {
                case json:
                    _socket_thread_id.send(doc.toJSON.toString);
                    break;
                case hibon:
                    _socket_thread_id.send(doc);
                    break;
                default:
                    throw new MonitorException(message("Bad fileformat %s. Only %s and %s allowed", json, hibon));
                }
            }
        }

        assumeWontThrow(inner_send());
    }

    static HiBON createHiBON(const(Event) e) nothrow {
        auto hibon = new HiBON;
        assumeWontThrow({ hibon[basename!(e.id)] = e.id; hibon[basename!(e.node_id)] = e.node_id; });
        return hibon;
    }

    nothrow {
        void create(const(Event) e) {
            // if(e.mother !is null) {
            //     // writeln("Mother id", e.mother.id);
            // }

            immutable _witness = e.witness !is null;

            auto hibon = createHiBON(e);
            assumeWontThrow({
                hibon[Params.altitude] = e.altitude;
                hibon[Params.order] = e.received_order;
                hibon[Params.number] = e.round.number;
                if (e.mother !is null) {
                    hibon[Params.mother] = e.mother.id;
                }
                if (e.father !is null) {
                    hibon[Params.father] = e.father.id;
                }
                if (e.payload.empty) {
                    hibon[Params.payload] = e.payload;
                }
            });

            socket_send(hibon);
        }

        void witness(const(Event) e) {
            immutable _witness = e.witness !is null;

            auto hibon = createHiBON(e);
            assumeWontThrow({ hibon[Params.witness] = _witness; });
            socket_send(hibon);
        }

        void witness_mask(const(Event) e) {

            auto hibon = createHiBON(e);
            assumeWontThrow({ hibon[Params.witness_mask] = bitarray2bool(e.witness_mask); });
            socket_send(hibon);
        }

        void round_seen(const(Event) e) {
            // auto hibon=createHiBON(e);
            // hibon[Keywords.round_seen]=bitarray2bool(e.witness.round_seen_mask);
            // socket_send(hibon);
        }

        void round_received(const(Event) e) {
            auto hibon = createHiBON(e);
            assumeWontThrow({ hibon[Params.received_number] = e.round_received.number; });
            socket_send(hibon);
        }

        void round_decided(const(Round.Rounder) rounder) {
            auto hibon = new HiBON;
            auto round = new HiBON;
            const r = rounder.last_decided_round;
            assumeWontThrow({
                round[Params.number] = r.number;
                round[Params.decided] = true;
                round[Params.decided_count] = rounder.cached_decided_count; // decided_count;
            });
            //hibon[Params.round]=round;
            socket_send(hibon);
        }

        void coin_round(const(Round) r) {
            auto hibon = new HiBON;
            auto round = new HiBON;
            assumeWontThrow({ round[Params.number] = r.number; round[Params.coin] = true; hibon[Params.round] = round; });
            socket_send(hibon);
        }

        // void looked_at(const(Event) e) {
        //     auto hibon=createHiBON(e);
        //     auto round=new HiBON;
        //     round[Keywords.number]=e.round.number;
        //     round[Keywords.looked_at_mask]=bitarray2bool(e.round.looked_at_mask);
        //     round[Keywords.looked_at_count]=cast(int)e.round.looked_at_count;
        //     round[Keywords.seeing_completed]=cast(int)e.round.seeing_completed;
        //     round[Keywords.completed]=cast(int)e.round.completed;

        //     hibon[Keywords.round]=round;
        //     socket_send(hibon);
        // }

        // void strongly_seeing(const(Event) e) {
        //     auto hibon=createHiBON(e);
        //     hibon[Keywords.strongly_seeing]=e.strongly_seeing;
        //     hibon[Keywords.strong_mask]=bitarray2bool(e.witness.strong_seeing_mask);
        //     socket_send(hibon);
        // }

        void famous(const(Event) e) {
            // auto hibon=createHiBON(e);
            // auto w=e.witness;
            // assumeWontThrow({
            //         hibon[Params.famous]=w.famous;
            //         // hibon[Params.famous_votes]=w.famous_votes;
            //     });
            // socket_send(hibon);
        }

        // void son(const(Event) e) {
        //     auto hibon=createHiBON(e);
        //     hibon[Keywords.son]=e.son.id;
        //     socket_send(hibon);
        // }

        // void daughter(const(Event) e) {
        //     auto hibon=createHiBON(e);
        //     hibon[Keywords.daughter]=e.daughter.id;
        //     socket_send(hibon);
        // }

        void round(const(Event) e) {
            auto hibon = createHiBON(e);
            auto round = new HiBON;
            assumeWontThrow({ round[Params.number] = e.round.number; });
            // round[Keywords.completed]=e.round.completed;
            // hibon[Keywords.round]=round;
            socket_send(hibon);
        }

        // void forked(const(Event) e) {
        //     auto hibon=createHiBON(e);
        //     hibon[Keywords.forked]=e.forked;
        //     socket_send(hibon);
        // }

        void remove(const(Event) e) {
            auto hibon = createHiBON(e);
            assumeWontThrow({ hibon[Params.remove] = true; });
            socket_send(hibon);
        }

        void remove(const(Round) r) {
            auto hibon = new HiBON;
            auto round = new HiBON;
            assumeWontThrow({ round[Params.number] = r.number; round[Params.remove] = true; });
            // hibon[Keywords.round]=round;
            socket_send(hibon);
        }

        void strong_vote(const(Event) e, immutable uint votes) {
            auto hibon = createHiBON(e);
            assumeWontThrow({ hibon[Params.strong_votes] = votes; });
            socket_send(hibon);
        }

        // void iterations(const(Event) e, const uint count) {
        //     auto hibon=createHiBON(e);
        //     hibon[Keywords.iterations]=count;
        //     socket_send(hibon);
        // }

        void epoch(const(Event[]) received_events) {
            auto epoch = new HiBON;
            auto hibon = new HiBON;
            auto list = new HiBON[received_events.length];
            assumeWontThrow({
                foreach (i, e; received_events) {
                    auto hibon_e = new HiBON;
                    hibon_e[basename!(e.id)] = e.id;
                    list[i] = hibon_e;
                }
                hibon[Params.list] = list;
                epoch[Params.epoch] = hibon;
            });
            socket_send(epoch);
        }

        // void connect(const(Event) e) {

        // }

        void receive(lazy const(Document) doc) {

        }

        void consensus_failure(const(ConsensusException) e) {
            // writefln("Impl. needed. %s  msg=%s ",  __FUNCTION__, e.msg);
        }

        // void wavefront_state_receive(const(Document) doc) {
        //     //import tagion.Base : cutHex;
        //     // writefln("Impl. needed. %s  node=%s ",  __FUNCTION__, n.pubkey.cutHex);
        // }

        void sent_tidewave(immutable(Pubkey) receiving_channel, const(Tides) tides) {
            // writefln("Impl. needed. %s  tides=%d ",  __FUNCTION__, tides.length);
        }

        void received_tidewave(immutable(Pubkey) sending_channel, const(Tides) tides) {
            // writefln("Impl. needed. %s  tides=%d ",  __FUNCTION__, tides.length);
        }

        void receive(const(Document) doc) {
            // writefln("Impl. needed. %s  ",  __FUNCTION__);
        }

        void send(const(Pubkey) channel, lazy const(Document) doc) {
            //import tagion.Base : cutHex;
            // writefln("Impl. needed. %s  channel=%s",  __FUNCTION__, channel.cutHex);
        }

        void exiting(const(Pubkey) owner_key, const(HashGraph)) {
            //import tagion.Base : cutHex;
            // writefln("Impl. needed. %s  node=%s ",  __FUNCTION__, n.pubkey.cutHex);
        }
    }

    @trusted
    this(Tid socket_thread_id,
            const uint local_node_id, // const uint global_node_id,
            const FileExtension dataformat) {
        this._socket_thread_id = socket_thread_id;
        this._network_socket_tread_id = locate("network_socket_thread");
        this._local_node_id = local_node_id;
        // this._global_node_id = global_node_id;
        this.dataformat = dataformat;
        // writefln("Created monitor socket with local node id: %s and global node id: %s. Has network socket %s", this._local_node_id, this._global_node_id, this._network_socket_tread_id != Tid.init);
    }

    @trusted
    void sendMessage(string msg) {
        _socket_thread_id.send(msg);
    }

}
