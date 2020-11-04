module tagion.gossip.P2pGossipNet;

import std.stdio;
import std.concurrency;
import std.format;
import std.array : join;
import std.conv : to;
import std.file;
import std.file: fwrite = write;

import tagion.revision;
import tagion.Options;
import tagion.basic.Basic : EnumText, Buffer, Pubkey, Payload, buf_idup,  basename, isBufferType, Control;
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
import tagion.hashgraph.ConsensusExceptions;

import tagion.services.LoggerService;
import tagion.services.ServiceNames : get_node_name;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.services.MdnsDiscoveryService;
import p2plib = p2p.node;
import p2p.connection;
import std.array;
import tagion.services.P2pTagionService;

import std.datetime;

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
        import std.concurrency: tsend=send, prioritySend, Tid, locate;
        auto sender = locate(opts.transaction.net_task_name);
        if(sender!=Tid.init){
            counter++;
            // log("sending to sender %d", counter);
            tsend(sender, channel, data, counter);
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

    override Event receive(immutable(ubyte[]) data,
    Event delegate(immutable(ubyte)[] father_fingerprint) @safe register_leading_event ) {
        log("received time: %s", Clock.currTime().toUTC());
        // log("1.receive");
        auto doc=Document(data);
        immutable type=doc[Params.type].get!uint;
        immutable received_state=convertState(type);
        Pubkey received_pubkey=doc[Event.Params.pubkey].get!(immutable(ubyte)[]);

        // log("2.receive");
        auto result = super.receive(data, register_leading_event);
        import std.algorithm: canFind;

        log("3.receive");
        if([/*ExchangeState.FIRST_WAVE,*/ ExchangeState.SECOND_WAVE, ExchangeState.BREAKING_WAVE].canFind(received_state)){
            log("send remove with state: %s", received_state);
            send_remove(received_pubkey);
        }
        return result;
    }


    private uint eva_count;

    Payload evaPackage() {
        eva_count++;
        auto hibon=new HiBON;
        hibon["pubkey"]=pubkey;
        hibon["git"]=HASH;
        hibon["nonce"]="Should be implemented:"~to!string(eva_count);
        return Payload(hibon.serialize);
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
                        stream.listen(&StdHandlerCallback, "p2ptagion");
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
