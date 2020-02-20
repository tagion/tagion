module tagion.services.HeartBeatService;

import core.thread;
import std.concurrency;

import tagion.Options;

//import tagion.services.ServiceNames;

//import tagion.services.LoggerService;
import tagion.utils.Random;

import tagion.Base : Pubkey, Control;
import tagion.services.LoggerService;
import tagion.services.TagionService;
import tagion.gossip.EmulatorGossipNet;
import tagion.gossip.InterfaceNet : SecureNet;
import tagion.gossip.GossipNet : StdSecureNet;
import tagion.services.ServiceNames : get_node_name;
import tagion.TagionExceptions;
import p2plib = p2p.node;
import tagion.services.DartSynchronizeService;
import tagion.dart.DARTSynchronization;
import tagion.dart.DART;
import std.conv;
shared bool abort=false;
version(SIG_SHORTDOWN){
import core.stdc.signal;
static extern(C) void shutdown(int sig) @nogc nothrow {

    printf("Shutdown sig %d about=%d\n\0".ptr, sig, abort);
    if (sig is SIGINT || sig is SIGTERM) {
        abort=true;
    }
//    printf("Shutdown sig %d\n\0".ptr, sig);
}

shared static this() {

    signal(SIGINT, &shutdown);
    signal(SIGTERM, &shutdown);
}
}
import std.stdio;
void heartBeatServiceTask(immutable(Options) opts) {
    setOptions(opts);

    immutable tast_name=opts.heartbeat.task_name;

    Tid[] tids;
    Pubkey[]  pkeys;

    log.register(tast_name);
    scope(exit) {
        log("----- Stop all tasks -----");
        uint number_of_active_tids;
        foreach(i, ref tid; tids) {
            immutable node_name=get_node_name(opts, i);
//            writefln("node_name=%s", node_name, );
            auto locate_tid=locate(node_name);
            writefln("node_name=%s %s", node_name, locate_tid);

            if (locate_tid != Tid.init) {
                writefln("Send stop to %d", i);
                log("Send stop to %d", i);
                tid.prioritySend(Control.STOP);
                number_of_active_tids++;
            }
        }
        foreach(i; 0..number_of_active_tids) {
            auto control=receiveOnly!Control;
            if ( control is Control.END ) {
                log("Thread %s stopped %s", get_node_name(opts, i), control);
            }
            else {
                log("Thread %s unexpected control %s", get_node_name(opts, i), control);
            }
        }
        log("----- Stop send to all -----");
        log.close;
        ownerTid.prioritySend(Control.END);
    }

    stderr.writeln("@@@@@ Before node loop");
    auto sector_range = DART.SectorRange(0,0);
    Tid[] dart_sync_tids;
    scope(exit) {
        log("---- Stop dart sync tasks(%d) ----", dart_sync_tids.length);
        foreach(id, dart_sync_tid; dart_sync_tids){
            log("Send stop to %d dart_sync_service", id);
            send(dart_sync_tid, Control.STOP);
            const dartSyncControl = receiveOnly!Control;
            log("received control %s from %d dart_sync_service", dartSyncControl, id);
        }
    }
    foreach (i; 0..opts.nodes) {
        auto local_port = opts.port_base + i;
        if(i==0){
            local_port = opts.dart.sync.maxSlavePort;
        }
        auto p2pnode = new shared(p2plib.Node)("/ip4/0.0.0.0/tcp/" ~ to!string(local_port), 0);
        auto master_net=new StdSecureNet;
        synchronized(master_net) {
            import std.format;
            immutable passphrase=format("Secret_word_%d",i).idup;

            master_net.generateKeyPair(passphrase);
            shared shared_net=cast(shared)master_net;
            auto dart_sync_tid = spawn(&dartSynchronizeServiceTask!StdSecureNet, opts, p2pnode, shared_net, sector_range, i);
            dart_sync_tids ~= dart_sync_tid;
        }
        // dartTid = spawn(&dartServiceTask!MyFakeNet, local_options, node, shared_net, sector_range);
    }
    uint ready_counter = opts.nodes;
    do{
        receive(
            (Control control){

            },
            (DartSynchronizeState state, uint id){
                // writefln("!!received from %d state: %s", id, state);
                if(state == DartSynchronizeState.READY){
                    log("%d sync finished", id);
                    ready_counter--;
                }
            }
        );
    }while(ready_counter>0);
    log("All nodes synchronized");
    foreach(i;0..opts.nodes) {
        log("node=%s", i);
        stderr.writefln("node=%s", i);
        Options service_options=opts;
        if ( (opts.monitor.port >= opts.min_port) && ((opts.monitor.max == 0) || (i < opts.monitor.max) ) ) {
            service_options.monitor.port=cast(ushort)(opts.monitor.port + i);
        }
        // if ( (opts.transaction.port >= opts.min_port) && ((opts.transaction.max == 0) || (i < opts.transaction.max)) ) {
        //     service_options.transaction.port=cast(ushort)(opts.transaction.port + i);
        // }
        if ( (opts.transaction.service.port >= opts.min_port) && ((opts.transaction.max == 0) || (i < opts.transaction.max)) ) {
            service_options.transaction.service.port=cast(ushort)(opts.transaction.service.port + i);
        }
        service_options.node_id=cast(uint)i;
        Tid tid;

        auto master_net=new StdSecureNet;
        synchronized(master_net) {
            import std.format;
            immutable passphrase=format("Secret_word_%d",i).idup;

            master_net.generateKeyPair(passphrase);
            shared shared_net=cast(shared)master_net;
            tid=spawn(&(tagionServiceTask!EmulatorGossipNet), service_options, shared_net);
        }

        tids~=tid;
        pkeys~=receiveOnly!(Pubkey);
        log("Start %d", pkeys.length);
        writefln("@@@@@ Start %d", pkeys.length);

    }

    log("----- Receive sync signal from nodes -----");

    log("----- Send acknowlege signals  num of keys=%d -----", pkeys.length);

    foreach(ref tid; tids) {
        foreach(pkey; pkeys) {
            tid.send(pkey);
        }
    }

    uint count = opts.loops;

    size_t count_down=tids.length;

    bool stop=false;
    if ( opts.sequential ) {
        Thread.sleep(1.seconds);
        log("Start the heart beat");
        uint node_id;
        uint time=opts.delay;
        Random!uint rand;
        rand.seed(opts.seed);
        while(!stop) {
            if ( !opts.infinity ) {
                log("count=%d", count);
            }
            Thread.sleep(opts.delay.msecs);

            tids[node_id].send(time, rand.value);
            if ( !opts.infinity ) {
                log("send time=%d to  %d", time, node_id);
            }

            time+=opts.delay;
            node_id++;
            if ( node_id >= tids.length ) {
                node_id=0;
            }

            if ( !opts.infinity ) {
                stop=(count==0);
                count--;
            }
        }
    }
    else {
        // Thread.sleep(1.seconds);
        log("Start the heatbeat in none sequential mode");
        while(!stop && !abort) {
            stderr.writef("* %s ", abort);
            immutable message_received=receiveTimeout(
                opts.delay.msecs,
                (Control ctrl) {
                    with(Control) {
                        switch(ctrl) {
                        case STOP, FAIL:
                        stop=true;
                        break;
                        case LIVE:
                        count_down--;
                        if (count_down == 0 ) {
                            log("HEARTBEAT STARTED");
                        }
                        break;
                        // case END:
                        // stop=true;
                        // break;
                        // case FAIL:
                        // stop=true;
                        // break;
                        default:
                        log.error("Control %s unexpected", ctrl);
                        }
                    }
                },
                (immutable(TagionException) e) {
                    stop=true;
                    const print_e=e;
                    print_e.toString((buf) {log.fatal(buf.idup);});
                    // const print_e=cast(const)e;
                    // pragma(msg, typeof(e), " ", typeof(print_e));
                    // print_e.toString((string buf) {log.error(buf);});
                    stderr.writeln(e);
                },
                (immutable(Exception) e) {
                    stop=true;
                    const print_e=e;
                    print_e.toString((buf) {log.fatal(buf.idup);});
                    stderr.writeln(e);
                },
                (immutable(Throwable) t) {
                    stop=true;
                    const print_t=t;
                    print_t.toString((buf) {log.fatal(buf.idup);});
                    stderr.writeln(t);
                }
                );
            if (message_received) {
                log("count down=%s", count_down);
            }
            else if ( !opts.infinity ) {
                if (count_down == 0) {
                    stop=(count==0);
                    stderr.writefln("count=%d", count);
                    log("count=%d", count);
                    count--;
                }
            }

        }
    }
}
