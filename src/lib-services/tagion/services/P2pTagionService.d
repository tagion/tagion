module tagion.services.P2pTagionService;

import core.thread;
import std.concurrency;

import std.datetime: Clock;
import tagion.Options;

import tagion.utils.Random;

import tagion.GlobalSignals : abort;

import tagion.basic.Basic : Pubkey, Payload, Control, nameOf;
import tagion.basic.Logger;
import tagion.services.TagionService;
import tagion.gossip.EmulatorGossipNet;
import tagion.gossip.InterfaceNet : SecureNet;
import tagion.gossip.GossipNet : StdSecureNet;
import tagion.ServiceNames : get_node_name;
import tagion.basic.TagionExceptions;
import p2plib = p2p.node;
import p2p.connection;
import p2p.callback;
import p2p.cgo.helper;
import tagion.services.DartSynchronizeService;
import tagion.dart.DARTSynchronization;
import tagion.dart.DART;
import std.conv;
import tagion.gossip.P2pGossipNet;
import tagion.communication.Monitor;
import tagion.services.MonitorService;
import tagion.services.TransactionService;
import tagion.services.TranscriptService;
import tagion.Options : Options, setOptions, options;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;

import tagion.utils.Miscellaneous: cutHex;
import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraph;
import tagion.basic.ConsensusExceptions;
import tagion.gossip.InterfaceNet;
import tagion.gossip.EmulatorGossipNet;
import tagion.basic.TagionExceptions : TagionException;

import tagion.services.ScriptCallbacks;
import tagion.services.FileDiscoveryService;
import tagion.services.ServerFileDiscoveryService;
import tagion.services.NetworkRecordDiscoveryService;
import tagion.gossip.P2pGossipNet: AddressBook;
import tagion.services.DartService;
import tagion.Keywords: NetworkMode;
import std.stdio;

void p2pTagionService(Options opts)
    in{
        import std.algorithm: canFind;
        assert([NetworkMode.local, NetworkMode.pub].canFind(opts.net_mode));
    }
