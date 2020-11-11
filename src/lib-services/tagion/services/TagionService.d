module tagion.services.TagionService;

import std.concurrency;
import std.exception : assumeUnique;
import std.stdio;
import std.conv : to;
import std.traits : hasMember;
import core.thread;

import tagion.utils.Miscellaneous: cutHex;
import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraph;
import tagion.basic.ConsensusExceptions;
import tagion.gossip.InterfaceNet;
import tagion.gossip.EmulatorGossipNet;
import tagion.basic.TagionExceptions : TagionException;


import tagion.services.ScriptCallbacks;
import tagion.crypto.secp256k1.NativeSecp256k1;

import tagion.communication.Monitor;
import tagion.ServiceNames;
import tagion.services.MonitorService;
import tagion.services.TransactionService;
import tagion.services.TranscriptService;
//import tagion.services.ScriptingEngineService;
import tagion.services.LoggerService;
import tagion.basic.TagionExceptions;

import tagion.Options : Options, setOptions, options;
import tagion.basic.Basic : Pubkey, Payload, Control;
import tagion.hibon.HiBON : HiBON;


// If no monitor should be enable set the address to empty or the port below min_port.
// void tagionNode(Net)(uint timeout, immutable uint node_id,
//     immutable uint N,
//     string monitor_ip_address,
//     const ushort monitor_port)  {
void tagionServiceTask(Net)(immutable(Options) args, shared(SecureNet) master_net) {
    Options opts=args;
    opts.node_name=node_task_name(opts);
    log.register(opts.node_name);
    opts.monitor.task_name=monitor_task_name(opts);
    opts.transaction.task_name=transaction_task_name(opts);
    opts.transcript.task_name=transcript_task_name(opts);
    opts.transaction.service.task_name=transervice_task_name(opts);
    setOptions(opts);

    log("task_name=%s options.mode_name=%s", opts.node_task_name, options.node_name);

//    HRPC hrpc;
    import std.datetime.systime;

    auto hashgraph=new HashGraph();
    // Create hash-graph
    Net net;
    net=new Net(hashgraph);
    net.drive("tagion_service", master_net);
    // synchronized(master_net) {
    //     auto unshared_net = cast(SecureDriveNet)master_net;
    //     unshared_net.drive("tagion_service", net1);
    // }


    log("\n\n\n\n\n##### Received %s #####", opts.node_name);

    Tid monitor_socket_tid;
    Tid transaction_socket_tid;
    Tid transcript_tid;

    scope(exit) {
        log("!!!==========!!!!!! Existing %s", opts.node_name);

        if ( net.transcript_tid != net.transcript_tid.init ) {
            log("Send stop to %s", opts.transcript.task_name);
            net.transcript_tid.prioritySend(Control.STOP);
            if ( receiveOnly!Control is Control.END ) {
                log("Scripting api end!!");
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
            writefln("Send stop %s", opts.transaction.task_name);
            auto control=receiveOnly!Control;
            log("Control %s", control);
            if ( control is Control.END ) {
                log("Closed transaction");
            }
            else if ( control is Control.FAIL ) {
                log.error("Closed transaction with failure");
            }
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
                    else if ( ctrl is Control.FAIL ) {
                        log.error("Closed monitor with failure");
                    }
                },
                (immutable Exception e) {
                    ownerTid.prioritySend(e);
                });
        }


        log("End");
        ownerTid.prioritySend(Control.END);
    }


    // Pseudo passpharse
    // immutable passphrase=opts.node_name;
    // net.generateKeyPair(passphrase);

    ownerTid.send(net.pubkey);

    Pubkey[] received_pkeys;
    foreach(i;0..opts.nodes) {
        received_pkeys~=receiveOnly!(Pubkey);
        stderr.writefln("@@@@ Receive %s %s", opts.node_name, received_pkeys[i].cutHex);
    }
    immutable pkeys=assumeUnique(received_pkeys);

    hashgraph.createNode(net.pubkey);
    log("Ownkey %s num=%d", net.pubkey.cutHex, pkeys.length);
    stderr.writefln("@@@@ Ownkey %s num=%d", net.pubkey.cutHex, pkeys.length);
    foreach(i, p; pkeys) {
        if ( hashgraph.createNode(p) ) {
            log("%d] %s", i, p.cutHex);
        }
    }

    // scope tids=new Tid[N];
    // getTids(tids);
    net.set(pkeys);
    if ( ((opts.node_id < opts.monitor.max) || (opts.monitor.max == 0) ) &&
        (opts.monitor.port >= opts.min_port) ) {
        monitor_socket_tid = spawn(&monitorServiceTask, opts);
        Event.callbacks = new MonitorCallBacks(monitor_socket_tid, opts.node_id, net.globalNodeId(net.pubkey), opts.monitor.dataformat);
        stderr.writefln("@@@@ Wait for monitor %s", opts.node_name,);

        if ( receiveOnly!Control is Control.LIVE ) {
            log("Monitor started");
        }
    }

    stderr.writefln("@@@@ opts.transaction.port=%d", opts.transaction.service.port);
    // version(none)
    if ( ( (opts.node_id < opts.transaction.max) || (opts.transaction.max == 0) ) &&
        (opts.transaction.service.port >= opts.min_port) ) {
        transaction_socket_tid = spawn(&transactionServiceTask, opts);
        stderr.writefln("@@@@ Wait for transaction %s", opts.node_name);
        log("@@@@ Wait for transaction %s", opts.node_name);
        if ( receiveOnly!Control is Control.LIVE ) {
            log("Transaction started port %d", opts.transaction.service.port);
        }
        log("@@@@ after %s", opts.node_name);
    }

    // All tasks is in sync
    stderr.writefln("@@@@ All tasks are in sync %s", opts.node_name);
    log("All tasks are in sync %s", opts.node_name);

    //Event.scriptcallbacks=new ScriptCallbacks(thisTid);

