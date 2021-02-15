module tagion.gossip.P2pGossipNet;

import std.stdio;
import std.concurrency;
import std.format;
import std.array : join;
import std.conv : to;
import std.file;
import std.file: fwrite = write;
import std.typecons;

import tagion.gossip.revision;
import tagion.Options;
import tagion.basic.Basic : EnumText, Buffer, Pubkey, buf_idup,  basename, isBufferType, Control;
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
import tagion.hashgraph.HashGraphBasic : Params, convertState, ExchangeState;
import tagion.basic.ConsensusExceptions;

import tagion.basic.Logger;
import tagion.ServiceNames : get_node_name;
import tagion.crypto.secp256k1.NativeSecp256k1;
//import tagion.services.MdnsDiscoveryService;
import p2plib = p2p.node;
import p2p.connection;
import std.array;
//import tagion.services.P2pTagionService;

import tagion.dart.DART;

import std.datetime;

shared class ConnectionPoolBridge{
    ulong[Pubkey] lookup;

    void removeConnection(ulong connectionId){
        foreach(key, val; lookup){
            if(val == connectionId){
                log("CPB::REMOVING KEY: connection id: %s as pk: %s", val, key.cutHex);
                lookup.remove(key);
                // break;
            }
        }
    }

    bool contains(Pubkey pk){
        return (pk in lookup) !is null;
    }

}


immutable class AddressBook(TKey){
    this(NodeAddress[TKey] addrs){
        this.data = cast(immutable) addrs.dup;
    }
    immutable(NodeAddress[TKey]) data;
}

struct NodeAddress{
    enum tcp_token = "/tcp/";
    enum p2p_token = "/p2p/";
    string address;
    bool is_marshal;
    string id;
    uint port;
    DART.SectorRange sector;
    this(string address, immutable Options opts, bool marshal = false){
        import std.string;
        try{
            this.address = address;
            this.is_marshal = marshal;
            if(!marshal){
                this.id = address[address.lastIndexOf(p2p_token)+5..$];
                auto tcpIndex = address.indexOf(tcp_token)+tcp_token.length;
                this.port = to!uint(address[tcpIndex .. tcpIndex + 4]);

                const node_number = this.port - opts.port_base;
                if (this.port>=opts.dart.sync.maxSlavePort){
                    sector = DART.SectorRange(opts.dart.sync.netFromAng, opts.dart.sync.netToAng);
                }
                else{
                    const max_sync_node_count = opts.dart.sync.master_angle_from_port
                    ? opts.dart.sync.maxSlaves
                    : opts.dart.sync.maxMasters;
                    auto ang_range = calcAngleRange(opts, node_number, max_sync_node_count);

                    sector = DART.SectorRange(ang_range[0], ang_range[1]);
                }
            }
            else {
                import std.json;
                auto json = parseJSON(address);
                this.id = json["ID"].str;
                auto addr = json["Addrs"].array()[0].str();
                auto tcpIndex = addr.indexOf(tcp_token)+tcp_token.length;
                this.port = to!uint(addr[tcpIndex .. tcpIndex + 4]);
            }
        }
        catch(Exception e){
            writeln(e.msg);
                log.fatal(e.msg);
        }
    }

    static Tuple!(ushort, ushort) calcAngleRange(immutable(Options) opts, const ulong node_number, const ulong max_nodes){
        import std.math: ceil, floor;
        float delta = (cast(float)(opts.dart.sync.netToAng - opts.dart.sync.netFromAng))/max_nodes;
        auto from_ang = to!ushort(opts.dart.from_ang + floor(node_number*delta));
        auto to_ang = to!ushort(opts.dart.from_ang + floor((node_number+1)*delta));
        return tuple(from_ang, to_ang);
    }
    static string parseAddr(string addr) {
        import std.string;

        string result;
        auto firstpartAddr = addr.indexOf('[') + 1;
        auto secondpartAddr = addr.indexOf(']');
        auto firstpartId = addr.indexOf('{') + 1;
        auto secondpartId = addr.indexOf(':');
        // writefln("addr %s len: %d\naddress from %d to %d\nid from %d to %d", addr,
                // addr.length, firstpartAddr, secondpartAddr, firstpartId, secondpartId);
        result = addr[firstpartAddr .. secondpartAddr] ~ p2p_token ~ addr[firstpartId .. secondpartId];
        return result;
    }
    public string toString(){
        return address;
    }
}


@safe
class P2pGossipNet : StdGossipNet {
    protected uint _send_node_id;
    protected string shared_storage;
    immutable(Pubkey)[] pkeys;
    shared p2plib.Node node;
    protected immutable(Options) opts;
    protected shared(ConnectionPool!(shared p2plib.Stream, ulong)) connectionPool;
    Random!uint random;
    Tid sender_tid;
    static uint counter;

    this(HashGraph hashgraph, immutable(Options) opts, shared p2plib.Node node, shared(ConnectionPool!(shared p2plib.Stream, ulong)) connectionPool, ref shared ConnectionPoolBridge connectionPoolBridge) {
        super(hashgraph);
        this.connectionPool = connectionPool;
        shared_storage = opts.path_to_shared_info;
        this.node = node;
        this.opts = opts;
        @trusted void spawn_sender(){
            this.sender_tid = spawn(&async_send, node, opts, connectionPool, connectionPoolBridge);
        }
        spawn_sender();
    }
    void close(){
        @trusted void send_stop(){
            import std.concurrency: prioritySend, Tid, locate;
            auto sender = locate(opts.transaction.net_task_name);
            if (sender!=Tid.init){
                // log("sending stop to gossip net");
                sender.prioritySend(Control.STOP);
                receiveOnly!Control;
            }
        }
        send_stop();
    }
    void set(immutable(Pubkey)[] pkeys){
        this.pkeys = pkeys;
    }

