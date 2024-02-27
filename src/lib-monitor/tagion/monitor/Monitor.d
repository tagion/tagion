module tagion.monitor.Monitor;

@safe:

import tagion.hashgraph.Event : Event;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.HashGraphBasic : Tides;
import tagion.hashgraph.Round;
import tagion.hashgraphview.EventMonitorCallbacks : EventMonitorCallbacks;
import tagion.network.ListenerSocket;

import std.format;
import std.string;
import tagion.Keywords;
import tagion.basic.ConsensusExceptions : ConsensusException;
import tagion.basic.Message;
import tagion.basic.Types : FileExtension;
import tagion.basic.basic : EnumText, basename;
import tagion.basic.tagionexceptions : TagionException;
import tagion.crypto.Types : Pubkey;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONJSON;
import tagion.logger.Logger;
import tagion.utils.BitMask;

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
import core.thread;
import std.concurrency;
import std.socket;
import std.stdio : writefln, writeln;

import tagion.logger;
import tagion.hashgraph.HashGraphBasic;
import tagion.hibon.HiBONRecord;

class LogMonitorCallBacks : EventMonitorCallbacks {

    Topic topic;

    this(string event_topic_name = "monitor") {
        topic = Topic(event_topic_name);
    }

    struct EventPackages {
        const(EventPackage)[] packages;
        mixin HiBONRecord!(q{
            this(const(Event)[] events) pure nothrow {
                foreach(e; events) {
                    packages ~= *(e.event_package);
                }
            }
        });
    }

    nothrow :

