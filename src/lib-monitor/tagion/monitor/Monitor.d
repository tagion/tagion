module tagion.monitor.Monitor;

@safe:

import tagion.hashgraph.Event : Event;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.Round;

import std.format;
import tagion.basic.Types : FileExtension;
import tagion.basic.basic : EnumText, basename;
import tagion.basic.tagionexceptions : TagionException;
import tagion.crypto.Types : Pubkey;
import tagion.hibon.Document;
import tagion.logger.Logger;

import std.stdio;
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

class LogMonitorCallBacks : BaseMonitorCallbacks {
    Topic topic;

    this(string event_topic_name = "monitor") {
        topic = Topic(event_topic_name);
    }

    struct EventViews {
        const(EventView)[] views;
        mixin HiBONRecord!(q{
            this(const(Event)[] events) pure nothrow {
                foreach(e; events) {
                    views ~= EventView(e);
                }
            }
        });
    }

    nothrow :

    override void _write_eventview(string event_name, const(Event) e) {
        log.event(topic, event_name, EventView(e));
    }

    override void _write_eventviews(string event_name, const(Event)[] es) {
        log.event(topic, event_name, EventViews(es));
    }
}


class FileMonitorCallBacks : BaseMonitorCallbacks {
    File out_file;
    size_t[Pubkey] node_id_relocation;
    this(string file_name, uint nodes, const(Pubkey[]) node_keys) {
        out_file = File(file_name, "w");
        out_file.rawWrite(NodeAmount(nodes).toDoc.serialize);

        import std.algorithm : sort;
        import std.range : enumerate;
        foreach(i, k; node_keys.sort.enumerate) {
            this.node_id_relocation[k] = i;
        }
    }

    nothrow:

    override void _write_eventview(string _, const(Event) e) {
        try {
            out_file.rawWrite(EventView(e, node_id_relocation[e.event_package.pubkey]).toDoc.serialize);
        } catch(Exception err) {
            log.error("Could not write monitor event, %s", err.message);
        }
    }
    override void _write_eventviews(string _, const(Event)[] es) {
        try {
            foreach(e; es) {
                out_file.rawWrite(EventView(e).toDoc.serialize);
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
