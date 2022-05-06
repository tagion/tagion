module tagion.services.ScriptCallbacks;

import std.concurrency;
import std.datetime; // Date, DateTime
import std.exception : assumeUnique;

import tagion.hashgraph.Event : Event;

// import tagion.hashgraph.HashGraphBasic: EventScriptCallbacks;
import tagion.hashgraph.HashGraphBasic : EventBody;
import tagion.basic.Types : Buffer, Control;
import tagion.hibon.HiBON;
import tagion.hibon.Document;
import tagion.Keywords;
import tagion.basic.TagionExceptions : fatal;
import tagion.logger.Logger;

@safe class ScriptCallbacks {
    import std.datetime;

    alias Time = MonoTimeImpl!(ClockType.normal);
    private {
        Tid _event_script_tid;
        string transcript_task_name;
        string epoch_debug_task_name;
        Time last_time;
        //   string dart_task_name;
    }

    @trusted this(void function(string task_name, string dart_task_name) nothrow transcript_task,
            string transcript_task_name, string dart_task_name, string epoch_debug_task_name = null) nothrow {
        try {
            import std.concurrency;

            _event_script_tid = spawn(transcript_task, transcript_task_name, dart_task_name);
            this.transcript_task_name = transcript_task_name;
            this.epoch_debug_task_name = epoch_debug_task_name;
            if (receiveOnly!Control is Control.LIVE) {
                log("Transcript started");
            }

        }
        catch (Throwable t) {
            fatal(t);
        }
        last_time = MonoTime.currTime;
    }

    @trusted void epoch(const(Event[]) received_event, immutable long epoch_time) nothrow {
        const current_time = MonoTime.currTime;
        scope (exit) {
            last_time = current_time;
        }
        try {
            log.trace("Epoch with %d events (Period %ssecs)", received_event.length,
                    1e-3 * double((current_time - last_time).total!"msecs"));
            // auto hibon=new HiBON;
            // hibon[Keywords.time]=time;
            Document[] payloads;

            foreach (i, e; received_event) {
                if (e.eventbody.payload.length) {
                    log("\tepoch=%d %d", i, e.eventbody.payload.length);
                    // }
                    // if ( e.eventbody.payload ) {
                    payloads ~= e.eventbody.payload;
                }
            }
            if (payloads) {
                // hibon[Keywords.epoch]=payloads;
                // immutable data=hibon.serialize;
                log("SEND Epoch with %d transactions", payloads.length);
                send(payloads, epoch_time);
            }
        }
        catch (Throwable t) {
            fatal(t);
        }
    }

    @trusted void send(ref Document[] payloads, immutable long epoch_time) nothrow {
        try {
            immutable unique_payloads = assumeUnique(payloads);
            log("send data(%s)=%d", _event_script_tid, unique_payloads.length);
            HiBON params = new HiBON;
            pragma(msg, "fixme(cbr): epoch_time has not beed added to the epoch");
            foreach (i, payload; unique_payloads) {
                params[i] = payload;
            }
            immutable data = params.serialize;
            _event_script_tid.send(data);
            if (epoch_debug_task_name !is null) {
                HiBON epoch = new HiBON;
                epoch["$time"] = epoch_time;
                epoch["$params"] = Document(data);
                scope epoch_debug_tid = locate(epoch_debug_task_name);
                if (epoch_debug_tid !is epoch_debug_tid.init) {
                    epoch_debug_tid.send(transcript_task_name, Document(epoch.serialize));
                }
            }
        }
        catch (Throwable t) {
            fatal(t);
        }
    }

    @trusted void send(immutable(EventBody) ebody) nothrow {
        try {
            if (ebody.payload.length) {
                log("ebody.payload=%d", ebody.payload.length);
                _event_script_tid.send(ebody);
            }
        }
        catch (Throwable t) {
            fatal(t);
        }
    }

    @trusted bool stop() nothrow {
        try {
            log("stop here");
            scope tid = locate(transcript_task_name);
            //        result= _event_script_tid != _event_script_tid.init;
            if (tid != tid.init) {
                tid.send(Control.STOP);
                if (receiveOnly!Control is Control.END) {
                    return true;
                }
            }
        }
        catch (Throwable t) {
            fatal(t);
        }
        return false;
    }

}