    void connect(const(Event) e) {
        log.event(topic, __FUNCTION__, *(e.event_package));
    }
    void witness(const(Event) e) {
        log.event(topic, __FUNCTION__, *(e.event_package));
    }
    void round(const(Event) e) {
        log.event(topic, __FUNCTION__, *(e.event_package));
    }
    void round_decided(const(Round.Rounder) rounder) {
    }
    void round_received(const(Event) e) {
        log.event(topic, __FUNCTION__, *(e.event_package));
    }
    void famous(const(Event) e) {
        log.event(topic, __FUNCTION__, *(e.event_package));
    }
    void remove(const(Event) e) {
        log.event(topic, __FUNCTION__, *(e.event_package));
    }
    void epoch(const(Event)[] e) {
        const packages = EventPackages(e);
        log.event(topic, __FUNCTION__, packages);
    }
}

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
        "round",
        "is_grounded",
        "count",
    ];
    mixin(EnumText!("Params", _params));

    protected {
        Tid _socket_thread_id;
        //       Tid _network_socket_tread_id;
    }
    // immutable uint _global_node_id;
    immutable FileExtension ext;

    @trusted
    void socket_send(const(HiBON) hibon) nothrow {

        void inner_send() {
            const doc = Document(hibon);

            with (FileExtension) {
                switch (ext) {
                case json:
                    // log("SENDING JSON: %s", doc.toJSON.toString);
                    _socket_thread_id.send(doc.toJSON.toString);
                    break;
                case hibon:
                    // log("SENDING HIBON");
                    _socket_thread_id.send(doc);
                    break;
                default:
                    throw new MonitorException(message("Bad fileformat %s. Only %s and %s allowed", json, hibon));
                }
            }
        }

        try {
            inner_send();
        }
        catch (Exception e) {
            log.error("Monitor callback failed\n%s", e);
        }
    }

    static HiBON createHiBON(const(Event) e) nothrow {
        auto hibon = new HiBON;

        try {
            hibon[basename!(e.id)] = e.id;
            hibon[basename!(e.node_id)] = e.node_id;
            hibon[Params.count] = Event.count;
            if (e.mother !is null) {
                hibon[Params.mother] = e.mother.id;
            }
            if (e.father !is null) {
                hibon[Params.father] = e.father.id;
            }

        }
        catch (Exception excp) {
            // empty
        }
        return hibon;
    }

    const(string) getBitMaskString(const(BitMask) bitmask, uint node_size) @trusted {
        return format("%*.*s", node_size, node_size, bitmask);
    }

    nothrow {
        import tagion.basic.Debug;
        import tagion.hibon.HiBONJSON;

        void connect(const(Event) e) {

            immutable _witness = e.witness !is null;

            auto hibon = createHiBON(e);

            try {
                hibon[Params.altitude] = e.altitude;
                hibon[Params.order] = e.order;
                if (e.hasRound) {
                    hibon[Params.number] = e.round.number;
                }
                if (e.mother !is null) {
                    hibon[Params.mother] = e.mother.id;
                }
                if (e.father !is null) {
                    hibon[Params.father] = e.father.id;
                }
                if (!e.payload.empty) {
                    hibon[Params.payload] = e.payload;
                }
            }
            catch (Exception excp) {
                //empty
            }

            socket_send(hibon);
        }

        void witness(const(Event) e) {
            immutable _witness = e.witness !is null;
            auto hibon = createHiBON(e);
            try {
                hibon[Params.witness] = _witness;
            }
            catch (Exception excp) {
                // empty
            }
            socket_send(hibon);
        }

        void round_received(const(Event) e) {
            auto hibon = createHiBON(e);
            try {
                hibon[Params.received_number] = e.round_received.number;
            }
            catch (Exception excp) {
                //empty
            }

            socket_send(hibon);
        }

        void round_decided(const(Round.Rounder) rounder) {
            // auto hibon = new HiBON;
            // auto round = new HiBON;
            // const r = rounder.last_decided_round;

            // assumeWontThrow({
            //     round[Params.number] = r.number;
            //     round[Params.decided] = true;
            //     round[Params.decided_count] = rounder.cached_decided_count; // decided_count;
            // });

            // socket_send(hibon);
        }

        void coin_round(const(Round) r) {
            // auto hibon = new HiBON;
            // auto round = new HiBON;
            // assumeWontThrow({ round[Params.number] = r.number; round[Params.coin] = true; hibon[Params.round] = round; });

            // socket_send(hibon);
        }

        void looked_at(const(Event) e) {
            // auto hibon=createHiBON(e);
            // auto round=new HiBON;
            // round[Keywords.number]=e.round.number;
            // round[Keywords.looked_at_mask]=bitarray2bool(e.round.looked_at_mask);
            // round[Keywords.looked_at_count]=cast(int)e.round.looked_at_count;
            // round[Keywords.seeing_completed]=cast(int)e.round.seeing_completed;
            // round[Keywords.completed]=cast(int)e.round.completed;

            // hibon[Keywords.round]=round;
            // socket_send(hibon);
        }

        void famous(const(Event) e) {
            auto hibon = createHiBON(e);

            try {
                hibon[Params.famous] = e.isFamous();
            }
            catch (Exception excp) {
                // empty
            }
            socket_send(hibon);
        }

        void son(const(Event) e) {
            // auto hibon=createHiBON(e);
            // hibon[Keywords.son]=e.son.id;
            // socket_send(hibon);
        }

        void daughter(const(Event) e) {
            // auto hibon=createHiBON(e);
            // hibon[Keywords.daughter]=e.daughter.id;
            // socket_send(hibon);
        }

        void round(const(Event) e) {
            auto hibon = createHiBON(e);
            auto round = new HiBON;
            try {
                round[Params.number] = e.round.number;
                round[Keywords.completed] = e.round.decided;
                hibon[Keywords.round] = round;
            }
            catch (Exception excp) {
                //empty
            }
            socket_send(hibon);
        }

        void forked(const(Event) e) {
            // auto hibon=createHiBON(e);
            // hibon[Keywords.forked]=e.forked;
            // socket_send(hibon);
        }

        void remove(const(Event) e) {
            // set the daugther to be grounded
            set_grounded(e.daughter);

            auto hibon = createHiBON(e);
            try {
                hibon[Params.remove] = true;
            }
            catch (Exception excp) {
                // empty
            }
            // assumeWontThrow({ hibon[Params.remove] = true; });
            socket_send(hibon);
        }

        // sets the event to grounded
        void set_grounded(const(Event) e) {
            // log("SETTING GROUNDED");
            // auto hibon = createHiBON(e);
            // try {
            //     hibon[Params.is_grounded] = true;
            // } catch (Exception excp) {
            //     // empty
            // }
            // socket_send(hibon);
        }

        void remove(const(Round) r) {
            // auto hibon = new HiBON;
            // auto round = new HiBON;
            // assumeWontThrow({ round[Params.number] = r.number; round[Params.remove] = true; });
            // // hibon[Keywords.round]=round;
            // socket_send(hibon);
        }

        void strong_vote(const(Event) e, immutable uint votes) {
            // auto hibon = createHiBON(e);
            // assumeWontThrow({ hibon[Params.strong_votes] = votes; });
            // socket_send(hibon);
        }

        void iterations(const(Event) e, const uint count) {
            // auto hibon=createHiBON(e);
            // hibon[Keywords.iterations]=count;
            // socket_send(hibon);
        }

        void epoch(const(Event[]) received_events) {
            // auto epoch = new HiBON;
            // auto hibon = new HiBON;
            // auto list = new HiBON[received_events.length];
            // assumeWontThrow({
            //     foreach (i, e; received_events) {
            //         auto hibon_e = new HiBON;
            //         hibon_e[basename!(e.id)] = e.id;
            //         list[i] = hibon_e;
            //     }
            //     hibon[Params.list] = list;
            //     epoch[Params.epoch] = hibon;
            // });
            // socket_send(epoch);
        }

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
            const FileExtension dataformat) {
        this._socket_thread_id = socket_thread_id;
        this.ext = dataformat;
    }

    @trusted
    void sendMessage(string msg) {
        _socket_thread_id.send(msg);
    }

}
