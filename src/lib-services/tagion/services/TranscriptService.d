module tagion.services.TranscriptService;

import std.format;
import std.concurrency;
import core.thread;

import std.array : join;

import tagion.Options;
import tagion.Base : Payload, Control;
import tagion.hibon.HiBON;

import tagion.services.LoggerService;
import tagion.utils.Random;

import tagion.gossip.EmulatorGossipNet;


// This function is just to perform a test on the scripting-api input
void transcriptServiceTask(immutable(Options) opts) {
    setOptions(opts);
    immutable task_name=format("%s.%s", opts.node_name, opts.transcript.name);
    log.register(task_name);
    assert(opts.transcript.enable, "Scripting-Api test is not enabled");
    assert(opts.transcript.pause_from < opts.transcript.pause_to);

    Random!uint rand;
    rand.seed(opts.seed);
    immutable name=[opts.node_name, options.transcript.name].join;
    log("Scripting-Api script test %s started", name);
    Tid node_tid=locate(opts.node_name);
    bool stop;
    void controller(Control ctrl) {
        if ( ctrl == Control.STOP ) {
            stop=true;
            log("Scripting-Api %s stopped", name);
        }
    }

    uint counter;

    scope(exit) {
        log("Scripting-Api script test stopped %s", name);
        node_tid.prioritySend(Control.END);
    }


    while(!stop) {
        immutable delay=rand.value(opts.transcript.pause_from, opts.transcript.pause_to);
        log("delay=%s", delay);

        immutable message_received=receiveTimeout(delay.msecs, &controller);
        log("message_received=%s", message_received);
        if (!message_received) {
            // Send pseudo payload
            counter++;
            auto bson=new HiBON;
            bson["transaction"]=name;
            bson["count"]=counter;

            // Sends the transaction script to the node
            log("Scripting-Api %s send counter=%s", name, counter);
            Payload payload=bson.serialize;
            node_tid.send(payload);
        }
    }
}
