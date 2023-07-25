/// Tagion main services
module tagion.prior_services.TagionService;

import core.thread : Thread;
import core.time;
import std.concurrency;
import std.range : empty;
import std.string : fromStringz;
import std.file : fread = read, exists;
import std.format;
import std.datetime : Clock;

import p2plib = p2p.node;

import tagion.basic.Types : Control, Buffer;
import tagion.actor.exceptions : taskfailure, fatal;
import tagion.crypto.Types : Pubkey;
import tagion.communication.HiRPC;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.dart.DART;
import tagion.GlobalSignals : abort;
import tagion.gossip.AddressBook : addressbook;
import tagion.gossip.EmulatorGossipNet;
import tagion.gossip.InterfaceNet;
import tagion.gossip.P2pGossipNet;
import tagion.hashgraph.Event : Event;
import tagion.hashgraph.Event : Round;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.HashGraphBasic : EventPackage;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.logger.Logger;
import tagion.monitor.Monitor : MonitorCallBacks;
import tagion.script.StandardRecords;
import tagion.prior_services.Options : Options, setOptions, OptionException, NetworkMode, main_task;
import tagion.prior_services.DARTService;
import tagion.prior_services.DARTSynchronizeService;
import tagion.prior_services.TransactionService;
import tagion.prior_services.TranscriptService;
import tagion.prior_services.FileDiscoveryService;
import tagion.prior_services.NetworkRecordDiscoveryService;
import tagion.prior_services.MonitorService;
import tagion.prior_services.RecorderService : RecorderTask;
import tagion.prior_services.EpochDumpService : EpochDumpTask;
import tagion.taskwrapper.TaskWrapper : Task;
import tagion.utils.Random;
import tagion.utils.Queue;
import tagion.utils.StdTime;
import tagion.utils.Miscellaneous : cutHex;

