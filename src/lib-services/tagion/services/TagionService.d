module tagion.services.TagionService;

import core.thread : Thread;
import core.time;

import std.datetime : Clock;
import tagion.utils.StdTime;
import tagion.tasks.TaskWrapper : Task;

//import std.conv;
//import std.algorithm.searching : canFind;

import p2plib = p2p.node;

//import p2p.connection;
import p2p.callback;
import p2p.cgo.c_helper;

import tagion.services.Options : Options, setOptions, OptionException, NetworkMode, main_task;
import tagion.utils.Random;
import tagion.utils.Queue;
import tagion.GlobalSignals : abort;

import tagion.basic.Types : Pubkey, Control, Buffer;
import tagion.basic.Basic : nameOf;
import tagion.logger.Logger;
import tagion.hashgraph.Event : Event;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.HashGraphBasic : EventPackage;

//import tagion.services.TagionService;
import tagion.gossip.EmulatorGossipNet;

//import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.crypto.SecureNet : StdSecureNet;

//import tagion.options.ServiceNames : get_node_name;
import tagion.basic.TagionExceptions : taskfailure, fatal;
import tagion.services.DARTSynchronizeService;

///import tagion.dart.DARTSynchronization;
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

//import tagion.basic.ConsensusExceptions;
//import tagion.basic.TagionExceptions : TagionException;

//import tagion.services.ScriptCallbacks;
import tagion.services.FileDiscoveryService;

//import tagion.services.ServerFileDiscoveryService;
import tagion.services.NetworkRecordDiscoveryService;

//mport tagion.gossip.P2pGossipNet: AddressBook;
import tagion.services.DARTService;
import tagion.gossip.AddressBook : addressbook;
import tagion.script.StandardRecords;

//import tagion.Keywords : NetworkMode;

//import std.stdio;
//import std.array : replace, split;
//import std.string : indexOf;
//import std.file : mkdir, exists;
import std.format;
import std.datetime.systime;