//    version(none)
    //  if ( opts.transcript.enable ) {
    //version(none) {
    transcript_tid=spawn(&transcriptServiceTask, opts);


    Event.scriptcallbacks=new ScriptCallbacks(transcript_tid);
    if ( receiveOnly!Control is Control.LIVE ) {
        log("Transcript started");
    }
    //}

    enum max_gossip=2;
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

    auto net_random=cast(Net)net;
    enum bool has_random_seed=__traits(compiles, net_random.random.seed(0));
//    pragma(msg, has_random_seed);
    static if ( has_random_seed ) {
//        pragma(msg, "Random seed works");
        if ( !opts.sequential ) {
            net_random.random.seed(cast(uint)(Clock.currTime.toUnixTime!int));
        }
    }

    //
    // Start Script API task
    //

    Payload empty_payload;

    // Set thread global options


//    log("opts.sequential=%s", opts.sequential);
//        stdout.flush;
    immutable(ubyte)[] data;
    void receive_buffer(immutable(ubyte)[] buf) {
        timeout_count=0;
        net.time=net.time+100;
        log("\n*\n*\n*\n******* receive %s [%s] %s", opts.node_name, opts.node_id, buf.length);
        auto own_node=hashgraph.getNode(net.pubkey);

        Event register_leading_event(immutable(ubyte)[] father_fingerprint) @safe {
            auto mother=own_node.event;
            immutable ebody=immutable(EventBody)(empty_payload, mother.fingerprint,
                father_fingerprint, net.time, mother.altitude+1);
            const pack=net.buildEvent(ebody.toHiBON, ExchangeState.NONE);
            // immutable signature=net.sign(ebody);
            return hashgraph.registerEvent(net, net.pubkey, pack.signature, ebody);
        }
        event=net.receive(buf, &register_leading_event);
    }

    void next_mother(Payload payload) {
        auto own_node=hashgraph.getNode(net.pubkey);
        if ( (gossip_count >= max_gossip) || (payload.length) ) {
            // fout.writeln("After build wave front");
            if ( own_node.event is null ) {
                immutable ebody=immutable(EventBody)(net.evaPackage, null, null, net.time, net.eva_altitude);
                const pack=net.buildEvent(ebody.toHiBON, ExchangeState.NONE);
                // immutable signature=net.sign(ebody);
                event=hashgraph.registerEvent(net, net.pubkey, pack.signature, ebody);
            }
            else {
                auto mother=own_node.event;
                immutable mother_hash=mother.fingerprint;
                immutable ebody=immutable(EventBody)(payload, mother_hash, null, net.time, mother.altitude+1);
                const pack=net.buildEvent(ebody.toHiBON, ExchangeState.NONE);
                //immutable signature=net.sign(ebody);
                event=hashgraph.registerEvent(net,  net.pubkey, pack.signature, ebody);
            }
            immutable send_channel=net.selectRandomNode;
            auto send_node=hashgraph.getNode(send_channel);
            if ( send_node.state is ExchangeState.NONE ) {
                send_node.state = ExchangeState.INIT_TIDE;
                auto tidewave   = new HiBON;
                auto tides      = net.tideWave(tidewave, net.callbacks !is null);
                auto pack       = net.buildEvent(tidewave, ExchangeState.TIDAL_WAVE);

                net.send(send_channel, pack.toHiBON.serialize);
                if ( net.callbacks ) {
                    net.callbacks.sent_tidewave(send_channel, tides);
                }
            }
            gossip_count=0;
        }
        else {
            gossip_count++;
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

    log("SEQUENTIAL=%s", opts.sequential);
    ownerTid.send(Control.LIVE);
    while(!stop) {
        if ( opts.sequential ) {
            immutable message_received=receiveTimeout(
                opts.timeout.msecs,
                &receive_payload,
                &controller,
                &sequential,
                &receive_buffer,
                &tagionexception,
                &exception,
                &throwable,

                );
            if ( !message_received ) {
                log("TIME OUT");
                timeout_count++;
                if ( !net.queue.empty ) {
                    receive_buffer(net.queue.read);
                }
            }
        }
        else {
            immutable message_received=receiveTimeout(
                opts.timeout.msecs,
                &receive_payload,
                &controller,
                // &sequential,
                &receive_buffer,
                &tagionexception,
                &exception,
                &throwable,
                );
            if ( !message_received ) {
                log("TIME OUT");
                writefln("TIME OUT %d", opts.node_id);
                timeout_count++;
                net.time=Clock.currTime.toUnixTime!long;
                if ( !net.queue.empty ) {
                    receive_buffer(net.queue.read);
                }
                next_mother(empty_payload);
            }
        }
    }
}
