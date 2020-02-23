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
import tagion.TagionExceptions;

import tagion.gossip.EmulatorGossipNet;


// This function is just to perform a test on the scripting-api input
void transcriptServiceTask(immutable(Options) opts) {
    setOptions(opts);
    immutable task_name=opts.transcript.task_name;
    log.register(task_name);
    assert(opts.transcript.enable, "Scripting-Api test is not enabled");
    assert(opts.transcript.pause_from < opts.transcript.pause_to);

    Random!uint rand;
    rand.seed(opts.seed);
//    immutable name=[opts.node_name, options.transcript.name].join;
    log("Scripting-Api script test %s started", task_name);
    Tid node_tid=locate(opts.node_name);
    node_tid.send(Control.LIVE);

    bool stop;
    void controller(Control ctrl) {
        if ( ctrl == Control.STOP ) {
            stop=true;
            log("Scripting-Api %s stopped", task_name);
        }
    }

    void receive_epoch(immutable(Payload[]) payloads) {
         log("Epochs %d", payloads.length);
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



    uint counter;

    scope(exit) {
        log("Scripting-Api script test stopped %s", task_name);
        node_tid.prioritySend(Control.END);
    }


    while(!stop) {
        immutable delay=rand.value(opts.transcript.pause_from, opts.transcript.pause_to);
        log("delay=%s", delay);

        receive(
            &receive_epoch,
            //&receive_payload,
            // &epoch,
            &controller,
            &tagionexception,
            &exception,
            &throwable,

            );

        // immutable message_received=receiveTimeout(delay.msecs, &controller);
        // log("message_received=%s", message_received);
        // if (!message_received) {
        //     // Send pseudo payload
        //     counter++;
        //     auto hibon=new HiBON;
        //     hibon["transaction"]=task_name;
        //     hibon["count"]=counter;

        //     // Sends the transaction script to the node
        //     log("Scripting-Api %s send counter=%s", task_name, counter);
        //     Payload payload=hibon.serialize;
        //     node_tid.send(payload);
        // }
    }
}
