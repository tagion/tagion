module tagion.services.HeartBeatService;

import core.thread;
import std.concurrency;

import tagion.Options;
import tagion.services.TagionLog;
import tagion.utils.Random;

import tagion.Base : Pubkey, Control;
import tagion.services.TagionService;
import tagion.gossip.EmulatorGossipNet;

void heartBeatServiceThread(immutable(Options) opts) { //immutable uint count_from, immutable uint N, immutable uint seed, immutable uint delay, immutable uint timeout) {
      immutable N=opts.nodes;
      immutable delay=opts.delay;
      immutable timeout=opts.timeout;
      immutable uint count_from=opts.loops;

//    auto main_tid=ownerTid;

    Tid[] tids;
//    Tid[] scription_api_tids;
    Pubkey[]  pkeys;
    immutable monitor_address = options.url; //"127.0.0.1";

    version(Monitor) {
        auto network_socket_thread_id = spawn(&createSocketThread, options.network_socket_port, monitor_address);
     //spawn(&createSocketThread, ThreadState.LIVE, monitor_port, monitor_ip_address, true);

        register(format("network_socket_thread %s", options.network_socket_port), network_socket_thread_id);
    }

    immutable transcript_enable=options.transcript.enable;

    scope(exit) {
        version(Monitor) {
            if ( network_socket_thread_id != Tid.init ) {
                log.writefln("Send prioritySend(Control.STOP) %s", options.network_socket_port);
                network_socket_thread_id.send(Control.STOP);
                auto control=receiveOnly!Control;
                if ( control == Control.END ) {
                    log.writeln("Closed network socket monitor.");
                }
                else {
                    log.writefln("Closed network socket monitor with unexpect control command %s", control);
                }
            }
        }

        log.writeln("----- Stop all tasks -----");
        foreach(i, ref tid; tids) {
            log.writefln("Send stop to %d", i);
            tid.prioritySend(Control.STOP);
        }
        log.writeln("----- Wait for all tasks -----");
        foreach(i, ref tid; tids) {
            auto control=receiveOnly!Control;
            if ( control == Control.END ) {
                log.writefln("Thread %d stopped %d", i, control);
            }
            else {
                log.writefln("Thread %d stopped %d unexpected control %s", i, control);
            }
        }
        log.writeln("----- Stop send to all -----");
    }

    foreach(i;0..N) {
        ushort monitor_port;
        if ( (!options.disable_sockets) && ((options.max_monitors == 0) || (i < options.max_monitors) ) ) {
            monitor_port=cast(ushort)(options.port + i);
        }
        immutable setup=immutable(EmulatorGossipNet.Init)(timeout, i, N, monitor_address, monitor_port, 1234);
        auto tid=spawn(&(tagionServiceThread!EmulatorGossipNet), setup);
        register(getname(i), tid);
        tids~=tid;
        pkeys~=receiveOnly!(Pubkey);
        log.writefln("Start %d", pkeys.length);
    }

    log.writeln("----- Receive sync signal from nodes -----");

    log.writefln("----- Send acknowlege signals  num of keys=%d -----", pkeys.length);

    foreach(ref tid; tids) {
        foreach(pkey; pkeys) {
            tid.send(pkey);
        }
    }

    uint count = count_from;

    bool stop=false;

    if ( options.sequential ) {
        Thread.sleep(1.seconds);


        log.writeln("Start the heart beat");
        uint node_id;
        uint time=delay;
        Random!uint rand;
        rand.seed(options.seed);
        while(!stop) {
            if ( !options.infinity ) {
                log.writefln("count=%d", count);
            }
            Thread.sleep(delay.msecs);

            tids[node_id].send(time, rand.value);
            if ( !options.infinity ) {
                log.writefln("send time=%d to  %d", time, node_id);
            }

            time+=delay;
            node_id++;
            if ( node_id >= tids.length ) {
                node_id=0;
            }

            if ( !options.infinity ) {
                stop=(count==0);
                count--;
            }
        }
    }
    else {
        while(!stop) {
            if ( !options.infinity ) {
                log.writefln("count=%d", count);
            }
            Thread.sleep(delay.msecs);
            if ( !options.infinity ) {
                stop=(count==0);
                count--;
            }
        }
    }
}
