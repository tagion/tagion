module tagion.services.TagionNode;

import std.concurrency;
import std.exception : assumeUnique;
import std.stdio;
import std.conv : to;

import core.thread;

import tagion.utils.Miscellaneous: cutHex;
import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.ConsensusExceptions;
import tagion.hashgraph.GossipNet;
import tagion.hashgraph.EmulatorGossipNet;
import tagion.services.ScriptingEngineNode;
import tagion.services.TranscriptNode;
import tagion.services.ScriptCallbacks;

import tagion.communication.Monitor;
import tagion.Options;
import tagion.Base : Pubkey, Payload, Control;
import tagion.utils.BSON : HBSON;

// If no monitor should be enable set the address to empty or the port below 6000.
void tagionNode(uint timeout, immutable uint node_id,
    immutable uint N,
    string monitor_ip_address,
    const ushort monitor_port) {
    import std.format;
    import std.datetime.systime;
    immutable node_name=getname(node_id);
    immutable filename=[node_name].getfilename;
    //-----
    alias Net=EmulatorGossipNet;
    Net.Init setup;

    //---

    EmulatorGossipNet.fout.open(filename, "w");

    alias fout=EmulatorGossipNet.fout;
    Event.fout=&fout;

    fout.write("\n\n\n\n\n");
    fout.writefln("##### Received %s #####", node_name);

    Tid monitor_socket_tid;

    auto hashgraph=new HashGraph();
    // Create hash-graph
    auto net=new EmulatorGossipNet(hashgraph);

    immutable transcript_enable=options.transcript.enable;

    debug {
        net.node_name=node_name;
    }
    // Pseudo passpharse
    immutable passphrase=node_name;
    net.generateKeyPair(passphrase);


    ownerTid.send(net.pubkey);
    Pubkey[] received_pkeys; //=receiveOnly!(immutable(Pubkey[]));
    foreach(i;0..N) {
        received_pkeys~=receiveOnly!(Pubkey);
    }
    immutable pkeys=assumeUnique(received_pkeys);

    hashgraph.createNode(net.pubkey);
    fout.writefln("Ownkey %s num=%d", net.pubkey.cutHex, pkeys.length);
    foreach(i, p; pkeys) {
        if ( hashgraph.createNode(p) ) {
            fout.writefln("%d] %s", i, p.cutHex);
        }
    }
    // All tasks is in sync
    fout.writefln("All tasks are in sync %s", node_name);
    // scope tids=new Tid[N];
    // getTids(tids);
    net.set(pkeys);

    if ( (monitor_ip_address != "") && (monitor_port > 6000) ) {
        monitor_socket_tid = spawn(&createSocketThread, monitor_port, monitor_ip_address);

        Event.callbacks = new MonitorCallBacks(monitor_socket_tid, node_id, net.globalNodeId(net.pubkey));
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
    writefln("Wait for some delay %s", node_name);
    Thread.sleep(2.seconds);

    if ( !options.sequential ) {
        net.random.seed(cast(uint)(Clock.currTime.toUnixTime!int));
    }

    //
    // Start Script API task
    //

    if ( transcript_enable ) {
        net.transcript_tid=spawn(&transcript!Net, setup);

        auto scripting_engine_tid=spawn(&scripting_engine, node_id);
        Event.scriptcallbacks=new ScriptCallbacks(scripting_engine_tid);
    }

    scope(exit) {
        fout.flush;
        writefln("!!!==========!!!!!! Existing hasnode %s", node_name);
        fout.writefln("Send stop to the transcript");
        fout.flush;

        if ( net.transcript_tid != net.transcript_tid.init ) {
            fout.writeln("net.transcript_tid.prioritySend(Control.STOP)");
            fout.flush;

            net.transcript_tid.prioritySend(Control.STOP);
            if ( receiveOnly!Control == Control.END ) {
                fout.writeln("Scripting api end!!");
            }
        }

        fout.writefln("Send stop to the engine");
        fout.flush;
        if ( Event.scriptcallbacks ) {
            if ( Event.scriptcallbacks.stop && (receiveOnly!Control == Control.END) ) {
                fout.writeln("Scripting engine end!!");
            }
        }

        fout.writefln("Existing hasnode %s", node_name);
        fout.flush;
        if ( net.callbacks ) {
            net.callbacks.exiting(hashgraph.getNode(net.pubkey));
        }
        fout.writefln("$$$$$$Closed monitor %s", node_name);
        fout.flush;
        // Thread.sleep(2.seconds);
        if ( monitor_socket_tid != monitor_socket_tid.init ) {
            fout.writefln("Send STOP %s", node_name);
            fout.flush;
            monitor_socket_tid.prioritySend(Control.STOP);

            fout.writefln("after STOP %s", node_name);
            fout.flush;
            auto control=receiveOnly!Control;
            fout.writefln("Control %s", control);
            fout.flush;
            if ( control == Control.END ) {
                fout.writeln("Closed monitor thread");
            }
            else if ( control == Control.FAIL ) {
                fout.writeln("Closed monitor thread with failure");
            }
            fout.flush;
        }
//        Thread.sleep(2.seconds);
        //      version(none) {


        // }
        fout.writefln("prioritySend %s", node_name);
        fout.writefln("End");
        fout.close;
        ownerTid.prioritySend(Control.END);
    }

    Payload empty_payload;

    while(!stop) {
        immutable(ubyte)[] data;
        void receive_buffer(immutable(ubyte)[] buf) {
            timeout_count=0;
            net.time=net.time+100;
            fout.write("*\n*\n*\n");
            fout.writefln("******* receive %s [%s] %s", node_name, node_id, buf.length);
            auto own_node=hashgraph.getNode(net.pubkey);

            Event register_leading_event(immutable(ubyte)[] father_fingerprint) @safe {
                auto mother=own_node.event;
                immutable ebody=immutable(EventBody)(empty_payload, mother.fingerprint,
                    father_fingerprint, net.time, mother.altitude+1);
                immutable signature=net.sign(ebody);
                return hashgraph.registerEvent(net, net.pubkey, signature, ebody);
            }
            event=net.receive(buf, &register_leading_event);
        }

        void next_mother(Payload payload) {
            auto own_node=hashgraph.getNode(net.pubkey);
            if ( gossip_count >= max_gossip ) {
                // fout.writeln("After build wave front");
                if ( own_node.event is null ) {
                    immutable ebody=immutable(EventBody)(net.evaPackage, null, null, net.time, net.eva_altitude);
                    immutable signature=net.sign(ebody);
                    event=hashgraph.registerEvent(net,  net.pubkey, signature, ebody);
                }
                else {
                    auto mother=own_node.event;
                    immutable mother_hash=mother.fingerprint;
                    immutable ebody=immutable(EventBody)(payload, mother_hash, null, net.time, mother.altitude+1);
                    immutable signature=net.sign(ebody);
                    event=hashgraph.registerEvent(net,  net.pubkey, signature, ebody);
                }
                immutable send_channel=net.selectRandomNode;
                auto send_node=hashgraph.getNode(send_channel);
                if ( send_node.state == ExchangeState.NONE ) {
                    send_node.state=ExchangeState.INIT_TIDE;
                    auto tidewave=new HBSON;
                    auto tides = net.tideWave(tidewave, net.callbacks !is null);
                    auto pack=net.buildEvent(tidewave, ExchangeState.TIDE_WAVE);
                    net.send(send_channel, pack);
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
            fout.writefln("payload.length=%d", pload.length);
            next_mother(pload);
        }

        void controller(Control ctrl) {
            with(Control) switch(ctrl) {
                case STOP:
                    stop=true;
                    fout.writefln("##### Stop %s", node_name);
                    break;
                default:
                    fout.writefln("Unsupported control %s", ctrl);
                }
        }

        void sequential(uint time, uint random)
            in {
                assert(options.sequential);
            }
        do {

            immutable(ubyte[]) payload;
            net.random.seed(random);
            net.time=time;
            next_mother(empty_payload);
        }

        try {
            if ( options.sequential ) {
                immutable message_received=receiveTimeout(timeout.msecs,
                    &receive_payload,
                    &controller,
                    &sequential,
                    &receive_buffer,
                    );
                if ( !message_received ) {
                    fout.writeln("TIME OUT");
                    timeout_count++;
                    if ( !net.queue.empty ) {
                        receive_buffer(net.queue.read);
                    }
                }
            }
            else {
                immutable message_received=receiveTimeout(timeout.msecs,
                    &receive_payload,
                    &controller,
                    // &sequential,
                    &receive_buffer,
                    );
                if ( !message_received ) {
                    fout.writeln("TIME OUT");
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
            fout.writefln("Consensus fail %s: %s. code=%s\n%s", node_name, e.msg, e.code, typeid(e));
            stop=true;
            if ( net.callbacks ) {
                net.callbacks.consensus_failure(e);
            }
        }
        catch ( Exception e ) {
            auto msg=format("Error %s: %s\n%s", node_name, e.msg, typeid(e));
            fout.writeln(msg);
            writeln(msg);
            stop=true;
        }
        catch ( Throwable t ) {
            t.msg ~= " - From hashnode thread " ~ to!string(node_id);
            fout.writeln(t);
            writeln(t);
            stop=true;
            throw t;
        }

    }
}