    immutable(Pubkey) selectRandomNode(const bool active=true) {
        uint node_index;
        do {
            node_index=random.value(0, cast(int)pkeys.length);
        } while (pkeys[node_index] == pubkey);
        return pkeys[node_index];
    }


    // void dump(const(HiBON[]) events) const {
    //     foreach(e; events) {
    //         auto pack_doc=Document(e.serialize);
    //         auto pack=EventPackage(pack_doc);
    //         immutable fingerprint=calcHash(pack.event_body.serialize);
    //         log("\tsending %s f=%s a=%d", pack.pubkey.cutHex, fingerprint.cutHex, pack.event_body.altitude);
    //     }
    // }

    version(none)
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
    void send(immutable(Pubkey) channel, const(Document) doc) {
        import std.concurrency: tsend=send, prioritySend, Tid, locate;
        auto sender = locate(opts.transaction.net_task_name);
        if(sender!=Tid.init){
            counter++;
            // log("sending to sender %d", counter);
            tsend(sender, channel, doc.data, counter);
        }else{
            log("sender not found");
        }
    }

    @trusted
    protected void send_remove(Pubkey pk){
        import std.concurrency: tsend=send, Tid, locate;
        auto sender = locate(opts.transaction.net_task_name);
        if(sender!=Tid.init){
            counter++;
            // log("sending close to sender %d", counter);
            tsend(sender, pk, counter);
        }else{
            log("sender not found");
        }
    }

    override void receive(const(Document) doc) {
//    Event delegate(immutable(ubyte)[] father_fingerprint) @safe register_leading_event ) {
        log("received time: %s", Clock.currTime().toUTC());
        // log("1.receive");
//        auto doc=Document(data);
        immutable type=doc[Params.type].get!uint;
        immutable received_state=convertState(type);
        Pubkey received_pubkey=doc[Event.Params.pubkey].get!(immutable(ubyte)[]);

        // log("2.receive");
        super.receive(doc);//, register_leading_event);
        import std.algorithm: canFind;

        log("3.receive");
        if([/*ExchangeState.FIRST_WAVE,*/ ExchangeState.SECOND_WAVE, ExchangeState.BREAKING_WAVE].canFind(received_state)){
            log("send remove with state: %s", received_state);
            send_remove(received_pubkey);
        }
        //return result;
    }


    private uint eva_count;

    Document evaPackage() {
        eva_count++;
        auto hibon=new HiBON;
        hibon["pubkey"]=pubkey;
        hibon["git"]=HASH;
        hibon["nonce"]="Should be implemented:"~to!string(eva_count);
        return Document(hibon.serialize);
    }

}


static void async_send(shared p2plib.Node node, immutable Options opts, shared(ConnectionPool!(shared p2plib.Stream, ulong)) connectionPool, shared ConnectionPoolBridge connectionPoolBridge){
    scope(exit){
        // log("SENDER CLOSED!!");
        ownerTid.send(Control.END);
    }
    log.register(opts.transaction.net_task_name);
    void send_to_channel(immutable(Pubkey) channel, Buffer data){

        log("sending to: %s TIME: %s", channel.cutHex, Clock.currTime().toUTC());
        auto streamIdPtr = channel in connectionPoolBridge.lookup;
        auto streamId = streamIdPtr is null ? 0 : *streamIdPtr;
        // log("stream id: %d", streamId);
        if(streamId == 0 || !connectionPool.contains(streamId)){
             auto discovery_tid = locate(opts.discovery.task_name);
            if(discovery_tid != Tid.init){
                discovery_tid.send(channel, thisTid);
                // writeln("waiting for response");
                // auto node_address = receiveOnly!(NodeAddress);
                receive(
                    (NodeAddress node_address){
                        auto stream = node.connect(node_address.address, node_address.is_marshal, [opts.transaction.protocol_id]);
                        streamId = stream.Identifier;
                        import p2p.callback;
                        stream.listen(&StdHandlerCallback, "p2ptagion", opts.transaction.host.timeout.msecs, opts.transaction.host.max_size);
                        // log("add stream to connection pool %d", streamId);
                        connectionPool.add(streamId, stream, true);
                        connectionPoolBridge.lookup[channel] = streamId;
                    }
                );
            }else{
                log("Can't send: Discovery service is not running");
            }
        }

        try{
            log("send to:%d", streamId);
            auto sended = connectionPool.send(streamId, data);
            if(!sended){
                log("\n\n\n not sended \n\n\n");
            }
        }
        catch(Exception e){
            log.fatal(e.msg);
            ownerTid.send(channel);
        }
    }
    auto stop = false;
    do{
        // log("handling %s", thisTid);
        receive(
            (immutable(Pubkey) channel, Buffer data, uint id){
                // log("received sender %d", id);
                try{
                    send_to_channel(channel, data);
                }catch(Exception e){
                    log("Error on sending to channel: %s", e.msg);
                    ownerTid.send(channel);
                }
            },
            (Pubkey channel, uint id){
                log("Closing connection: %s", channel.cutHex);
                try{
                    auto streamIdPtr = channel in connectionPoolBridge.lookup;
                    if(streamIdPtr !is null){
                        const streamId = *streamIdPtr;
                        log("connection to close: %d", streamId);
                        connectionPool.close(streamId);
                        connectionPoolBridge.lookup.remove(channel);
                    }
                }catch(Exception e){
                    log("SDERROR: %s", e.msg);
                }
            },
            (Control control){
                // log("received control");
                if(control==Control.STOP){
                    stop = true;
                }
            }
        );
    }while(!stop);
}
