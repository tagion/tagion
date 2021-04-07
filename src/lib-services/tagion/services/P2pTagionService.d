module tagion.services.P2pTagionService;

import core.thread;
import std.concurrency;

import std.datetime: Clock;
import std.conv;
import std.algorithm.searching: canFind;

import p2plib = p2p.node;
//import p2p.connection;
import p2p.callback;
import p2p.cgo.helper;

import tagion.Options : Options, setOptions, options, OptionException;
import tagion.utils.Random;
import tagion.utils.Queue;
import tagion.GlobalSignals : abort;

import tagion.basic.Basic : Pubkey, Control, nameOf, Buffer;
import tagion.basic.Logger;
import tagion.hashgraph.Event : Event;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.HashGraphBasic : EventBody, ExchangeState, Wavefront;

import tagion.services.TagionService;
import tagion.gossip.EmulatorGossipNet;
import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.ServiceNames : get_node_name;
import tagion.basic.TagionExceptions;
import tagion.services.DartSynchronizeService;
import tagion.dart.DARTSynchronization;
import tagion.dart.DART;
import tagion.gossip.P2pGossipNet;
import tagion.gossip.InterfaceNet;
import tagion.gossip.EmulatorGossipNet;

import tagion.monitor.Monitor;
import tagion.services.MonitorService;
import tagion.services.TransactionService;
import tagion.services.TranscriptService;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.communication.HiRPC;

import tagion.utils.Miscellaneous: cutHex;
// import tagion.hashgraph.Event;
// import tagion.hashgraph.HashGraph;
import tagion.basic.ConsensusExceptions;
import tagion.basic.TagionExceptions : TagionException;

import tagion.services.ScriptCallbacks;
import tagion.services.FileDiscoveryService;
import tagion.services.ServerFileDiscoveryService;
import tagion.services.NetworkRecordDiscoveryService;
//mport tagion.gossip.P2pGossipNet: AddressBook;
import tagion.services.DartService;
import tagion.Keywords: NetworkMode;

import std.stdio;
import std.array : replace, split;
import std.string : indexOf;
import std.file : mkdir, exists;
import std.format;

shared(p2plib.Node) initialize_node(immutable Options opts){
    auto p2pnode = new shared(p2plib.Node)(format("/ip4/%s/tcp/%s", opts.ip,
        to!string(opts.port)), 0);
    if (opts.p2plogs)
    {
        p2plib.EnableLogger();
    }
    if (opts.hostbootrap.enabled)
    {
        if (opts.hostbootrap.bootstrapNodes.length)
        {
            auto bootsraps = opts.hostbootrap.bootstrapNodes.split("\n");
            foreach (bootsrap; bootsraps)
            {
                log("Connection to %s", bootsrap);
                p2pnode.connect(bootsrap);
            }
        }
        else
        {
            throw new OptionException("Bootstrap nodes list is empty");
        }
    }
    return p2pnode;
}

void tagionService(NetworkMode net_mode)(Options opts)
    in
    {
        import std.algorithm : canFind;
        assert([NetworkMode.internal, NetworkMode.local, NetworkMode.pub].canFind(opts.net_mode));
    }