shared(p2plib.Node) initialize_node(immutable Options opts) {
    import std.array : split;

    auto p2pnode = new shared(p2plib.Node)(
            format("/ip4/%s/tcp/%s",
            opts.ip,
            opts.port), 0);

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

void tagionService(NetworkMode net_mode, Options opts) nothrow {
    try {
        /** last epoch timestamp */
        long epoch_timestamp = Clock.currTime().toTimeSpec.tv_sec;
        const startup_timestamp = Clock.currTime().stdTime;
        log.register(opts.node_name);
        setOptions(opts);
        bool stop;
        uint count_transactions;
        uint epoch_num;
        scope (success) {
            log.close;
            ownerTid.prioritySend(Control.END);
        }

        string passphrase;
        if (!opts.path_to_stored_passphrase.empty) {
            if (exists(opts.path_to_stored_passphrase)) {
                const char[] file_content = cast(char[]) fread(opts.path_to_stored_passphrase);
                passphrase = fromStringz(file_content).idup;
            }

            if (passphrase.empty) {
                log.warning(
                        "Please check file " ~ opts.path_to_stored_passphrase ~ ", perform start with default settings");
            }
        }

        if (passphrase.empty) {
            if (net_mode == NetworkMode.internal) {
                passphrase = format("Secret_word_%s", opts.node_name).idup;
            }
            else {
                passphrase = format("Secret_word_%d", opts.port).idup;
            }
        }

        auto sector_range = DART.SectorRange(0, 0);
        shared(p2plib.Node) p2pnode;

        auto master_net = new StdSecureNet;
        StdSecureNet net = new StdSecureNet;
        GossipNet gossip_net;
        HashGraph hashgraph;

        Tid discovery_tid;
        Tid dart_sync_tid;
        Tid dart_tid;
        Tid monitor_socket_tid;
        Tid transaction_socket_tid;
        Tid transcript_tid;
        Tid recorder_service_tid;
        Tid epoch_dumping_service_tid;

        shared StdSecureNet shared_net;
        synchronized (master_net) {
            master_net.generateKeyPair(passphrase);
            shared_net = cast(shared) master_net;
            net.derive(opts.node_name, shared_net);
            p2pnode = initialize_node(opts);
        }

        final switch (net_mode) {
        case NetworkMode.internal:

            gossip_net = new EmulatorGossipNet(net.pubkey, opts.timeout.msecs);
            ownerTid.send(net.pubkey);
            Pubkey[] pkeys;
            foreach (i; 0 .. opts.nodes) {
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
        import tagion.hashgraph.Refinement;
        import tagion.basic.basic : trusted;
        @safe
        class PriorStdRefinement : StdRefinement {

            override void finishedEpoch(const(Event)[] events, const sdt_t epoch_time, const Round decided_round) {
                import std.algorithm;
                import std.array : array;
                import tagion.hibon.HiBONJSON;

                HiBON params = new HiBON;

                params = events
                    .filter!((e) => !e.event_body.payload.empty)
                    .map!((e) => e.event_body.payload);

                (() @trusted => transcript_tid.send(params.serialize))();
                epoch_num++;
                count_transactions = 0;
                epoch_timestamp = Clock.currTime().toTimeSpec.tv_sec;

                if (epoch_num >= opts.epoch_limit) {
                    auto main_tid = (() @trusted => locate(main_task))();
                    (() @trusted => (main_tid.send(Control.STOP)))();
                }
            }
            
        }


        if (opts.monitor.enable) {
            monitor_socket_tid = spawn(&monitorServiceTask, opts);

            Event.callbacks = new MonitorCallBacks(
                    monitor_socket_tid, opts.node_id,
                    opts.monitor.dataformat);

            assert(receiveOnly!Control is Control.LIVE);
        }

        import tagion.utils.Miscellaneous;
        import std.typecons;

        log.trace("Hashgraph pubkey=%s", net.pubkey.cutHex);
        import tagion.hashgraph.Refinement;
        auto refinement = new PriorStdRefinement;
        hashgraph = new HashGraph(opts.nodes, net, refinement, &gossip_net.isValidChannel, No.joining);
        hashgraph.scrap_depth = opts.scrap_depth;

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

        scope (exit) {
            log("Closing net");
            gossip_net.close();
        }

        bool ready = false;
        int ready_counter = 2;
        log.trace("Before sync ready addressbook.numOfActiveNodes : %d", addressbook
                .numOfActiveNodes);

        do {
            receive((Control ctrl) {
                log("Received ctrl: %s", ctrl);
                if (ctrl is Control.LIVE) {
                    ready_counter--;
                }
            }, (DARTSynchronizeState state) {
                if (state == DARTSynchronizeState.READY) {
                    ready = true;
                }
            });
        }
        while (!ready || (ready_counter !is 0)); // empty

        log("Ready: %s", ready);

        discovery_tid.send(DiscoveryRequestCommand.BecomeOnline);

        scope (exit) {
            p2pnode.closeListener(opts.transaction.protocol_id);
        }
        scope (exit) {
            if (transcript_tid !is transcript_tid.init) {
                transcript_tid.prioritySend(Control.STOP);
                receiveOnly!Control;
            }

            if (recorder_service_tid !is Tid.init) {
                recorder_service_tid.prioritySend(Control.STOP);
                if (receiveOnly!Control == Control.END) {
                    log("Recorder service stopped");
                }
            }

            if (epoch_dumping_service_tid !is Tid.init) {
                epoch_dumping_service_tid.send(Control.STOP);
                if (receiveOnly!Control == Control.END) {
                    log("Epoch dumping service stopped");
                }
            }

            if (discovery_tid !is Tid.init) {
                discovery_tid.prioritySend(Control.STOP);
                if (receiveOnly!Control is Control.END) {
                    log("Discovery service stoped");
                }
            }

            if (dart_sync_tid !is Tid.init) {
                dart_sync_tid.prioritySend(Control.STOP);
                if (receiveOnly!Control is Control.END) {
                    log("DART synchronization service stoped");
                }
            }
            if (dart_tid !is Tid.init) {
                dart_tid.prioritySend(Control.STOP);
                if (receiveOnly!Control is Control.END) {
                    log("DART service stoped");
                }
            }

            if (transaction_socket_tid !is transaction_socket_tid.init) {
                transaction_socket_tid.prioritySend(Control.STOP);
                if (receiveOnly!Control is Control.END) {
                    log("Closed transaction");
                }
            }

            if (monitor_socket_tid !is monitor_socket_tid.init) {
                monitor_socket_tid.prioritySend(Control.STOP);
                if (receiveOnly!Control is Control.END) {
                    log("Closed monitor");
                }
            }
            ownerTid.prioritySend(Control.END);
        }

        log.trace("Before startinf monitor and transaction addressbook.numOfActiveNodes : %d", addressbook
                .numOfActiveNodes);

        if (!opts.recorder_chain.folder_path.empty) {
            Task!RecorderTask(opts.recorder_chain.task_name, opts);
            assert(receiveOnly!Control == Control.LIVE);
            recorder_service_tid = locate(opts.recorder_chain.task_name);
        }

        if (opts.epoch_dump.enabled) {
            auto task_name = opts.epoch_dump.task_name;
            Task!EpochDumpTask(task_name, opts);
            assert(receiveOnly!Control == Control.LIVE);
            epoch_dumping_service_tid = locate(task_name);
        }

        transcript_tid = spawn(

                &transcriptServiceTask,
                opts.transcript.task_name,
                opts.dart.sync.task_name,
                opts.recorder_chain.task_name,
                opts.epoch_dump.task_name);
        assert(receiveOnly!Control == Control.LIVE);

        transaction_socket_tid = spawn(
                &transactionServiceTask,
                opts);
        assert(receiveOnly!Control == Control.LIVE);

        {
            immutable buf = cast(Buffer) hashgraph.channel;
            const nonce = cast(Buffer) net.calcHash(buf);
            auto eva_event = hashgraph.createEvaEvent(gossip_net.time, nonce);

            if (eva_event is null) {
                log.error("The channel of this oner is not valid");
                return;
            }
        }

        alias PayloadQueue = Queue!Document;
        PayloadQueue payload_queue = new PayloadQueue();

        void receive_payload(Document pload, bool flag) { //TODO: remove flag. Maybe try switch(doc.type)
            count_transactions++;
            log.trace("payload.size=%d", pload.size);
            payload_queue.write(pload);
        }

        const(Document) payload() @safe {
            if (!hashgraph.active || payload_queue.empty) {
                return Document();
            }
            log.trace("Payload read");
            return payload_queue.read;
        }

        void controller(Control ctrl) {
            with (Control) {
                switch (ctrl) {
                case STOP:
                    stop = true;
                    log("Stop %s", opts.node_name);
                    break;
                case LIVE:
                    break;
                default:
                    log.error("Unsupported control %s", ctrl);
                }
            }
        }

        void receive_wavefront(const Document doc) {
            const receiver = HiRPC.Receiver(doc);
            hashgraph.wavefront(
                    receiver,
                    gossip_net.time,
                    (const(HiRPC.Sender) return_wavefront) @safe { gossip_net.send(receiver.pubkey, return_wavefront); },
                    &payload);
        }

        pragma(msg, "fixme(cbr): Random should be unpredictable");

        Random!size_t random;
        random.seed(123456789);

        log.trace("Before DiscoveryRequestCommand.RequestTable  addressbook.numOfActiveNodes : %d", addressbook
                .numOfActiveNodes);

        bool network_ready = false;
        do {
            discovery_tid.send(DiscoveryRequestCommand.RequestTable);
            log.trace("NETWORK READY %d < %d ", addressbook.numOfNodes, opts.nodes);
            if (addressbook.isReady) {
                network_ready = true;
            }
            else {
                Thread.sleep(500.msecs);
            }
        }
        while (!network_ready);

        log.trace("Before Main loop addressbook.numOfActiveNodes : %d", addressbook
                .numOfActiveNodes);
        HiRPC empty_hirpc;
        gossip_net.start_listening();

        const startup_duration = dur!"hnsecs"(Clock.currTime().stdTime - startup_timestamp);
        if (opts.startup_delay.msecs > startup_duration) {
            Thread.sleep(opts.startup_delay.msecs - startup_duration);
        }
        while (!stop && !abort) {
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
                log("Sent back to %s", respond_task_name);
            }
            );
            log("ROUNDS: %d AreWeInGraph: %s Active %d", hashgraph.rounds.length, hashgraph.areWeInGraph, addressbook
                    .numOfActiveNodes);
            if (!message_received || !hashgraph.areWeInGraph) {
                const init_tide = random.value(0, 2) is 1;
                if (init_tide) {
                    hashgraph.init_tide(&gossip_net.gossip, &payload, gossip_net.time);
                }
            }
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}
