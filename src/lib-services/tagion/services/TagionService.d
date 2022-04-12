module tagion.services.TagionService;

import core.thread;
import std.concurrency;

import std.datetime : Clock;
import tagion.utils.StdTime;

import std.conv;
import std.algorithm.searching : canFind;

import p2plib = p2p.node;

//import p2p.connection;
import p2p.callback;
import p2p.cgo.c_helper;

import tagion.services.Options : Options, setOptions, options, OptionException, NetworkMode;
import tagion.utils.Random;
import tagion.utils.Queue;
import tagion.GlobalSignals : abort;

import tagion.basic.Basic : Pubkey, Control, nameOf, Buffer;
import tagion.logger.Logger;
import tagion.hashgraph.Event : Event;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.HashGraphBasic : EventBody, ExchangeState, Wavefront;

import tagion.services.TagionService;
import tagion.gossip.EmulatorGossipNet;
import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.options.ServiceNames : get_node_name;
import tagion.basic.TagionExceptions;
import tagion.services.DARTSynchronizeService;
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

import tagion.utils.Miscellaneous : cutHex;

import tagion.basic.ConsensusExceptions;
import tagion.basic.TagionExceptions : TagionException;

import tagion.services.ScriptCallbacks;
import tagion.services.FileDiscoveryService;
import tagion.services.ServerFileDiscoveryService;
import tagion.services.NetworkRecordDiscoveryService;

//mport tagion.gossip.P2pGossipNet: AddressBook;
import tagion.services.DARTService;

//import tagion.Keywords : NetworkMode;

import std.stdio;
import std.array : replace, split;
import std.string : indexOf;
import std.file : mkdir, exists;
import std.format;

shared(p2plib.Node) initialize_node(immutable Options opts) {
    auto p2pnode = new shared(p2plib.Node)(
            format("/ip4/%s/tcp/%s",
            opts.ip,
            opts.port), 0);
    log("initialize_node");
    scope (exit) {
        log("END initialize_node");

    }
    if (opts.p2plogs) {
        p2plib.EnableLogger();
    }
    if (opts.hostbootrap.enabled) {
        if (opts.hostbootrap.bootstrapNodes.length) {
            auto bootsraps = opts.hostbootrap.bootstrapNodes.split("\n");
            foreach (bootsrap; bootsraps) {
                log("Connection to %s", bootsrap);
                p2pnode.connect(bootsrap);
            }
        }
        else {
            throw new OptionException("Bootstrap nodes list is empty");
        }
    }
    return p2pnode;
}

