module tagion.services.ScriptCallbacks;

import std.concurrency;
import std.datetime;   // Date, DateTime

import tagion.hashgraph.Event : Event, EventScriptCallbacks;
import tagion.Base : Buffer, Payload, Control;
import tagion.hibon.HiBON;
import tagion.hibon.Document;
import tagion.Keywords;

import tagion.services.LoggerService;

@safe class ScriptCallbacks : EventScriptCallbacks {
    private Tid _event_script_tid;
    @trusted
    this(ref Tid event_script_tid) {
        _event_script_tid=event_script_tid;
    }

    void epoch(const(Event[]) received_event, const(long) time) {
        log("Epoch with %d events", received_event.length);
        /++
        auto hibon=new HiBON;
        hibon[Keywords.time]=time;
        Document[] payloads;

        foreach(i, e; received_event) {
            log("\tepoch=%d %d", i, e.eventbody.payload.length);
            if ( e.eventbody.payload ) {
                payloads~=Document(e.eventbody.payload);
            }
        }
        if ( payloads ) {
            hibon[Keywords.epoch]=payloads;
            immutable data=hibon.serialize;
            log("SEND Epoch with %d transactions %d bytes", payloads.length, data.length);
            send(data);
        }
        ++/
    }

    @trusted
    void send(immutable(Buffer) data) {
        log("send data=%d", data.length);
        _event_script_tid.send(data);
    }

    @trusted
    bool stop() {
        immutable result= _event_script_tid != _event_script_tid.init;
        if ( result ) {
            _event_script_tid.prioritySend(Control.STOP);
        }
        return result;
    }

}
