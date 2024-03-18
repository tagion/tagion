/// This program checks if we can start the network in mode1
module tagion.testbench.e2e.mode1;

import core.thread;
import core.time;

import std.stdio;
import std.process;
import std.range;
import std.algorithm;

import tagion.tools.Basic;
import neuewelle = tagion.tools.neuewelle;

void kill_waves(Pid[] pids, Duration grace_time) {
    const begin_time = MonoTime.currTime;

    foreach(pid; pids) {
        kill(pid);
        writefln("SIGINT: %s", pid.processID);
    }

    Pid[] alive_pids = pids;
    while(alive_pids.empty || MonoTime.currTime - begin_time <= grace_time) {
        foreach(i, pid; alive_pids) {
            auto proc_status = tryWait(pid);
            if(proc_status.terminated) {
                alive_pids = alive_pids.remove(i);
            }
        }
        Thread.sleep(100.msecs);
    }

    foreach(pid; alive_pids) {
        kill(pid, 9);
        writefln("SIGKILL: %s", pid.processID);
    }
}


mixin Main!(_main);

int _main(string[] _) {
    auto pid = spawnProcess("/home/lucas/wrk/tagion/bin/neuewelle");
    writeln("Started %s", pid);

    Thread.sleep(3.seconds);

    kill_waves([pid], 10.seconds);
    return 0;
}
