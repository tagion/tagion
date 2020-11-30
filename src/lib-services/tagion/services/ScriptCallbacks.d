module tagion.services.ScriptCallbacks;

import std.concurrency;
import std.datetime;   // Date, DateTime
import std.exception : assumeUnique;

import tagion.hashgraph.Event : Event, EventScriptCallbacks, EventBody;
import tagion.basic.Basic : Buffer, Payload, Control;
import tagion.hibon.HiBON;
import tagion.hibon.Document;
import tagion.Keywords;

import tagion.basic.Logger;

@safe class ScriptCallbacks : EventScriptCallbacks {

    private {
        Tid _event_script_tid;
        string transcript_task_name;
        //   string dart_task_name;
    }
    // @trusted
    // this(ref Tid event_script_tid) nothrow pure {
    //     _event_script_tid=event_script_tid;
    // }
    // this(ref Tid event_script_tid) nothrow pure {
    //     _event_script_tid=event_script_tid;
    // }

    @trusted
    this(void function(string task_name, string dart_task_name) nothrow transcript_task, string transcript_task_name, string dart_task_name) nothrow {
        try {
            import std.concurrency;
            _event_script_tid=spawn(transcript_task, transcript_task_name, dart_task_name);
            this.transcript_task_name = transcript_task_name;
            if ( receiveOnly!Control is Control.LIVE ) {
                log("Transcript started");
            }
        }
        catch (Throwable t) {
            import tagion.basic.TagionExceptions : fatal;
            fatal(t);
        }
    }

    void epoch(const(Event[]) received_event, immutable long epoch_time) {
        log("Epoch with %d events", received_event.length);
        // auto hibon=new HiBON;
        // hibon[Keywords.time]=time;
        Payload[] payloads;

        foreach(i, e; received_event) {
            if (e.eventbody.payload.length) {
                log("\tepoch=%d %d", i, e.eventbody.payload.length);
            // }
            // if ( e.eventbody.payload ) {
                payloads~=Payload(e.eventbody.payload);
            }
        }
        if ( payloads ) {
            // hibon[Keywords.epoch]=payloads;
            // immutable data=hibon.serialize;
            log("SEND Epoch with %d transactions", payloads.length);
            send(payloads, epoch_time);
        }
    }

   @trusted
   void send(ref Payload[] payloads, immutable long epoch_time) {
       immutable unique_payloads=assumeUnique(payloads);
       log("send data(%s)=%d", _event_script_tid, unique_payloads.length);
       pragma(msg, "Scripts: " ,typeof(unique_payloads));
       HiBON params = new HiBON;
       foreach(i, payload; unique_payloads){
           params[i] = payload;
       }
       _event_script_tid.send(params.serialize);
   }

    @trusted
    void send(immutable(EventBody) ebody) {
        if (ebody.payload.length) {
            log("ebody.payload=%d", ebody.payload.length);
            _event_script_tid.send(ebody);
        }
    }

    @trusted
    bool stop() nothrow {
        try {
            log("stop here");
            scope tid = locate(transcript_task_name);
//        result= _event_script_tid != _event_script_tid.init;
            if ( tid != tid.init ) {
                tid.send(Control.STOP);
                if (receiveOnly!Control is Control.END) {
                    return true;
                }
            }
        }
        catch (Throwable t) {
            import tagion.basic.TagionExceptions : fatal;
            fatal(t);
        }
        return false;
    }

}
