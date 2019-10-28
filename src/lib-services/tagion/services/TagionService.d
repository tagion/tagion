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
import tagion.hashgraph.ConsensusExceptions;
import tagion.gossip.InterfaceNet;
import tagion.gossip.EmulatorGossipNet;
import tagion.TagionExceptions : TagionException;


import tagion.services.ScriptCallbacks;
import tagion.crypto.secp256k1.NativeSecp256k1;

import tagion.communication.Monitor;
//import tagion.services.ServiceNames;
import tagion.services.MonitorService;
import tagion.services.TransactionService;
import tagion.services.TranscriptService;
import tagion.services.ScriptingEngineService;
import tagion.services.LoggerService;

import tagion.Options : Options, setOptions, options;
import tagion.Base : Pubkey, Payload, Control;
import tagion.hibon.HiBON : HiBON;


// If no monitor should be enable set the address to empty or the port below 6000.
// void tagionNode(Net)(uint timeout, immutable uint node_id,
//     immutable uint N,
//     string monitor_ip_address,
//     const ushort monitor_port)  {
void tagionServiceTask(Net)(immutable(Options) args) {
    setOptions(args);
    Options opts=args;
    writefln("options.nodeprefix=%s", options.nodeprefix);
//    opts.node_name=node_task_name(args.node_id);
    writefln("opts.monitor.task_name=%s", opts.monitor.task_name);
//    opts.monitor.task_name=monitor_task_name(opts);
//    opts.transaction.task_name=transaction_task_name(opts);
//  opts.transcript.task_name=transcript_task_name(opts);
//    opts.scripting_engine.task_name=scripting_engine_task_name(opts);
//    opts.dart.task_name=dart_task_name(opts);
    setOptions(opts);

//    immutable task_name=get_node_name(opts.node_id);
    writefln("task_name=%s options.mode_name=%s", opts.node_name, options.node_name);
    log.register(opts.node_name);
//    HRPC hrpc;
    import std.format;
    import std.datetime.systime;
//    immutable node_name=getname(options.node_id);
    immutable filename=[opts.node_name].getfilename;
//    Net.fout.open(filename, "w");
//    alias fout=Net.fout;
    //Event.fout=&fout;


    log("\n\n\n\n\nx##### Received %s #####", opts.node_name);

    Tid monitor_socket_tid;
    Tid transaction_socket_tid;

    auto hashgraph=new HashGraph();
    // Create hash-graph
    ScriptNet net;
    auto crypt=new NativeSecp256k1;
    net=new Net(crypt, hashgraph);
//    hrpc.net=net;

//    immutable transcript_enable=opts.transcript.enable;

//    debug {
//    net.node_name=opts.node_name;
//    }
    // Pseudo passpharse
    immutable passphrase=opts.node_name;
    net.generateKeyPair(passphrase);


    ownerTid.send(net.pubkey);
    Pubkey[] received_pkeys; //=receiveOnly!(immutable(Pubkey[]));
    foreach(i;0..opts.nodes) {
        received_pkeys~=receiveOnly!(Pubkey);
    }
    immutable pkeys=assumeUnique(received_pkeys);

    hashgraph.createNode(net.pubkey);
    log("Ownkey %s num=%d", net.pubkey.cutHex, pkeys.length);
    foreach(i, p; pkeys) {
        if ( hashgraph.createNode(p) ) {
            log("%d] %s", i, p.cutHex);
        }
    }
    // All tasks is in sync
    log("All tasks are in sync %s", opts.node_name);
    // scope tids=new Tid[N];
    // getTids(tids);
    net.set(pkeys);
    if ( opts.url !is null ) {
        if  (opts.monitor.port > 6000) {
            monitor_socket_tid = spawn(&monitorServiceTask, opts);
            log("opts.node_name=%s options.node_name=%s", opts.node_name, options.node_name);
            Event.callbacks = new MonitorCallBacks(monitor_socket_tid, opts.node_id, net.globalNodeId(net.pubkey));
        }

        if ( opts.transaction.port > 6000) {
            transaction_socket_tid = spawn(&transactionServiceTask, opts);
//            log("opts.node_name=%s options.node_name=%s", opts.node_name, options.node_name);
//            Event.callbacks = new MonitorCallBacks(monitor_socket_tid, opts.node_id, net.globalNodeId(net.pubkey));
        }
    }
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
    Thread.sleep(2.seconds);

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

    if ( opts.transcript.enable ) {
//        net.transcript_tid=spawn(&transcriptServiceThread!Net, setup);
        net.transcript_tid=spawn(&transcriptServiceTask, opts);

        auto scripting_engine_tid=spawn(&scriptingEngineTask, opts);
        Event.scriptcallbacks=new ScriptCallbacks(scripting_engine_tid);
    }

    scope(exit) {
//        fout.flush;
        log("!!!==========!!!!!! Existing hasnode %s", opts.node_name);
        log("Send stop to the transcript");
//        fout.flush;

        if ( net.transcript_tid != net.transcript_tid.init ) {
            log("net.transcript_tid.prioritySend(Control.STOP)");
//            fout.flush;

            net.transcript_tid.prioritySend(Control.STOP);
            if ( receiveOnly!Control == Control.END ) {
                log("Scripting api end!!");
            }
        }

        log("Send stop to the engine");
//        fout.flush;
        if ( Event.scriptcallbacks ) {
            if ( Event.scriptcallbacks.stop && (receiveOnly!Control == Control.END) ) {
                log("Scripting engine end!!");
            }
        }

//        log("Existing hasnode %s", opts.node_name);
//        fout.flush;
        if ( net.callbacks ) {
            net.callbacks.exiting(hashgraph.getNode(net.pubkey));
        }
//        log("$$$$$$Closed monitor %s", opts.node_name);
//        fout.flush;
        // Thread.sleep(2.seconds);
        if ( transaction_socket_tid != transaction_socket_tid.init ) {
            transaction_socket_tid.prioritySend(Control.STOP);
            auto control=receiveOnly!Control;
            log("Control %s", control);
//            fout.flush;
            if ( control == Control.END ) {
                log("Closed transaction thread");
            }
            else if ( control == Control.FAIL ) {
                log.error("Closed transaction thread with failure");
            }
        }
        if ( monitor_socket_tid != monitor_socket_tid.init ) {
            log("Send STOP %s", opts.node_name);
//            fout.flush;

            monitor_socket_tid.prioritySend(Control.STOP);

            log("after STOP %s", opts.node_name);
//            fout.flush;
            auto control=receiveOnly!Control;
            log("Control %s", control);
//            fout.flush;
            if ( control == Control.END ) {
                log("Closed monitor thread");
            }
            else if ( control == Control.FAIL ) {
                log.error("Closed monitor thread with failure");
            }
        }
        log("prioritySend %s", opts.node_name);
        log("End");
        ownerTid.prioritySend(Control.END);
    }

    Payload empty_payload;

    // Set thread global options

    while(!stop) {

        log("opts.sequential=%s", opts.sequential);
//        stdout.flush;
        immutable(ubyte)[] data;
        void receive_buffer(immutable(ubyte)[] buf) {
            timeout_count=0;
            net.time=net.time+100;
            log("*\n*\n*\n");
            log("*\n*\n*\n******* receive %s [%s] %s", opts.node_name, opts.node_id, buf.length);
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
            if ( gossip_count >= max_gossip ) {
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
                if ( send_node.state is  ExchangeState.NONE ) {
                    send_node.state = ExchangeState.INIT_TIDE;
                    auto tidewave   = new HiBON;
                    auto tides      = net.tideWave(tidewave, net.callbacks !is null);
                    auto pack       = net.buildEvent(tidewave, ExchangeState.TIDE_WAVE);

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
                    log("##### Stop %s", opts.node_name);
                    break;
                default:
                    log.error("Unsupported control %s", ctrl);
                }
        }

        void tagionexception(immutable(TagionException) e) {
            stop=true;
            ownerTid.send(e);
        }

        void exception(immutable(Exception) e) {
            stop=true;
            ownerTid.send(e);
        }

        void throwable(immutable(Throwable) t) {
            stop=true;
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
        try {
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
                    timeout_count++;
                    net.time=Clock.currTime.toUnixTime!long;
                    if ( !net.queue.empty ) {
                        receive_buffer(net.queue.read);
                    }
                    next_mother(empty_payload);
                }
            }
        }
        catch ( ConsensusException e ) {
            log.error("Consensus fail %s: %s. code=%s\n%s", opts.node_name, e.msg, e.code, typeid(e));
            stop=true;
            if ( net.callbacks ) {
                net.callbacks.consensus_failure(e);
            }
            ownerTid.send(cast(immutable)e);
        }
        catch ( Exception e ) {
            auto msg=format("%s: %s\n%s", opts.node_name, e.msg, typeid(e));
            log.fatal(msg);
            // fout.writeln(msg);
            // writeln(msg);
            stop=true;
            ownerTid.send(cast(immutable)e);
        }
        catch ( Throwable t ) {
            t.msg ~= format(" - From hashnode thread %s", opts.node_id);
            log.fatal(t.msg);
            // fout.writeln(t);
            // writeln(t);
            stop=true;
            ownerTid.send(cast(immutable)t);
        }

    }
}
