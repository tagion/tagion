module tagion.services.ScriptingEngineNode;

import std.concurrency;
import std.array : join;

import tagion.Options;
import tagion.services.TagionLog;
import tagion.Base : Buffer, Control;
import tagion.utils.BSON : Document;
import tagion.Keywords;
import tagion.hashgraph.ConsensusExceptions;



import tagion.hashgraph.EmulatorGossipNet;


// This the test task for the scripting engine
void scripting_engine(immutable uint node_id) {
    immutable node_name=getname(node_id);
    if ( options.scripting_engine.name ) {
        string filename=[node_name, options.scripting_engine.name].getfilename;
        log.writefln("Script Filename %s", filename);
        log.open(filename, "w");
    }

    Tid node_tid=locate(node_name);
    bool stop;
    immutable name=[node_name, options.scripting_engine.name].join;
    log.writefln("Scripting engine started %s", name);
    void transaction(Buffer data) {
        log.writefln("Transaction data received BUFFER  %d bytes", data.length);
        // Data contains a Payload or an Epoch
        auto doc=Document(data);
        if ( doc.hasElement(Keywords.epoch) ) {
            auto docs=doc[Keywords.epoch].get!Document;
            log.writefln("\tData is epoch %d", docs.length);

        }
        else {
            log.writefln("\tData is payload");
        }

    }

    void controller(Control ctrl) {
        log.writefln("Control %s", ctrl);
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
        log.writefln("Scripting engine test stopped %s", name);
        log.close;
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
            log.writefln("Consensus fail %s: %s. code=%s\n%s", node_name, e.msg, e.code, typeid(e));
        }
        catch ( Exception e ) {
            log.writefln("Error %s: %s\n%s", node_name, e.msg, e);
            stop=true;
        }
        catch ( Throwable t ) {
            //t.msg ~= " - From epoch_script thread " ~ to!string(node_id);
            stop=true;
            throw t;
        }
    }
}
