module tagion.services.TranscriptNode;

import std.concurrency;
import core.thread;

import std.array : join;

import tagion.Options;
import tagion.Base : Payload, Control;
import tagion.utils.BSON : HBSON;

import tagion.services.TagionLog;
import tagion.utils.Random;

import tagion.hashgraph.EmulatorGossipNet;


// This function is just to perform a test on the scripting-api input
void transcript(immutable uint node_id, immutable uint seed) {
    assert(options.transcript.enable, "Scripting-Api test is not enabled");
    immutable from=options.transcript.pause_from;
    immutable to=options.transcript.pause_to;
    assert(from < to);
    immutable node_name=node_id.getname;

    if ( options.transcript.name ) {
        string filename=[node_name, options.transcript.name].getfilename;
        import std.stdio;
        stderr.writefln("Trans Filename %s", filename);
        log.open(filename, "w");
    }

    Random!uint rand;
    rand.seed(seed);
    immutable name=[node_name, options.transcript.name].join;
    log.writefln("Scripting-Api script test %s started", name);
    Tid node_tid=locate(node_name);
    bool stop;
    void controller(Control ctrl) {
        if ( ctrl == Control.STOP ) {
            stop=true;
            log.writefln("Scripting-Api %s stopped", name);
        }
    }

    uint counter;

    scope(exit) {
        log.writefln("Scripting-Api script test stopped %s", name);
        log.close;
        node_tid.prioritySend(Control.END);
//        ownerTid.prioritySend(Control.END);
    }


    while(!stop) {
        immutable delay=rand.value(from, to);
        log.writefln("delay=%s", delay);

        immutable message_received=receiveTimeout(delay.msecs, &controller);
        log.writefln("message_received=%s", message_received);
        if (!message_received) {
            // Send pseudo payload
            counter++;
            auto bson=new HBSON;
            bson["transaction"]=name;
            bson["count"]=counter;

            // Sends the transaction script to the node
            log.writefln("Scripting-Api %s send counter=%s", name, counter);
            Payload payload=bson.serialize;
            node_tid.send(payload);
        }
    }
}
