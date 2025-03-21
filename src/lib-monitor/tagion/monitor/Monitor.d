module tagion.monitor.Monitor;

@safe:

import std.algorithm : sort;
import std.range : enumerate;
import std.format;
import std.file : exists;
import std.stdio;
import std.exception;

import tagion.hashgraph.Event : Event;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.Round;

import tagion.basic.Types : FileExtension;
import tagion.basic.basic : EnumText, basename;
import tagion.errors.tagionexceptions : TagionException;
import tagion.crypto.Types : Pubkey;
import tagion.hibon.Document;
import tagion.logger.Logger;

import tagion.logger;
import tagion.hibon.HiBONRecord;
import tagion.hashgraphview.EventView;

abstract class BaseMonitorCallbacks : EventMonitorCallbacks {
    nothrow :

    void _write_eventview(string event_name, const(Event) e);
    void _write_eventviews(string event_name, const(Event)[] e);

    void connect(const(Event) e) {
        _write_eventview(__FUNCTION__, e);
    }
}

class LogMonitorCallbacks : BaseMonitorCallbacks {
    Topic topic;
    uint[Pubkey] node_id_relocation;

    this(uint nodes, Pubkey[] node_keys, string event_topic_name = "monitor") {
        topic = Topic(event_topic_name);

        foreach(i, k; node_keys.sort.enumerate!uint) {
            this.node_id_relocation[k] = i;
        }
    }

    struct EventViews {
        const(EventView)[] views;
        mixin HiBONRecord!(q{
            this(const(Event)[] events, long nodes_amount) pure nothrow {
                foreach(e; events) {
                    views ~= EventView(e, nodes_amount);
                }
            }
        });
    }

    nothrow :

    override void _write_eventview(string event_name, const(Event) e) {
        const node_id = assumeWontThrow(node_id_relocation.get(e.event_package.pubkey, e.node_id));
        log.event(topic, event_name, EventView(e, node_id_relocation.length, node_id));
    }

    override void _write_eventviews(string event_name, const(Event)[] es) {
        log.event(topic, event_name, EventViews(es, node_id_relocation.length));
    }
}


class FileMonitorCallbacks : BaseMonitorCallbacks {
    File out_file;
    uint[Pubkey] node_id_relocation;
    this(string file_name, uint nodes, Pubkey[] node_keys) {
        // the "a" creates the file as well
        out_file = File(file_name, "a");

        import std.algorithm : sort;
        import std.range : enumerate;
        foreach(i, k; node_keys.sort.enumerate!uint) {
            this.node_id_relocation[k] = i;
        }
    }

    ~this() {
        out_file.close;
    }

    nothrow:

    override void _write_eventview(string _, const(Event) e) {
        try {
            const node_id = node_id_relocation.get(e.event_package.pubkey, e.node_id); 
            out_file.rawWrite(EventView(e, node_id_relocation.length, node_id).toDoc.serialize);
        } catch(Exception err) {
            log.error("Could not write monitor event, %s", err.message);
        }
    }
    override void _write_eventviews(string _, const(Event)[] es) {
        try {
            foreach(e; es) {
                out_file.rawWrite(EventView(e, node_id_relocation.length).toDoc.serialize);
            }
        }
        catch(Exception err) {
            log.error("Could not write monitor event, %s", err.message);
        }
    }
}


/// HashGraph monitor call-back interface
@safe
interface EventMonitorCallbacks {
    nothrow {
        void connect(const(Event) e);
    }
}
