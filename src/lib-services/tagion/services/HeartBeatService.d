module tagion.services.HeartBeatService;

import core.thread;
import std.concurrency;
import std.range : lockstep;

import tagion.Options;

import tagion.utils.Random;

import tagion.GlobalSignals : abort;
import tagion.basic.Basic : Pubkey, Control;
import tagion.basic.Logger;
import tagion.services.TagionService;
import tagion.gossip.EmulatorGossipNet;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.ServiceNames : get_node_name;
import tagion.basic.TagionExceptions;
import p2plib = p2p.node;
import tagion.services.DartService;
import tagion.services.DartSynchronizeService;
import tagion.dart.DARTSynchronization;
import tagion.dart.DART;
import std.conv;

import tagion.gossip.P2pGossipNet : ActiveNodeAddressBook;
import tagion.services.MdnsDiscoveryService;

import tagion.Keywords: NetworkMode;

import std.stdio;
void heartBeatServiceTask(immutable(Options) opts) nothrow
    in{
        assert(opts.net_mode == NetworkMode.internal);
    }
do {
    try {
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
                    log.warning("Unexpected control code %s", control);
                }

                // else {
                //     log("Thread %s unexpected control %s", get_node_name(opts, i), control);
                // }
            }
            log("----- Stop send to all -----");
            log.close;
            ownerTid.prioritySend(Control.END);
        }

        stderr.writeln("@@@@@ Before node loop");
        auto sector_range = DART.SectorRange(0,0);
        auto dart_sync_tids=new Tid[opts.nodes];
        auto dart_tids = new Tid[opts.nodes];
        auto discovery_tids = new Tid[opts.nodes];

        scope(exit) {
            log("---- Stop discovery tasks(%d) ----", discovery_tids.length);
            foreach (i; 0..opts.nodes) {
                auto discovery_tid = locate(opts.discovery.task_name~to!string(i));
                if(discovery_tid != Tid.init){
                    send(discovery_tid, Control.STOP);
                    const discoveryControl = receiveOnly!Control;
                }
                else{
                    log("couldn't locate task: %s", opts.discovery.task_name~to!string(i));
                }
            }
            log("---- Stop dart tasks(%d) ----", dart_tids.length);
            foreach (i; 0..opts.nodes) {
                auto dart_tid = locate(opts.dart.task_name~to!string(i));
                if(dart_tid != Tid.init){
                    send(dart_tid, Control.STOP);
                    const dartControl = receiveOnly!Control;
                }
                else{
                    log("couldn't locate task: %s", opts.dart.task_name~to!string(i));
                }
            }
            log("---- Stop dart sync tasks(%d) ----", dart_sync_tids.length);
            foreach (i; 0..opts.nodes) {
                auto dart_sync_tid = locate(opts.dart.sync.task_name~to!string(i));
                if(dart_sync_tid != Tid.init){
                    send(dart_sync_tid, Control.STOP);
                    const dartSyncControl = receiveOnly!Control;
                }
                else{
                    log("couldn't locate task: %s", opts.dart.sync.task_name~to!string(i));
                }
            }
        }
        import std.array: replace;
        import std.string: indexOf;
        import std.file: mkdir, exists;

        Options[uint] node_opts;
        foreach (i; 0..opts.nodes) {
            const is_master_node = i == 0;
            Options service_options=opts;

            service_options.node_id=cast(uint)i;
            auto local_port = opts.port_base + i;
            service_options.dart.initialize = true;
            if(is_master_node){
                service_options.dart.initialize = opts.dart.initialize;
                service_options.dart.synchronize = false;
                local_port = opts.dart.sync.maxSlavePort;
                service_options.discovery.notify_enabled = true;
            }

            service_options.port = local_port;
            enum dir_token = "%dir%";
            if(opts.dart.path.indexOf(dir_token) != -1){
                auto path_to_dir = service_options.dart.path[0..opts.dart.path.indexOf(dir_token)]~"node"~to!string(i);
                if(!path_to_dir.exists) path_to_dir.mkdir;
                service_options.dart.path = opts.dart.path.replace(dir_token, "node"~to!string(i));
            }
            else{
                import std.path;
                if(!is_master_node){
                    pragma(msg, "fixme(): Use buildpath/path functions instead of string concat");
                    service_options.dart.path = stripExtension(opts.dart.path) ~ to!string(i) ~ extension(opts.dart.path);
                }
            }
            service_options.transaction.service.response_task_name = opts.transaction.service.response_task_name~to!string(i);
            service_options.dart.task_name = opts.dart.task_name~to!string(i);
            service_options.dart.sync.task_name = opts.dart.sync.task_name~to!string(i);
            service_options.discovery.task_name = opts.discovery.task_name~to!string(i);
            if ( (opts.monitor.port >= opts.min_port) && ((opts.monitor.max == 0) || (i < opts.monitor.max) ) ) {
                service_options.monitor.port=cast(ushort)(opts.monitor.port + i);
            }
            // if ( (opts.transaction.port >= opts.min_port) && ((opts.transaction.max == 0) || (i < opts.transaction.max)) ) {
            //     service_options.transaction.port=cast(ushort)(opts.transaction.port + i);
            // }
            if ( (opts.transaction.service.port >= opts.min_port) && ((opts.transaction.max == 0) || (i < opts.transaction.max)) ) {
                service_options.transaction.service.port=cast(ushort)(opts.transaction.service.port + i);
            }

            node_opts[i] = service_options;
        }
        log("options configurated");
        foreach (i, ref discovery_tid, ref dart_sync_tid, ref dart_tid;lockstep(discovery_tids, dart_sync_tids, dart_tids)) {
//    foreach (i; 0..opts.nodes) {
            auto sync_opts = node_opts[cast(uint)i];

            auto p2pnode = new shared(p2plib.Node)("/ip4/0.0.0.0/tcp/" ~ to!string(sync_opts.port), 0);
            auto master_net=new StdSecureNet;
            synchronized(master_net) {
                import std.format;
                immutable passphrase=format("Secret_word_%d",i).idup;

                pragma(msg, "fixme(alex): This temporary");
                master_net.generateKeyPair(passphrase);
                shared shared_net=cast(shared)master_net;
                discovery_tid = spawn(&mdnsDiscoveryService, p2pnode, sync_opts);
                //discovery_tids~=discovery_tid;

                dart_sync_tid = spawn(&dartSynchronizeServiceTask!StdSecureNet, sync_opts, p2pnode, shared_net, sector_range);
                //dart_sync_tids ~= dart_sync_tid;

                dart_tid = spawn(&dartServiceTask!StdSecureNet, sync_opts, p2pnode, shared_net, sector_range);
                //dart_tids ~= dart_tid;
                // send(dart_sync_tid, cast(immutable) address_book);
            }
            // const service_control = receiveOnly!Control;
            // log("received %s from %d", service_control, i);
            // assert(service_control == Control.LIVE);
            // dartTid = spawn(&dartServiceTask!MyFakeNet, local_options, node, shared_net, sector_range);
        }

        uint ready_counter = opts.nodes;
        uint live_counter = opts.nodes * 3;
        bool force_stop = false;
        do {
            receive(
                (Control control){
                    with(Control) {
                        switch(control) {
                        case LIVE:
                            live_counter--;
                            break;
                        case END:
                            live_counter--;
                            break;
                        case STOP:
                            force_stop = true;
                            break;
                        default:
                            log.error("Illegal control %s", control);
                        }
                    }
                },
                (ActiveNodeAddressBook address_book){
                    log("received address book");
                    foreach (ref discovery_tid; discovery_tids){
                        discovery_tid.send(Control.STOP);
                        receiveOnly!Control;    //use receive instead..
                    }
                    log("discovery services stoped");
                    foreach (ref dart_sync_tid; dart_sync_tids) {
                        dart_sync_tid.send(address_book);
                    }
                },
                (DartSynchronizeState state){
                    // writefln("!!received from %d state: %s", id, state);
                    if(state == DartSynchronizeState.READY){
                        ready_counter--;
                    }
                },
                (immutable(TaskFailure) t) {
                    ownerTid.send(t);
                }
                // (immutable(Exception) e) {
                //     ownerTid.send(e);
                //     // force_stop = true;
                // },
                // (immutable(Throwable) t) {
                //     ownerTid.send(t);
                //     // force_stop = true;
                // }
                );
            if ((force_stop || abort) && live_counter <=0) break;
        } while(ready_counter>0);

        if(force_stop || abort) return;

        log("All nodes synchronized");
        foreach(i;0..opts.nodes) {
            log("node=%s", i);
            stderr.writefln("node=%s", i);
            Options service_options=node_opts[i];

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
//        writefln("@@@@@ Start %d", pkeys.length);

        }

        log("----- Receive sync signal from nodes -----");

        log("----- Send acknowlege signals  num of keys=%d -----", pkeys.length);

        foreach(ref tid; tids) {
            foreach(pkey; pkeys) {
                tid.send(pkey);
            }
        }

        void taskfailure(immutable(TaskFailure) t) {
            ownerTid.send(t);
            abort=true;
            log.silent=true;
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
            while(!stop && !abort) {
                if ( !opts.infinity ) {
                    log("count=%d", count);
                }
//            Thread.sleep(opts.delay.msecs);
                immutable message_received=receiveTimeout(
                    opts.delay.msecs,
                    (Control ctrl) {
                        with(Control) {
                            switch(ctrl) {
                            case STOP:
                                stop=true;
                                break;
                            default:
                            }
                        }
                    },
                    &taskfailure
                    );
                if (!message_received) {
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
        }
        else {
            // Thread.sleep(1.seconds);
            log("Start the heatbeat in none sequential mode");
            while(!stop && !abort) {
                stderr.write("> ");
                immutable message_received=receiveTimeout(
                    opts.delay.msecs,
                    (Control ctrl) {
                        with(Control) {
                            switch(ctrl) {
                            case STOP:
                                stop=true;
                                break;
                            case LIVE:
                                count_down--;
                                if (count_down == 0 ) {
                                    log("HEARTBEAT STARTED");
                                }
                                break;
                            case END:
                                count_down++;
                                stop=true;
                                log.error("Unexpected %s count_down=%d", ctrl, count_down);
                                break;
                                // case FAIL:

                                // stop=true;
                                // break;
                            default:
                                log.error("Control %s unexpected", ctrl);
                            }
                        }
                    },
                    &taskfailure
                    // (immutable(
                    //     stop=true;
                    //     log(e);
                    //     // const print_e=e;
                    //     // print_e.toString((buf) {log.fatal(buf.idup);});
                    //     // stderr.writeln(e);
                    // },
                    // (immutable(TaskException) t) {
                    //     stop=true;
                    //     log(t);
                    //     // log.fatal("From tasj %s", t.task_name);
                    //     // const print_e=t.throwable;
                    //     // print_e.toString((buf) {log.fatal(buf.idup);});
                    // },
                    // (immutable(Exception) e) {
                    //     stop=true;
                    //     const print_e=e;
                    //     print_e.toString((buf) {log.fatal(buf.idup);});
                    //     stderr.writeln(e);
                    // },
                    // (immutable(Throwable) t) {
                    //     stop=true;
                    //     const print_t=t;
                    //     print_t.toString((buf) {log.fatal(buf.idup);});
                    //     stderr.writeln(t);
                    // }
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
    catch (Throwable t) {
        fatal(t);
        abort=true;
    }
}
