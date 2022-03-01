module tagion.services.TagionService;

import std.concurrency;
import std.exception : assumeUnique;

import std.conv : to;
import std.traits : hasMember;
import core.thread;

import tagion.utils.Miscellaneous : cutHex;
import tagion.hashgraph.Event : Event;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.HashGraphBasic : EventBody, ExchangeState;
import tagion.basic.ConsensusExceptions;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.gossip.EmulatorGossipNet;
import tagion.basic.TagionExceptions : fatal, TaskFailure;

import tagion.services.ScriptCallbacks;
import tagion.services.EpochDebugService;
import tagion.crypto.secp256k1.NativeSecp256k1;

import tagion.monitor.Monitor;
import tagion.options.ServiceNames;
import tagion.services.MonitorService;
import tagion.services.TransactionService;
import tagion.services.TranscriptService;

import tagion.logger.Logger;

import tagion.services.Options : Options, setOptions, options;
import tagion.basic.Basic : Pubkey, Buffer, Control;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;

// If no monitor should be enable set the address to empty or the port below min_port.
// void tagionNode(Net)(uint timeout, immutable uint node_id,
//     immutable uint N,
//     string monitor_ip_address,
//     const ushort monitor_port)  {
void tagionServiceTask(Net)(immutable(Options) args, shared(SecureNet) master_net) nothrow {
    try {
        scope (success) {
            ownerTid.prioritySend(Control.END);
        }

        Options opts = args;
        opts.node_name = node_task_name(opts);
        log.register(opts.node_name);
        opts.monitor.task_name = task_name(opts.monitor.task_name, opts);
        opts.transaction.task_name = task_name(opts.transaction.task_name, opts);
        opts.transcript.task_name = task_name(opts.transcript.task_name, opts);
        opts.transaction.service.task_name = task_name(opts.transaction.service.task_name, opts);
        setOptions(opts);

        log("task_name=%s options.mode_name=%s", opts.node_task_name, options.node_name);

        //    HRPC hrpc;
        import std.datetime.systime;

        Net net;
        //    net=new Net(hashgraph);
        net.derive("tagion_service", master_net);
        //    hashgraph.gossip_net=net;
        // Create hash-graph
        auto hashgraph = new HashGraph(opts.nodes);

        log("\n\n\n\n\n##### Received %s #####", opts.node_name);

        Tid monitor_socket_tid;
        Tid transaction_socket_tid;

        scope (exit) {
            log("!!!==========!!!!!! Existing %s", opts.node_name);

            if (net.transcript_tid != net.transcript_tid.init) {
                log("Send stop to %s", opts.transcript.task_name);
                net.transcript_tid.send(Control.STOP);
                receive((Control ctrl) {
                    if (ctrl is Control.END) {
                        log("Closed monitor");
                    }
                    else {
                        log.warning("Unexpected control code %s", ctrl);
                    }

                }, (immutable(TaskFailure) t) { ownerTid.send(t); });
            }

            if (net.callbacks) {
                net.callbacks.exiting(net.pubkey, hashgraph);
            }

            if (transaction_socket_tid != transaction_socket_tid.init) {
                log("send stop to %s", opts.transaction.task_name);

                transaction_socket_tid.send(Control.STOP);
                receive((Control ctrl) {
                    if (ctrl is Control.END) {
                        log("Closed monitor");
                    }
                    else {
                        log.warning("Unexpected control code %s", ctrl);
                    }
                }, (immutable(TaskFailure) t) { ownerTid.send(t); });
            }

            if (monitor_socket_tid != monitor_socket_tid.init) {
                log("send stop to %s", opts.monitor.task_name);
                monitor_socket_tid.send(Control.STOP);

                receive((Control ctrl) {
                    if (ctrl is Control.END) {
                        log("Closed monitor");
                    }
                    else {
                        log.warning("Unexpected control code %s", ctrl);
                    }
                }, (immutable(TaskFailure) t) { ownerTid.send(t); });
            }

        }

        // Pseudo passpharse
        // immutable passphrase=opts.node_name;
        // net.generateKeyPair(passphrase);

        ownerTid.send(net.pubkey);
        Pubkey[] received_pkeys;
        foreach (i; 0 .. opts.nodes) {
            received_pkeys ~= receiveOnly!(Pubkey);
            log.trace("Receive %d %s", i, received_pkeys[i].cutHex);
        }
        immutable pkeys = assumeUnique(received_pkeys);

        hashgraph.createNode(net.pubkey);
        log("Ownkey %s num=%d", net.pubkey.cutHex, pkeys.length);
        //    stderr.writefln("@@@@ Ownkey %s num=%d", net.pubkey.cutHex, pkeys.length);
        foreach (i, p; pkeys) {
            if ((p != net.pubkey) && hashgraph.createNode(p)) {
                log("Create %d %s", i, p.cutHex);
            }
        }
        // scope tids=new Tid[N];
        // getTids(tids);
        net.set(pkeys);
        if (((opts.node_id < opts.monitor.max) || (opts.monitor.max == 0))
                && (opts.monitor.port >= opts.min_port)) {
            monitor_socket_tid = spawn(&monitorServiceTask, opts);
            Event.callbacks = new MonitorCallBacks(monitor_socket_tid, opts.node_id,
                    net.globalNodeId(net.pubkey), opts.monitor.dataformat);

            if (receiveOnly!Control is Control.LIVE) {
                log("Monitor started");
            }
        }

        if (((opts.node_id < opts.transaction.max)
                || (opts.transaction.max == 0)) && (opts.transaction.service.port >= opts.min_port)) {
            transaction_socket_tid = spawn(&transactionServiceTask, opts);
            if (receiveOnly!Control is Control.LIVE) {
                log("Transaction started port %d", opts.transaction.service.port);
            }
        }

        // All tasks is in sync
        //stderr.writefln("@@@@ All tasks are in sync %s", opts.node_name);
        log("All tasks are in sync %s", opts.node_name);

        //Event.scriptcallbacks=new ScriptCallbacks(thisTid);

        string epoch_debug_task_name;
        if (opts.transcript.epoch_debug) {
            import std.array : join;

            epoch_debug_task_name = ["epoch", opts.transcript.task_name].join("_");
            spawn(&epochDebugServiceTask, epoch_debug_task_name);
        }
        scope (exit) {
            auto tid = locate(epoch_debug_task_name);
            if (tid != tid.init) {
                tid.send(Control.STOP);
                if (receiveOnly!Control != Control.END) {
                    log("Epoch Debug ended");
                }
            }
        }

        Event.scriptcallbacks = new ScriptCallbacks(&transcriptServiceTask,
                opts.transcript.task_name, opts.dart.task_name);
        scope (exit) {
            Event.scriptcallbacks.stop;
        }

        enum max_gossip = 1;
        uint gossip_count = max_gossip;
        bool stop = false;
        // // True of the network has been initialized;
        uint timeout_count;

        Event event; // Current evnet for this node
        auto own_node = hashgraph.getNode(net.pubkey);

        auto net_random = cast(Net) net;
        enum bool has_random_seed = __traits(compiles, net_random.random.seed(0));

        static if (has_random_seed) {
            if (!opts.sequential) {
                net_random.random.seed(cast(uint)(Clock.currTime.toUnixTime!int));
            }
        }

        //
        // Start Script API task
        //

        //
        //  Define empty payload
        //
        const(Document) empty_payload;

        void receive_buffer(const(Document) doc) {
            timeout_count = 0;
            net.time = net.time + 100;
            log("\n*\n*\n*\n******* receive %s [%s] %s", opts.node_name,
                    opts.node_id, doc.data.length);
            net.receive(doc);
        }

        void next_mother(const(Document) payload) {
            if ((gossip_count >= max_gossip) || (payload.length)) {

                // fout.writeln("After build wave front");
                if (own_node.event is null) {
                    log.trace("next_mother %d eva", timeout_count);
                    immutable ebody = EventBody.eva(net);
                    immutable epack = buildEventPackage(net, ebody);
                    event = hashgraph.registerEvent(epack);
                }
                else {
                    log.trace("next_mother %d single", timeout_count);
                    auto mother = own_node.event;
                    immutable mother_hash = mother.fingerprint;
                    immutable ebody = immutable(EventBody)(payload,
                            mother_hash, null, net.time, mother.altitude + 1);
                    immutable epack = buildEventPackage(net, ebody);
                    event = hashgraph.registerEvent(epack);
                }
                immutable send_channel = net.selectRandomNode;
                auto send_node = hashgraph.getNode(send_channel);
                if (send_node.state is ExchangeState.NONE) {
                    log.trace("next_mother %d wavefront", timeout_count);
                    send_node.state = ExchangeState.INIT_TIDE;
                    auto tidewave = new HiBON;
                    auto tides = hashgraph.tideWave(tidewave, net.callbacks !is null);
                    const pack_doc = hashgraph.buildPackage(tidewave, ExchangeState.TIDAL_WAVE);

                    net.send(send_channel, pack_doc);
                    //log.trace("Send to %s", send_node.pubkey.cutHex);
                    if (net.callbacks) {
                        net.callbacks.sent_tidewave(send_channel, tides);
                    }
                }
                gossip_count = 0;
            }
            else {
                gossip_count++;
            }
        }

        void receive_payload(Document pload) {
            log.trace("payload.length=%d", pload.length);
            next_mother(pload);
        }

        void controller(Control ctrl) {
            with (Control) switch (ctrl) {
            case STOP:
                stop = true;
                log("##### Stop %s", opts.node_name);
                break;
            default:
                log.error("Unsupported control %s", ctrl);
            }
        }

        void _taskfailure(immutable(TaskFailure) t) {
            ownerTid.send(t);
            if (t.throwable is null) {
                stop = true;
            }
        }

        static if (has_random_seed) {
            void sequential(uint time, uint random)
            in {
                assert(opts.sequential);
            }
            do {
                net_random.random.seed(random);
                net_random.time = time;
                next_mother(empty_payload);
            }
        }

        log("SEQUENTIAL=%s", opts.sequential);
        ownerTid.send(Control.LIVE);
        Thread.sleep(1000.msecs);
        while (!stop) {
            if (opts.sequential) {
                immutable message_received = receiveTimeout(opts.timeout.msecs, &receive_payload,
                        &controller, &sequential, &receive_buffer, &_taskfailure,);
                if (!message_received) {
                    log("TIME OUT");
                    timeout_count++;
                    // if ( !net.queue.empty ) {
                    //     receive_buffer(net.queue.read);
                    // }
                }
            }
            else {
                immutable message_received = receiveTimeout(opts.timeout.msecs,
                        &receive_payload, &controller, &receive_buffer, &_taskfailure,);
                if (!message_received) {
                    log("TIME OUT");
                    timeout_count++;
                    net.time = Clock.currTime.toUnixTime!long;
                    // if ( !net.queue.empty ) {
                    //     receive_buffer(net.queue.read);
                    // }
                    next_mother(empty_payload);
                }
            }
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}
