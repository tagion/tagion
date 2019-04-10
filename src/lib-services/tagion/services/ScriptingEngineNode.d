module tagion.services.ScriptingEngineNode;

import std.format;
import std.concurrency;
import std.array : join;

import tagion.Options;
import tagion.services.LoggerService;
import tagion.Base : Buffer, Control;
import tagion.utils.BSON : Document;
import tagion.Keywords;
import tagion.hashgraph.ConsensusExceptions;

import tagion.gossip.EmulatorGossipNet;


// This the test task for the scripting engine
void scripting_engine(immutable(Options) opts) {
    set(opts);
//    immutable node_name=getname(node_id);
    immutable task_name=format("%s.%s", opts.node_name, options.scripting_engine.name);
    log.register(task_name);
//    register(format("%s.%s", opts.node_name, options.scripting_engine.name), thisTid);

    // if ( options.scripting_engine.name ) {
    //     string filename=[node_name, .scripting_engine.name].getfilename;
    //     log("Script Filename %s", filename);
    //     log.open(filename, "w");
    // }

    Tid node_tid=locate(opts.node_name);
    bool stop;
    immutable name=[opts.node_name, opts.scripting_engine.name].join;
    log("Scripting engine started %s", name);
    void transaction(Buffer data) {
        log("Transaction data received BUFFER  %d bytes", data.length);
        // Data contains a Payload or an Epoch
        auto doc=Document(data);
        if ( doc.hasElement(Keywords.epoch) ) {
            auto docs=doc[Keywords.epoch].get!Document;
            log("\tData is epoch %d", docs.length);

        }
        else {
            log("\tData is payload");
        }

    }

    void controller(Control ctrl) {
        log("Control %s", ctrl);
        with(Control) switch(ctrl) {
            case STOP:
                stop=true;
                break;
            default:
                /// Bad command !!!!!!!!!
            }
    }

    scope(exit) {
//        ownerTid.prioritySend(Control.END);
        log("Scripting engine test stopped %s", name);
//        log.close;
        node_tid.prioritySend(Control.END);
    }

    while(!stop) {
        try {
            receive(
                &controller,
                &transaction,
                );
        }
        catch ( ConsensusException e ) {
            log("Consensus fail %s: %s. code=%s\n%s", opts.node_name, e.msg, e.code, typeid(e));
        }
        catch ( Exception e ) {
            log("Error %s: %s\n%s", opts.node_name, e.msg, e);
            stop=true;
        }
        catch ( Throwable t ) {
            //t.msg ~= " - From epoch_script thread " ~ to!string(node_id);
            stop=true;
            throw t;
        }
    }
}