do
{
    setOptions(opts);

    log.register(opts.node_name);
    scope (exit)
    {
        log("----- Stop all tasks -----");
        log.close;
        ownerTid.prioritySend(Control.END);
    }


    static if(net_mode == NetworkMode.internal){
        immutable passphrase=format("Secret_word_%s",opts.node_name).idup;
    }else{
        immutable passphrase = format("Secret_word_%d", opts.port).idup;
    }

    bool force_stop = false;

    import std.format;
    auto sector_range = DART.SectorRange(opts.dart.from_ang, opts.dart.to_ang);
    shared(p2plib.Node) p2pnode;
    string passpharse;
      
    auto master_net = new StdSecureNet;
    StdSecureNet net = new StdSecureNet;
    GossipNet gossip_net;
    HashGraph hashgraph; // = new HashGraph(opts.nodes);

    Tid discovery_tid;
    Tid dart_sync_tid;
    Tid dart_tid;
    Pubkey[] pkeys;
    void update_pkeys(Pubkey[] pubkeys){
        if(net_mode != NetworkMode.internal){
            pkeys = pubkeys;
            foreach(p; pkeys) gossip_net.add_channel(p);
        }
    }
      
    synchronized (master_net)
    {
        import std.format;

        immutable secret = passpharse.idup;

        master_net.generateKeyPair(secret);
        shared shared_net = cast(shared) master_net;
        log("opts.node_name = %s", opts.node_name);
        net.derive(opts.node_name, shared_net);
        p2pnode = initialize_node(opts);
        static if(net_mode == NetworkMode.internal){
            gossip_net = new EmulatorGossipNet();
            ownerTid.send(net.pubkey);
            Pubkey[] received_pkeys;
            foreach(i;0..opts.nodes) {
                received_pkeys~=receiveOnly!(Pubkey);
                log.trace("Receive %d %s", i, received_pkeys[i].cutHex);
            }
            import std.exception: assumeUnique;
            pkeys=received_pkeys.dup;
            foreach(p; pkeys) gossip_net.add_channel(p);
        }else if([NetworkMode.local, NetworkMode.pub].canFind(net_mode)){
            // immutable task_name = "p2ptagion";
            // opts.node_name = task_name;
            gossip_net = new P2pGossipNet(opts.node_name, opts.discovery.task_name, opts.host, p2pnode);
        }else{
            throw new OptionException("Unknown network mode");
        }
        // gossip_net = new P2pGossipNet(task_name, opts.discovery.task_name, opts.host, p2pnode);

        hashgraph=new HashGraph(opts.nodes, net, &gossip_net.isValidChannel, null);
        hashgraph.print_flag = true;
        log("\n\n\n\nMY PUBKEY: %s \n\n\n\n", net.pubkey.cutHex);

        
        discovery_tid = spawn(&networkRecordDiscoveryService, net.pubkey, p2pnode, opts.discovery.task_name, opts);
        auto ctrl = receiveOnly!Control;
        assert(ctrl == Control.LIVE);

        receive((DiscoveryState state){
            assert(state == DiscoveryState.READY);
        });
        discovery_tid.send(DiscoveryRequestCommand.RequestTable);
        receive((ActiveNodeAddressBook address_book) {
                update_pkeys(address_book.data.keys);
                dart_sync_tid = spawn(&dartSynchronizeServiceTask!StdSecureNet,
                    opts, p2pnode, shared_net, sector_range);
                // receiveOnly!Control;
                dart_tid = spawn(&dartServiceTask!StdSecureNet, opts, p2pnode,
                    shared_net, sector_range);
                log("address_book len: %d", address_book.data.length);
                send(dart_sync_tid, cast(immutable) address_book);
            }, (Control ctrl) {
                if (ctrl is Control.STOP)
                {
                    force_stop = true;
                }

                if (ctrl is Control.END)
                {
                    force_stop = true;
                }
            });
    }
    scope (exit)
    {
        log("Closing net");
        gossip_net.close();
    }
    if (force_stop) {
        return;
    }

    bool ready = false;
    int ready_counter = 0;
    do
    {
        receive((Control ctrl) {
                log("Received ctrl: %s", ctrl);
                if (ctrl is Control.LIVE)
                {
                    ready_counter++;
                }
                else if (ctrl is Control.STOP)
                {
                    force_stop = true;
                }
            }, (DartSynchronizeState state) {
                if (state == DartSynchronizeState.READY)
                {
                    ready = true;
                }
            });
        if (force_stop)
            return;
    }
    while (!ready || ready_counter != 2); // empty

    log("Ready: %s", ready);

    discovery_tid.send(DiscoveryRequestCommand.BecomeOnline);
    scope(exit){
        discovery_tid.send(DiscoveryRequestCommand.BecomeOffline);
    }
    receive((DiscoveryState state){
            assert(state == DiscoveryState.ONLINE);
        });

    discovery_tid.send(DiscoveryRequestCommand.RequestTable);
    receive((ActiveNodeAddressBook address_book) {
        update_pkeys(address_book.data.keys);
    });

    Tid monitor_socket_tid;
    Tid transaction_socket_tid;
    Tid transcript_tid;
    scope (exit)
    {
        log("close listener");
        p2pnode.closeListener(opts.transaction.protocol_id);
    }
    scope (exit)
    {
        log("!!!==========!!!!!! Existing %s", opts.node_name);

        if (transcript_tid != transcript_tid.init)
        {
            log("Send stop to %s", opts.transcript.task_name);
            transcript_tid.prioritySend(Control.STOP);
            if (receiveOnly!Control is Control.END)
            {
                log("Scripting api end!!");
            }
        }

        if (discovery_tid != Tid.init)
        {
            log("Send stop to %s", opts.discovery.task_name);
            discovery_tid.prioritySend(Control.STOP);
            if (receiveOnly!Control is Control.END)
            {
                log("Discovery service stoped");
            }
        }

        if (dart_sync_tid != Tid.init)
        {
            log("Send stop to %s", opts.dart.sync.task_name);
            dart_sync_tid.prioritySend(Control.STOP);
            if (receiveOnly!Control is Control.END)
            {
                log("Dart synchronization service stoped");
            }
        }
        log("DART TID: %s", dart_tid);
        if (dart_tid != Tid.init)
        {
            log("Send stop to %s", opts.dart.task_name);
            dart_tid.prioritySend(Control.STOP);
            if (receiveOnly!Control is Control.END)
            {
                log("Dart service stoped");
            }
        }
        // log("Send stop to the engine");

        // if ( Event.scriptcallbacks ) {
        //     if ( Event.scriptcallbacks.stop && (receiveOnly!Control == Control.END) ) {
        //         log("Scripting engine end!!");
        //     }
        // }

        // if (net.callbacks)
        // {
        //     net.callbacks.exiting(net.pubkey, hashgraph);
        // }

        // version(none)
        if (transaction_socket_tid != transaction_socket_tid.init)
        {
            log("send stop to %s", opts.transaction.task_name);
            transaction_socket_tid.prioritySend(Control.STOP);
            auto control = receiveOnly!Control;
            log("Control %s", control);
            if (control is Control.END)
            {
                log("Closed transaction");
            }
            // else if (control is Control.FAIL)
            // {
            //     log.error("Closed transaction with failure");
            // }
        }

        if (monitor_socket_tid != monitor_socket_tid.init)
        {
            log("send stop to %s", opts.monitor.task_name);
            //            try {
            monitor_socket_tid.prioritySend(Control.STOP);

            receive((Control ctrl) {
                    if (ctrl is Control.END)
                    {
                        log("Closed monitor");
                    }
                    // else if (ctrl is Control.FAIL)
                    // {
                    //     log.error("Closed monitor with failure");
                    // }
                }, (immutable Exception e) { ownerTid.prioritySend(e); });
        }

        log("End");
        ownerTid.prioritySend(Control.END);
    }

    // hashgraph.createNode(net.pubkey);
    // foreach (i, p; net.pkeys)
    // {
    //     if (hashgraph.createNode(p))
    //     {
    //         log("%d] %s", i, p.cutHex);
    //     }
    // }
    //     log("BEFORE DELAY");
    // import core.time;
    //     Thread.sleep(10.seconds);
    //     log("after DELAY");

    try
    {
        monitor_socket_tid = spawn(&monitorServiceTask, opts);
        // Event.callbacks = new MonitorCallBacks(monitor_socket_tid, opts.node_id,
        //         net.globalNodeId(net.pubkey), opts.monitor.dataformat);
        stderr.writefln("@@@@ Wait for monitor %s", opts.node_name,);

        if (receiveOnly!Control is Control.LIVE)
        {
            log("Monitor started");
        }
        transaction_socket_tid = spawn(&transactionServiceTask, opts);
        if (receiveOnly!Control is Control.LIVE)
        {
            log("Transaction started port %d", opts.transaction.service.port);
        }
        else
        {
            log("bad command");
        }
    }
    catch (Exception e)
    {
        log("ERROR: %s", e.msg);
        force_stop = true;
    }
    if (force_stop)
        return;
    transcript_tid = spawn(&transcriptServiceTask, opts.transcript.task_name, opts.dart.sync.task_name);
    // Event.scriptcallbacks=new ScriptCallbacks(&transcriptServiceTask, opts.transcript.task_name, opts.dart.task_name);
    // scope(exit) {
    //     Event.scriptcallbacks.stop;
    // }
    enum max_gossip = 2;
    uint gossip_count = max_gossip;
    bool stop = false;
    // // True of the network has been initialized;
    // bool initialised=false;
    enum timeout_end = 10;
    uint timeout_count;
    //    Event mother;
    Event event;
    //    Thread.sleep(2.seconds);
    // auto net_random = cast(P2pGossipNet) net;
    // enum bool has_random_seed = __traits(compiles, net_random.random.seed(0));
    // //    pragma(msg, has_random_seed);
    // version(none)
    //     static if (has_random_seed)
    // {
    //     //        pragma(msg, "Random seed works");
    //     if (!opts.sequential)
    //     {
    //         net_random.random.seed(cast(uint)(Clock.currTime.toUnixTime!int));
    //     }
    // }
//    const empty_payload=Document();
    // Document empty_payload_func(){
    //     return empty_payload;
    // }
    immutable(ubyte)[] data;


    {
        immutable buf=cast(Buffer)hashgraph.channel;
        const nonce=net.calcHash(buf);
        auto eva_event=hashgraph.createEvaEvent(gossip_net.time, nonce);

        if (eva_event is null) {
            log.error("The channel of this oner is not valid");
            return;
        }
    }


    alias PayloadQueue=Queue!Document;
    PayloadQueue payload_queue = new PayloadQueue();
    void receive_payload(const Document pload, bool flag) { //TODO: remove flag. Maybe try switch(doc.type)
        log.trace("payload.size=%d", pload.size);
        payload_queue.write(pload);
    }

    Document payload() @safe {
        if (!hashgraph.active || payload_queue.empty) {
            return Document();
        }
        return payload_queue.read;
    }

    void controller(Control ctrl) {
        log("Ctrl: %s", ctrl);
        with (Control) {
            switch (ctrl) {
            case STOP:
                stop = true;
                log("##### Stop %s", opts.node_name);
                break;
            case LIVE:
                break;
            default:
                log.error("Unsupported control %s", ctrl);
            }
        }
    }

    void receive_wavefront(const Document doc) {
        timeout_count=0;
        log("\n*\n*\n*\n******* receive %s [%s] %s", opts.node_name, opts.node_id, doc.data.length);
        const receiver = HiRPC.Receiver(doc);
        hashgraph.wavefront(
            receiver,
            gossip_net.time,
            (const(HiRPC.Sender) return_wavefront) @safe {
                gossip_net.send(receiver.pubkey, return_wavefront);
            },
            &payload
            );
    }

    version(none) {
        void tagionexception(immutable(TagionException) e)
        {
            log("Exception: %s", e.msg);
            ownerTid.send(e);
        }

        void exception(immutable(Exception) e)
        {
            log("Exception: %s", e.msg);
            ownerTid.send(e);
        }

        void throwable(immutable(Throwable) t)
        {
            log("Throwable: %s", t.msg);
            ownerTid.send(t);
        }
    }

    // version(none)
    //     static if (has_random_seed)
    // {
    //     void sequential(uint time, uint random)
    //         in
    //         {
    //             assert(opts.sequential);
    //         }
    //     do
    //     {
    //         immutable(ubyte[]) payload;
    //         net_random.random.seed(random);
    //         net_random.time = time;
    //         next_mother(empty_payload);
    //     }
    // }

    import tagion.utils.Random;
    Random!size_t random;
    random.seed(123456789);
    // ownerTid.send(Control.LIVE);
    // auto iteration = 0;
    while (!stop && !abort) {
        // log("Iteration %d", iteration);
        // if(iteration % 20 == 0) {
        //     log("Send request table to discovery");
        //     discovery_tid.send(DiscoveryRequestCommand.RequestTable);
        // }
        // iteration++;
        try {
            immutable message_received = receiveTimeout(opts.timeout.msecs,
                &receive_payload,
                &controller,
                &receive_wavefront,
                &taskfailure,
                //&tagionexception, &exception, &throwable,
                /*
                (Response!(ControlCode.Control_Connected) resp) {
                    log("Client Connected key: %d", resp.key);
                    connectionPool.add(resp.key, resp.stream, true);
                },
                (Response!(ControlCode.Control_Disconnected) resp) {
                    synchronized(connectionPoolBridge){
                        log("Client Disconnected key: %d", resp.key);
                        connectionPool.close(cast(void*) resp.key);
                        connectionPoolBridge.removeConnection(resp.key);
                    }
                },

                (Response!(ControlCode.Control_RequestHandled) resp) {
                    import tagion.hibon.Document;
                    import tagion.hibon.HiBONJSON;
                    pragma(msg, "fixme(Alex): resp.data can't it be a document (Because or else Document isInOrder need to be called here. It is better to verify that the Document is correct inside the Response");
                    auto doc = Document(resp.data);
                    Pubkey received_pubkey = doc[Event.Params.pubkey].get!(immutable(ubyte)[]);
                    if ((received_pubkey in connectionPoolBridge.lookup) !is null)
                    {
                        log("previous cpb: %d, now: %d",
                            connectionPoolBridge.lookup[received_pubkey], resp.stream.Identifier);
                    }
                    else
                    {
                        connectionPoolBridge.lookup[received_pubkey] = resp.stream.Identifier;
                    }
                    // log("response: %s", doc.toJSON);
                    log("received in: %s", resp.stream.Identifier);
                    receive_buffer(Document(resp.data));
                },
                */
                // (immutable(Pubkey) send_channel) { //On sending failed
                //     log("Removing channel from net");
                //     auto send_node = hashgraph.getNode(send_channel);
                //     send_node.state = ExchangeState.NONE;
                // },
                (ActiveNodeAddressBook address_book) {
                    log("Update address book");
                    update_pkeys(address_book.data.keys);
                    if (dart_sync_tid!=Tid.init){
                        send(dart_sync_tid, address_book);
                    }
                    else {
                        log("Dart sync not found");
                    }
                    // foreach (p; net.pkeys) {
                    //     // if (hashgraph.createNode(p)) {
                    //     //     log("%d] %s", i, p.cutHex);
                    //     // }
                    // }
                });
            // log("received: %s", message_received);
            // log("MY PK: %s, net.pkeys.len: %d, cpb len: %d", net.pubkey.cutHex,
            //     net.pkeys.length, connectionPoolBridge.lookup.length);

            if (!message_received) {
                const onLine=hashgraph.areWeOnline;
                pragma(msg, "Replace with a realy random");
                const init_tide=random.value(0,2) is 1;
                    // log("online: %s init?: %s", onLine, init_tide);
                if (onLine && init_tide) {
                    log("init_tide");
                    hashgraph.init_tide(&gossip_net.gossip, &payload, gossip_net.time);
                }
            }
        }
        catch (Exception e) {
            log.fatal(e.msg);
        }
    }
    log("stop: %s", stop);
}