do {
    setOptions(opts);

    immutable task_name="p2ptagion";
    opts.node_name = task_name;
    log.register(task_name);
    scope(exit) {
        log("----- Stop all tasks -----");
        log.close;
        ownerTid.prioritySend(Control.END);
    }

    bool force_stop = false;

    auto sector_range = DART.SectorRange(opts.dart.from_ang, opts.dart.to_ang);
    import std.array: replace, split;
    import std.string: indexOf;
    import std.file: mkdir, exists;
    import std.format;
    auto p2pnode = new shared(p2plib.Node)(format("/ip4/%s/tcp/%s",opts.ip, to!string(opts.port)), 0);
    if(opts.p2plogs){
        p2plib.EnableLogger();
    }

    enum dir_token = "%dir%";
    if(opts.dart.path.indexOf(dir_token) != -1){
        const i = opts.port - opts.port_base;
        immutable node_name="node"~i.to!string;
        auto path_to_dir = opts.dart.path[0..opts.dart.path.indexOf(dir_token)]~node_name;
        if(!path_to_dir.exists) path_to_dir.mkdir;
        opts.dart.path = opts.dart.path.replace(dir_token, node_name);
    }
    auto master_net=new StdSecureNet;
    P2pGossipNet net;
    auto hashgraph=new HashGraph();
    auto connectionPool = new shared(ConnectionPool!(shared p2plib.Stream, ulong))();
    auto connectionPoolBridge = new shared(ConnectionPoolBridge)();
    // connectionPoolBridge[Pubkey([0])] = 0;
    Tid discovery_tid;
    Tid dart_sync_tid;
    Tid dart_tid;
    synchronized(master_net) {
        import std.format;
        immutable passphrase=format("Secret_word_%d", opts.port).idup;

        master_net.generateKeyPair(passphrase);
        shared shared_net=cast(shared)master_net;
        net=new P2pGossipNet(hashgraph, opts, p2pnode, connectionPool, connectionPoolBridge);
        net.drive("tagion_service", shared_net);
        hashgraph.request_net=net;
        log("\n\n\n\nMY PUBKEY: %s \n\n\n\n", net.pubkey.cutHex);

        discovery_tid = spawn(&networkRecordDiscoveryService, net.pubkey, p2pnode, cast(immutable HashNet) net, opts.discovery.task_name, opts);
        receiveOnly!Control;
        discovery_tid.send(DiscoveryRequestCommand.RequestTable);

        receive(
            (immutable(AddressBook!Pubkey) address_book){
                auto pkeys = cast(immutable) address_book.data.keys;
                // net.set(pkeys);
                dart_sync_tid = spawn(&dartSynchronizeServiceTask!StdSecureNet, opts, p2pnode, shared_net, sector_range);
                // receiveOnly!Control;
                dart_tid = spawn(&dartServiceTask!StdSecureNet, opts, p2pnode, shared_net, sector_range);
                log("address_book len: %d", address_book.data.length);
                send(dart_sync_tid, cast(immutable) address_book);
            },
            (Control ctrl){
                if(ctrl is Control.STOP){
                    force_stop = true;
                }

                if(ctrl is Control.END){
                    force_stop = true;
                }
            }
            );
    }
    scope(exit){
        log("Closing net");
        net.close();
    }
    if(force_stop) return;

    if(opts.hostbootrap.enabled){
        if(opts.hostbootrap.bootstrapNodes.length){
            auto bootsraps = opts.hostbootrap.bootstrapNodes.split("\n");
            foreach(bootsrap; bootsraps){
                log("Connection to %s", bootsrap);
                p2pnode.connect(bootsrap);
            }
        }else{
            log.error("List of bootstrap nodes missing");
            force_stop = true;
        }
    }
    if(force_stop) return;
    bool ready =false;
    int ready_counter = 0;
    do{
        receive(
            (Control ctrl){
                log("Received ctrl: %s", ctrl);
                if(ctrl is Control.LIVE){
                    ready_counter++;
                }
                else if(ctrl is Control.STOP){
                    force_stop = true;
                }
            },
            (DartSynchronizeState state){
                if(state == DartSynchronizeState.READY){
                    ready = true;
                }
            });
        if(force_stop) return;
    }while(!ready||ready_counter!=2);
    log("Ready: %s", ready);


    discovery_tid.send(DiscoveryRequestCommand.BecomeOnline);
    scope(exit){
        discovery_tid.send(DiscoveryRequestCommand.BecomeOffline);
    }
    receive((DicvoryControl ctr){
        assert(ctr == DicvoryControl.READY);
    });

    discovery_tid.send(DiscoveryRequestCommand.RequestTable);
    receive((immutable(AddressBook!Pubkey) address_book) {
        auto pkeys = cast(immutable) address_book.data.keys;
        net.set(pkeys);
    });

    Tid monitor_socket_tid;
    Tid transaction_socket_tid;
    Tid transcript_tid;
    scope(exit){
        log("close listener");
        p2pnode.closeListener(opts.transaction.protocol_id);
    }
    scope(exit) {
        log("!!!==========!!!!!! Existing %s", opts.node_name);

        if ( net.transcript_tid != net.transcript_tid.init ) {
            log("Send stop to %s", opts.transcript.task_name);
            net.transcript_tid.prioritySend(Control.STOP);
            if ( receiveOnly!Control is Control.END ) {
                log("Scripting api end!!");
            }
        }

        if(discovery_tid!=Tid.init){
            log("Send stop to %s", opts.discovery.task_name);
            discovery_tid.prioritySend(Control.STOP);
            if ( receiveOnly!Control is Control.END ) {
                log("Discovery service stoped");
            }
        }

        if(dart_sync_tid!=Tid.init){
            log("Send stop to %s", opts.dart.sync.task_name);
            dart_sync_tid.prioritySend(Control.STOP);
            if ( receiveOnly!Control is Control.END ) {
                log("Dart synchronization service stoped");
            }
        }
        log("DART TID: %s", dart_tid);
        if(dart_tid!=Tid.init){
            log("Send stop to %s", opts.dart.task_name);
            dart_tid.prioritySend(Control.STOP);
            if ( receiveOnly!Control is Control.END ) {
                log("Dart service stoped");
            }
        }
        // log("Send stop to the engine");

        // if ( Event.scriptcallbacks ) {
        //     if ( Event.scriptcallbacks.stop && (receiveOnly!Control == Control.END) ) {
        //         log("Scripting engine end!!");
        //     }
        // }

        if ( net.callbacks ) {
            net.callbacks.exiting(hashgraph.getNode(net.pubkey));
        }

        // version(none)
        if ( transaction_socket_tid != transaction_socket_tid.init ) {
            log("send stop to %s", opts.transaction.task_name);
            transaction_socket_tid.prioritySend(Control.STOP);
            auto control=receiveOnly!Control;
            log("Control %s", control);
            if ( control is Control.END ) {
                log("Closed transaction");
            }
            // else if ( control is Control.FAIL ) {
            //     log.error("Closed transaction with failure");
            // }
        }

        if ( monitor_socket_tid != monitor_socket_tid.init ) {
            log("send stop to %s", opts.monitor.task_name);
//            try {
            monitor_socket_tid.prioritySend(Control.STOP);

            receive(
                (Control ctrl) {
                    if ( ctrl is Control.END ) {
                        log("Closed monitor");
                    }
                    // else if ( ctrl is Control.FAIL ) {
                    //     log.error("Closed monitor with failure");
                    // }
                },
                (immutable Exception e) {
                    ownerTid.prioritySend(e);
                });
        }


        log("End");
        ownerTid.prioritySend(Control.END);
    }


    hashgraph.createNode(net.pubkey);
    foreach(i, p; net.pkeys) {
        if ( hashgraph.createNode(p) ) {
            log("%d] %s", i, p.cutHex);
        }
    }
    hashgraph.dumpNodes();
//     log("BEFORE DELAY");
// import core.time;
//     Thread.sleep(10.seconds);
//     log("after DELAY");

    try{
        monitor_socket_tid = spawn(&monitorServiceTask, opts);
        Event.callbacks = new MonitorCallBacks(monitor_socket_tid, opts.node_id, net.globalNodeId(net.pubkey), opts.monitor.dataformat);
        stderr.writefln("@@@@ Wait for monitor %s", opts.node_name,);

        if ( receiveOnly!Control is Control.LIVE ) {
            log("Monitor started");
        }
        transaction_socket_tid = spawn(&transactionServiceTask, opts);
        if ( receiveOnly!Control is Control.LIVE ) {
            log("Transaction started port %d", opts.transaction.service.port);
        }else{
            log("bad command");
        }
    }
    catch(Exception e){
        log("ERROR: %s", e.msg);
        force_stop = true;
    }
    if(force_stop) return;
    Event.scriptcallbacks=new ScriptCallbacks(&transcriptServiceTask, opts.transcript.task_name, opts.dart.task_name);
    scope(exit) {
        Event.scriptcallbacks.stop;
    }

    // transcript_tid=spawn(&transcriptServiceTask, opts);
    // Event.scriptcallbacks=new ScriptCallbacks(transcript_tid);
    // scope(exit) {
    //     Event.scriptcallbacks.stop;
    // }
    //     if ( receiveOnly!Control is Control.LIVE ) {
    //         log("Transcript started");
    //     }
    enum max_gossip=1;
    uint gossip_count=max_gossip;
    bool stop=false;
    // // True of the network has been initialized;
    // bool initialised=false;
    enum timeout_end=10;
    uint timeout_count;
    //    Event mother;
    Event event;
    auto own_node=hashgraph.getNode(net.pubkey);
    log("Wait for some delay %s", opts.node_name);
    //    Thread.sleep(2.seconds);

    auto net_random=cast(P2pGossipNet)net;
    enum bool has_random_seed=__traits(compiles, net_random.random.seed(0));
    //    pragma(msg, has_random_seed);
    static if ( has_random_seed ) {
        //        pragma(msg, "Random seed works");
        if ( !opts.sequential ) {
            net_random.random.seed(cast(uint)(Clock.currTime.toUnixTime!int));
        }
    }
    Payload empty_payload;

    immutable(ubyte)[] data;

    void receive_buffer(const(Document) doc) {
        try{
            timeout_count=0;
            net.time=net.time+100;
            log("\n*\n*\n*\n******* receive %s [%s] %s", opts.node_name, opts.node_id, doc.data.length);
//            auto own_node=hashgraph.getNode(net.pubkey);

            // version(none)
            // Event register_leading_event(immutable(ubyte)[] father_fingerprint) @safe {
            //     auto mother=own_node.event;
            //     immutable ebody=immutable(EventBody)(empty_payload, mother.fingerprint,
            //         father_fingerprint, net.time, mother.altitude+1);
            //     const epack=net.buildPackage(ebody.toHiBON, ExchangeState.NONE);
            //     // immutable signature=net.sign(ebody);
            //     return hashgraph.registerEvent(epack);
            // }
            net.receive(doc);
        }
        catch(Exception e){
            log("Exception: %s", e.msg);
        }
        catch(Throwable t){
            log("THROWABLE: %s\n%s", t.msg, t.info);
        }
    }

    void next_mother(Payload payload) {
        try{
            log("next mother %d", gossip_count);
            auto own_node=hashgraph.getNode(net.pubkey);
            if ( (gossip_count >= max_gossip) || (payload.length) ) {
                // fout.writeln("After build wave front");
                if ( own_node.event is null ) {
                    immutable ebody=EventBody.eva(net);
                    immutable epack=new immutable(EventPackage)(net, ebody);
                    // const ebody_hibon = ebody.toHiBON;
                    // const pack=net.buildPackage(ebody_hibon, ExchangeState.NONE);
                    // immutable signature=net.sign(ebody);
                    //event=hashgraph.registerEvent(net.pubkey, pack.signature, ebody);
                    event=hashgraph.registerEvent(epack);
                }
                else {
                    auto mother=own_node.event;
                    immutable mother_hash=mother.fingerprint;
                    immutable ebody=immutable(EventBody)(payload, mother_hash, null, net.time, mother.altitude+1);
                    immutable epack=new immutable(EventPackage)(net, ebody);
                    // const pack=net.buildPackage(ebody.toHiBON, ExchangeState.NONE);
                    //immutable signature=net.sign(ebody);
                    // event=hashgraph.registerEvent(net.pubkey, pack.signature, ebody);
                    event=hashgraph.registerEvent(epack);
                }
                immutable send_channel=net.selectRandomNode;
                auto send_node=hashgraph.getNode(send_channel);
                log("selected %s STATE: %s, is in pool: %s", send_node.pubkey.cutHex ,send_node.state, connectionPoolBridge.contains(send_node.pubkey));
                if ( send_node.state is ExchangeState.NONE && !connectionPoolBridge.contains(send_node.pubkey)) {
                    send_node.state = ExchangeState.INIT_TIDE;
                    auto tidewave   = new HiBON;
                    auto tides      = net.tideWave(tidewave, net.callbacks !is null);
                    auto pack_doc   = net.buildPackage(tidewave, ExchangeState.TIDAL_WAVE);
                    net.send(send_channel, pack_doc);
                    if ( net.callbacks ) {
                        net.callbacks.sent_tidewave(send_channel, tides);
                    }
                }
                gossip_count=0;
            }
            else {
                gossip_count++;
            }
        }catch(Exception e){
            log("Exception: %s", e.msg);
        }
        catch(Throwable t){
            log("THROWABLE1: %s\n%s", t.msg, t.info);
        }
    }

    void receive_payload(Payload pload) {
        log("payload.length=%d", pload.length);
        next_mother(pload);
    }

    void controller(Control ctrl) {
        with(Control) switch(ctrl) {
            case STOP:
                stop=true;
                writefln("##### Stop %s", opts.node_name);
                log("##### Stop %s", opts.node_name);
                break;
            case LIVE: break;
            default:
                log.error("Unsupported control %s", ctrl);
            }
    }

    void tagionexception(immutable(TagionException) e) {
        ownerTid.send(e);
    }

    void exception(immutable(Exception) e) {
        ownerTid.send(e);
    }

    void throwable(immutable(Throwable) t) {
        ownerTid.send(t);
    }

    static if (has_random_seed) {
        void sequential(uint time, uint random)
            in {
                assert(opts.sequential);
            }
        do {
            immutable(ubyte[]) payload;
            net_random.random.seed(random);
            net_random.time=time;
            next_mother(empty_payload);
        }
    }

    p2pnode.listen(opts.transaction.protocol_id, &StdHandlerCallback, cast(string) task_name, opts.dart.sync.host.timeout.msecs, cast(uint) opts.dart.sync.host.max_size);

    // ownerTid.send(Control.LIVE);
    while(!stop && !abort)  {
        try{
            immutable message_received=receiveTimeout(
                opts.timeout.msecs,
                &receive_payload,
                &controller,
                // &sequential,
                &receive_buffer,
                &tagionexception,
                &exception,
                &throwable,
                (Response!(ControlCode.Control_Connected) resp) {
                    log("Client Connected key: %d", resp.key);
                    connectionPool.add(resp.key, resp.stream, true);
                },
                (Response!(ControlCode.Control_Disconnected) resp) {
                    log("Client Disconnected key: %d", resp.key);
                    connectionPool.close(cast(void*)resp.key);
                    connectionPoolBridge.removeConnection(resp.key);
                },
                (Response!(ControlCode.Control_RequestHandled) resp){
                    import tagion.hibon.Document;
                    import tagion.hibon.HiBONJSON;
                    auto doc=Document(resp.data);
                    Pubkey received_pubkey=doc[Event.Params.pubkey].get!(immutable(ubyte)[]);
                    connectionPoolBridge.lookup[received_pubkey] = resp.stream.Identifier;
                    // log("response: %s", doc.toJSON);
                    log("received in: %s", resp.stream.Identifier);
                    receive_buffer(doc);
                },
                (immutable(Pubkey) send_channel){ //On sending failed
                    log("Removing channel from net");
                    auto send_node=hashgraph.getNode(send_channel);
                    send_node.state = ExchangeState.NONE;
                    // auto pkeys = net.pkeys;  //Remove channel from net.pkeys
                    // import std.algorithm: remove, SwapStrategy, countUntil;
                    // auto i = pkeys.countUntil(send_channel);
                    // net.set(pkeys[0..i]~pkeys[i+1..$]);
                },
                (immutable(AddressBook!Pubkey) address_book){
                    auto pkeys = cast(immutable) address_book.data.keys;
                    net.set(pkeys);
                    foreach(i, p; net.pkeys) {
                        if ( hashgraph.createNode(p) ) {
                            log("%d] %s", i, p.cutHex);
                        }
                    }
                }
                );
            log("received: %s", message_received);
            log("MY PK: %s", net.pubkey.cutHex);

            if ( !message_received && net.pkeys.length > 1) {
                log("TIME OUT");
                writefln("TIME OUT %d", opts.node_id);
                timeout_count++;
                net.time=Clock.currTime.toUnixTime!long;
                if ( !net.queue.empty ) {
                    log("FROM QUEUE");
                    receive_buffer(net.queue.read);
                }
                next_mother(empty_payload);
            }
        }
        catch(Exception e){
            log.fatal(e.msg);
        }
    }
    log("stop: %s", stop);
}