void tagionService(NetworkMode net_mode)(Options opts) nothrow {
    //     in {
    //         import std.algorithm : canFind;

    //         assert([NetworkMode.internal, NetworkMode.local, NetworkMode.pub].canFind(opts.net_mode));
    //     }
    // do {
    try {
        setOptions(opts);

        log.register(opts.node_name);
        scope (success) {
            log.close;
            ownerTid.prioritySend(Control.END);
        }

        static if (net_mode == NetworkMode.internal) {
            immutable passpharse = format("Secret_word_%s", opts.node_name).idup;
        }
        else {
            immutable passpharse = format("Secret_word_%d", opts.port).idup;
        }

        bool force_stop = false;

        import std.format;

        auto sector_range = DART.SectorRange(opts.dart.from_ang, opts.dart.to_ang);
        shared(p2plib.Node) p2pnode;
        // string passpharse;

        auto master_net = new StdSecureNet;
        StdSecureNet net = new StdSecureNet;
        GossipNet gossip_net;
        ScriptCallbacks scriptcallbacks;
        HashGraph hashgraph; // = new HashGraph(opts.nodes);

        Tid discovery_tid;
        Tid dart_sync_tid;
        Tid dart_tid;
        Tid monitor_socket_tid;
        Tid transaction_socket_tid;
        Tid transcript_tid;
        Pubkey[] pkeys;
        void update_pkeys(Pubkey[] pubkeys) {
            if (net_mode != NetworkMode.internal) {
                pkeys = pubkeys;
                foreach (p; pkeys)
                    gossip_net.add_channel(p);
            }
        }

        synchronized (master_net) {
            import std.format;

            immutable secret = passpharse.idup;

            master_net.generateKeyPair(secret);
            shared shared_net = cast(shared) master_net;
            log("opts.node_name = %s", opts.node_name);
            net.derive(opts.node_name, shared_net);
            p2pnode = initialize_node(opts);
            final switch(net_mode) {
            case NetworkMode.internal:
                gossip_net = new EmulatorGossipNet(net.pubkey, opts.timeout.msecs);
                ownerTid.send(net.pubkey);
                Pubkey[] received_pkeys;
                foreach (i; 0 .. opts.nodes) {
                    received_pkeys ~= receiveOnly!(Pubkey);
                    log.trace("Receive %d %s", i, received_pkeys[i].cutHex);
                }
                import std.exception : assumeUnique;

                pkeys = received_pkeys.dup;
                foreach (p; pkeys)
                    gossip_net.add_channel(p);
                ownerTid.send(Control.LIVE);
                break;
            case NetworkMode.local:
            case NetworkMode.pub:
            // else if ([NetworkMode.local, NetworkMode.pub].canFind(net_mode)) {
                // immutable task_name = "p2ptagion";
                // opts.node_name = task_name;
                gossip_net = new P2pGossipNet(net.pubkey, opts.node_name,
                        opts.discovery.task_name, opts.host, p2pnode);
            // }
            // else {
            //     throw new OptionException("Unknown network mode");
            }
            // gossip_net = new P2pGossipNet(task_name, opts.discovery.task_name, opts.host, p2pnode);
            void receive_epoch(const(Event)[] events, const sdt_t epoch_time) @trusted {
                import std.algorithm;
                import std.array : array;
                import tagion.hibon.HiBONJSON;

                HiBON params = new HiBON;
                pragma(msg, "fixme(cbr): epoch_time has not beed added to the epoch");
                foreach (i, payload; events.map!((e) => e.event_body.payload).array) {
                    params[i] = payload;
                }
                log("Send to transcript: %s", Document(params).toJSON);
                transcript_tid.send(params.serialize);
            }

            hashgraph = new HashGraph(opts.nodes, net, &gossip_net.isValidChannel, &receive_epoch);
            // hashgraph.print_flag = true;
            hashgraph.scrap_depth = opts.scrap_depth;
            log("\n\n\n\nMY PUBKEY: %s \n\n\n\n", net.pubkey.cutHex);

            discovery_tid = spawn(
                &networkRecordDiscoveryService,
                net.pubkey,
                p2pnode,
                opts.discovery.task_name,
                opts);
            auto ctrl = receiveOnly!Control;
            assert(ctrl == Control.LIVE);
            log("networkRecordDiscoveryService Started");

            receive((DiscoveryState state) { assert(state == DiscoveryState.READY); });
            log("DiscoveryState state");
            discovery_tid.send(DiscoveryRequestCommand.RequestTable);
            receive(
                (ActiveNodeAddressBookPub address_book) {
                    update_pkeys(address_book.data.keys);
                    dart_sync_tid = spawn(
                        &dartSynchronizeServiceTask!StdSecureNet,
                        opts,
                        p2pnode,
                        shared_net,
                        sector_range);
                // receiveOnly!Control;
                    dart_tid = spawn(
                        &dartServiceTask!StdSecureNet,
                        opts,
                        p2pnode,
                        shared_net,
                        sector_range);
                    log("address_book len: %d", address_book.data.length);
                    send(dart_sync_tid, address_book);
                },
                (Control ctrl) {
                    if (ctrl is Control.STOP) {
                        force_stop = true;
                    }

                    if (ctrl is Control.END) {
                        force_stop = true;
                    }
                });
        }
        scope (exit) {
            log("Closing net");
            gossip_net.close();
        }
        if (force_stop) {
            return;
        }

        bool ready = false;
        int ready_counter = 0;
        do {
            receive((Control ctrl) {
                log("Received ctrl: %s", ctrl);
                if (ctrl is Control.LIVE) {
                    ready_counter++;
                }
                else if (ctrl is Control.STOP) {
                    force_stop = true;
                }
            }, (DARTSynchronizeState state) {
                if (state == DARTSynchronizeState.READY) {
                    ready = true;
                }
            });
            if (force_stop)
                return;
        }
        while (!ready || ready_counter != 2); // empty

        log("Ready: %s", ready);

        discovery_tid.send(DiscoveryRequestCommand.BecomeOnline);
        scope (exit) {
            discovery_tid.send(DiscoveryRequestCommand.BecomeOffline);
        }

        scope (exit) {
            log("close listener");
            p2pnode.closeListener(opts.transaction.protocol_id);
        }
        scope (exit) {
            log("!!!==========!!!!!! Existing %s", opts.node_name);

            if (transcript_tid != transcript_tid.init) {
                log("Send stop to %s", opts.transcript.task_name);
                transcript_tid.prioritySend(Control.STOP);
                if (receiveOnly!Control is Control.END) {
                    log("Scripting api end!!");
                }
            }

            if (discovery_tid !is Tid.init) {
                log("Send stop to %s", opts.discovery.task_name);
                discovery_tid.prioritySend(Control.STOP);
                if (receiveOnly!Control is Control.END) {
                    log("Discovery service stoped");
                }
            }

            if (dart_sync_tid !is Tid.init) {
                log("Send stop to %s", opts.dart.sync.task_name);
                dart_sync_tid.prioritySend(Control.STOP);
                if (receiveOnly!Control is Control.END) {
                    log("DART synchronization service stoped");
                }
            }
            log("DART TID: %s", dart_tid);
            if (dart_tid !is Tid.init) {
                log("Send stop to %s", opts.dart.task_name);
                dart_tid.prioritySend(Control.STOP);
                if (receiveOnly!Control is Control.END) {
                    log("DART service stoped");
                }
            }

            if (transaction_socket_tid != transaction_socket_tid.init) {
                log("send stop to %s", opts.transaction.task_name);
                transaction_socket_tid.prioritySend(Control.STOP);
                auto control = receiveOnly!Control;
                log("Control %s", control);
                if (control is Control.END) {
                    log("Closed transaction");
                }
            }

            if (monitor_socket_tid !is monitor_socket_tid.init) {
                log("send stop to %s", opts.monitor.task_name);
                //            try {
                monitor_socket_tid.prioritySend(Control.STOP);

                receive((Control ctrl) {
                    if (ctrl is Control.END) {
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

        try {
            monitor_socket_tid = spawn(&monitorServiceTask, opts);
            stderr.writefln("@@@@ Wait for monitor %s", opts.node_name,);

            if (receiveOnly!Control is Control.LIVE) {
                log("Monitor started");
            }
            transaction_socket_tid = spawn(&transactionServiceTask, opts);
            if (receiveOnly!Control is Control.LIVE) {
                log("Transaction started port %d", opts.transaction.service.port);
            }
            else {
                log("bad command");
            }
        }
        catch (Exception e) {
            log("ERROR: %s", e.msg);
            force_stop = true;
        }
        if (force_stop)
            return;
        transcript_tid = spawn(&transcriptServiceTask, opts.transcript.task_name,
                opts.dart.sync.task_name);
        assert(receiveOnly!Control is Control.LIVE);

        enum max_gossip = 2;
        uint gossip_count = max_gossip;
        bool stop = false;
        enum timeout_end = 10;
        uint timeout_count;
        //    Event mother;
        Event event;

        immutable(ubyte)[] data;

        {
            immutable buf = cast(Buffer) hashgraph.channel;
            const nonce = net.calcHash(buf);
            auto eva_event = hashgraph.createEvaEvent(gossip_net.time, nonce);

            if (eva_event is null) {
                log.error("The channel of this oner is not valid");
                return;
            }
        }

        alias PayloadQueue = Queue!Document;
        PayloadQueue payload_queue = new PayloadQueue();
        void receive_payload(Document pload, bool flag) { //TODO: remove flag. Maybe try switch(doc.type)
            log.trace("payload.size=%d", pload.size);
            payload_queue.write(pload);
        }

        Document payload() @safe {
            // log("Select payload: %s", payload_queue.empty);
            if (!hashgraph.active || payload_queue.empty) {
                return Document();
            }
            log("Payload readed %s", Clock.currTime().toUTC());
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
            timeout_count = 0;
            log("\n*\n*\n*\n******* receive %s %s", opts.node_name,
                    doc.data.length);
            const receiver = HiRPC.Receiver(doc);
            hashgraph.wavefront(receiver, gossip_net.time,
                    (const(HiRPC.Sender) return_wavefront) @safe { gossip_net.send(receiver.pubkey, return_wavefront); }, &payload);
        }

        import tagion.utils.Random;

        Random!size_t random;
        random.seed(123456789);

        bool network_ready = false;
        do{
            discovery_tid.send(DiscoveryRequestCommand.RequestTable);
            receive((ActiveNodeAddressBookPub address_book) { update_pkeys(address_book.data.keys); });
            if(pkeys.length < opts.nodes){
                Thread.sleep(500.msecs);
            }else{
                network_ready = true;
            }
        }while(!network_ready);

        while (!stop && !abort) {
            immutable message_received = receiveTimeout(opts.timeout.msecs, &receive_payload, &controller,
                    &receive_wavefront, &taskfailure, (ActiveNodeAddressBookPub address_book) {
                log("Update address book");
                update_pkeys(address_book.data.keys);
                if (dart_sync_tid != Tid.init) {
                    send(dart_sync_tid, address_book);
                }
                else {
                    log("DART sync not found");
                }
            });
            log("ROUNDS: %d AreWeInGraph: %s", hashgraph.rounds.length, hashgraph.areWeInGraph);
            if (!message_received || !hashgraph.areWeInGraph) {
                const init_tide = random.value(0, 2) is 1;
                if (init_tide) {
                    log("init_tide");
                    hashgraph.init_tide(&gossip_net.gossip, &payload, gossip_net.time);
                }
            }
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}
