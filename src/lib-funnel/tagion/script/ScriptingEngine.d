module tagion.script.ScriptingEngine;

import std.stdio : writeln, writefln;
import tagion.Options;
import std.concurrency;
import core.thread : msecs;
import tagion.Base : Control;

void createScriptingEngine (ref const Options.ScriptingEngine se_options) {
    writeln("Started scripting engine test.");

    bool run_scripting_engine = true;

    void handleControl(Control ts) {
        with(Control) switch(ts) {
            case STOP:
                writefln("Terminates scripting engine on: %s:%s.", se_options.listener_ip_address, se_options.listener_port);
                run_scripting_engine = false;
                break;
            case LIVE:
                run_scripting_engine = true;
                break;
            default:
                writefln("Bad Control command %s", ts);
                run_scripting_engine = false;
        }
    }

    while ( run_scripting_engine ) {
        receiveTimeout(50.msecs,
        &handleControl);
    }

    ownerTid.prioritySend(Control.END);

}