shared(p2plib.Node) initialize_node(immutable Options opts)
{
    import std.array : split;

    auto p2pnode = new shared(p2plib.Node)(
        format("/ip4/%s/tcp/%s",
            opts.ip,
            opts.port), 0);
    log("initialize_node");
    scope (exit)
    {
        log("END initialize_node");

    }
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

void tagionService(NetworkMode net_mode, Options opts) nothrow
{
    try
    {
        /** last epoch timestamp */
        long epoch_timestamp = Clock.currTime().toTimeSpec.tv_sec;
        log.register(opts.node_name);
        setOptions(opts);
        bool stop;
        uint count_transactions;
        uint epoch_num;
        scope (success)
        {
            log.close;
            ownerTid.prioritySend(Control.END);
        }

        pragma(msg, "fixme(cbr): The passphrase should generate from outside");
        string passpharse;
        if (net_mode == NetworkMode.internal)
        {
            passpharse = format("Secret_word_%s", opts.node_name).idup;
        }
        else
        {
            passpharse = format("Secret_word_%d", opts.port).idup;
        }

        //        log.trace("passphrase %s", passpharse);
        bool force_stop = false;

        import std.format;

        auto sector_range = DART.SectorRange(opts.dart.from_ang, opts.dart.to_ang);
        shared(p2plib.Node) p2pnode;

        auto master_net = new StdSecureNet;
        StdSecureNet net = new StdSecureNet;
        GossipNet gossip_net;
        //ScriptCallbacks scriptcallbacks;
        HashGraph hashgraph;

        Tid discovery_tid;
        Tid dart_sync_tid;
        Tid dart_tid;
        Tid monitor_socket_tid;
        Tid transaction_socket_tid;
        Task!(TrascriptServiceTask)* transcript;

        shared StdSecureNet shared_net;
        synchronized (master_net)
        {
            import std.format;

            master_net.generateKeyPair(passpharse);
            shared_net = cast(shared) master_net;
            log("opts.node_name = %s", opts.node_name);
            net.derive(opts.node_name, shared_net);
            p2pnode = initialize_node(opts);
        }

        final switch (net_mode)
        {
        case NetworkMode.internal:

            gossip_net = new EmulatorGossipNet(net.pubkey, opts.timeout.msecs);
            ownerTid.send(net.pubkey);
            Pubkey[] pkeys;
            foreach (i; 0 .. opts.nodes)
            {
                pkeys ~= receiveOnly!(Pubkey);
                log.trace("Receive %d %s", i, pkeys[i].cutHex);
            }
            import std.exception : assumeUnique;

            //pkeys = received_pkeys.dup;
            foreach (p; pkeys)
                gossip_net.add_channel(p);
            ownerTid.send(Control.LIVE);
            break;
        case NetworkMode.local:
        case NetworkMode.pub:
            gossip_net = new P2pGossipNet(
                net.pubkey,
                opts.node_name,
                opts.discovery.task_name,
                opts.host,
                p2pnode);
        }

        void receive_epoch(const(Event)[] events, const sdt_t epoch_time) @trusted
        {
            import std.algorithm;
            import std.array : array;
            import tagion.hibon.HiBONJSON;

            HiBON params = new HiBON;

            params = events
                .filter!((e) => !e.event_body.payload.empty)
                .map!((e) => e.event_body.payload);

            transcript.receive_epoch(params.serialize);
            epoch_num++;
            count_transactions = 0;
            epoch_timestamp = Clock.currTime().toTimeSpec.tv_sec;

            if (epoch_num >= opts.epoch_limit)
            {
                auto main_tid = locate(main_task);
                main_tid.send(Control.STOP);
            }
        }

        void register_epack(immutable(EventPackage*) epack) @safe
        {
            log.trace("epack.event_body.payload.empty %s", epack.event_body.payload.empty);
        }

        import tagion.utils.Miscellaneous;

        log.trace("Hashgraph pubkey=%s", net.pubkey.cutHex);
        hashgraph = new HashGraph(opts.nodes, net, &gossip_net.isValidChannel, &receive_epoch, &register_epack);
        // hashgraph.print_flag = true;
        hashgraph.scrap_depth = opts.scrap_depth;
        log("\n\n\n\nMY PUBKEY: %s \n\n\n\n", net.pubkey.cutHex);

        discovery_tid = spawn(
            &networkRecordDiscoveryService,
            net.pubkey,
            p2pnode,
            opts.discovery.task_name,
            opts);
        assert(receiveOnly!Control is Control.LIVE);

        assert(receiveOnly!DiscoveryControl is DiscoveryControl.READY);
        log.trace("Network discovered ready");
        discovery_tid.send(DiscoveryRequestCommand.RequestTable);
        assert(receiveOnly!DiscoveryControl is DiscoveryControl.READY);
        alias constDocument = const(Document);
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
        log.trace("Start sync addressbook.numOfActiveNodes : %d", addressbook.numOfActiveNodes);

        scope (exit)
        {
            log("Closing net");
            gossip_net.close();
        }

        bool ready = false;
        int ready_counter = 2;
        log.trace("Before sync ready addressbook.numOfActiveNodes : %d", addressbook
                .numOfActiveNodes);

        do
        {
            receive((Control ctrl) {
                log("Received ctrl: %s", ctrl);
                if (ctrl is Control.LIVE)
                {
                    ready_counter--;
                }
            }, (DARTSynchronizeState state) {
                if (state == DARTSynchronizeState.READY)
                {
                    ready = true;
                }
            });
        }
        while (!ready || (ready_counter !is 0)); // empty

        log("Ready: %s", ready);

        discovery_tid.send(DiscoveryRequestCommand.BecomeOnline);
        // scope (exit) {
        //     discovery_tid.send(DiscoveryRequestCommand.BecomeOffline);
        // }

        scope (exit)
        {
            log("close listener");
            p2pnode.closeListener(opts.transaction.protocol_id);
        }
        scope (exit)
        {
            auto _cd_ = receiveOnly!constDocument;
            import std.stdio;
            writeln("<><>", _cd_);
            if (discovery_tid !is Tid.init)
            {
                discovery_tid.prioritySend(Control.STOP);
                if (receiveOnly!Control is Control.END)
                {
                    log("Discovery service stoped");
                }
            }

            if (dart_sync_tid !is Tid.init)
            {
                dart_sync_tid.prioritySend(Control.STOP);
                if (receiveOnly!Control is Control.END)
                {
                    log("DART synchronization service stoped");
                }
            }
            if (dart_tid !is Tid.init)
            {
                dart_tid.prioritySend(Control.STOP);
                if (receiveOnly!Control is Control.END)
                {
                    log("DART service stoped");
                }
            }

            if (transaction_socket_tid !is transaction_socket_tid.init)
            {
                transaction_socket_tid.prioritySend(Control.STOP);
                if (receiveOnly!Control is Control.END)
                {
                    log("Closed transaction");
                }
            }

            if (monitor_socket_tid !is monitor_socket_tid.init)
            {
                monitor_socket_tid.prioritySend(Control.STOP);
                if (receiveOnly!Control is Control.END)
                {
                    log("Closed monitor");
                }
            }
            ownerTid.prioritySend(Control.END);
        }

        log.trace("Before startinf monitor and transaction addressbook.numOfActiveNodes : %d", addressbook
                .numOfActiveNodes);

        // monitor_socket_tid = spawn(
        //         &monitorServiceTask,
        //         opts);
        // assert(receiveOnly!Control is Control.LIVE);
        /*
        transcript_tid = spawn(
            &transcriptServiceTask,
            opts.transcript.task_name,
            opts.dart.sync.task_name);*/
        transcript = new Task!TrascriptServiceTask(opts.transaction.task_name, opts);
        import std.stdio;
        writeln(">>>YY<<<");
        scope(exit)
        {            
            writeln("<>1<>", receiveOnly!DiscoveryControl);
            writeln("<>2<>", receiveOnly!constDocument);
            transcript.control(Control.STOP);
            if (receiveOnly!Control is Control.END)
            {
                log("Scripting api end!!");
            }
        }
        assert(receiveOnly!Control is Control.LIVE);

        transaction_socket_tid = spawn(
            &transactionServiceTask,
            opts);
        assert(receiveOnly!Control is Control.LIVE);

        {
            immutable buf = cast(Buffer) hashgraph.channel;
            const nonce = net.calcHash(buf);
            auto eva_event = hashgraph.createEvaEvent(gossip_net.time, nonce);

            if (eva_event is null)
            {
                log.error("The channel of this oner is not valid");
                return;
            }
        }

        alias PayloadQueue = Queue!Document;
        PayloadQueue payload_queue = new PayloadQueue();

        void receive_payload(Document pload, bool flag)
        { //TODO: remove flag. Maybe try switch(doc.type)
            count_transactions++;
            log.trace("payload.size=%d", pload.size);
            payload_queue.write(pload);
        }

        const(Document) payload() @safe
        {
            if (!hashgraph.active || payload_queue.empty)
            {
                return Document();
            }
            log("Payload readed %s", Clock.currTime().toUTC());
            return payload_queue.read;
        }

        void controller(Control ctrl)
        {
            log("Ctrl: %s", ctrl);
            with (Control)
            {
                switch (ctrl)
                {
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

        void receive_wavefront(const Document doc)
        {
            log("\n*\n*\n*\n******* receive %s %s", opts.node_name,
                doc.data.length);
            const receiver = HiRPC.Receiver(doc);
            hashgraph.wavefront(
                receiver,
                gossip_net.time,
                (const(HiRPC.Sender) return_wavefront) @safe {
                gossip_net.send(receiver.pubkey, return_wavefront);
            },
                &payload);
        }

        pragma(msg, "fixme(cbr): Random should be unpredictable");
        import tagion.utils.Random;

        Random!size_t random;
        random.seed(123456789);

        log.trace("Before DiscoveryRequestCommand.RequestTable  addressbook.numOfActiveNodes : %d", addressbook
                .numOfActiveNodes);

        bool network_ready = false;
        do
        {
            discovery_tid.send(DiscoveryRequestCommand.RequestTable);
            log.trace("NETWORK READY %d < %d ", addressbook.numOfNodes, opts.nodes);
            if (addressbook.isReady)
            {
                network_ready = true;
            }
            else
            {
                Thread.sleep(500.msecs);
            }
        }
        while (!network_ready);

        log.trace("Before Main loop  addressbook.numOfActiveNodes : %d", addressbook
                .numOfActiveNodes);
        HiRPC empty_hirpc;
        while (!stop && !abort)
        {
            immutable message_received = receiveTimeout(
                opts.timeout.msecs,
                &receive_payload,
                &controller,
                &receive_wavefront,
                &taskfailure,
                (string respond_task_name, Buffer data) {
                import tagion.hibon.HiBONJSON;

                /** document for receive request */
                const doc = Document(data);
                const receiver = empty_hirpc.receive(doc);
                auto respond = HealthcheckParams(hashgraph.rounds.length, epoch_timestamp, count_transactions, epoch_num, hashgraph
                    .areWeInGraph);
                auto response = empty_hirpc.result(receiver, respond);
                log("Healthcheck: %s", response.toDoc.toJSON);
                locate(respond_task_name).send(response.toDoc.serialize);
            }
            );
            log("ROUNDS: %d AreWeInGraph: %s Active %d", hashgraph.rounds.length, hashgraph.areWeInGraph, addressbook
                    .numOfActiveNodes);
            if (!message_received || !hashgraph.areWeInGraph)
            {
                const init_tide = random.value(0, 2) is 1;
                if (init_tide)
                {
                    log("init_tide");
                    hashgraph.init_tide(&gossip_net.gossip, &payload, gossip_net.time);
                }
            }
        }
    }
    catch (Throwable t)
    {
        fatal(t);
    }
}
