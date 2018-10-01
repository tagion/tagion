module tagion.script.ScriptingEngine;

import std.stdio : writeln, writefln;
import tagion.Options;
import tagion.Base : Control;
import core.thread;


//Wrapper struct for Scripting engine to help handle scripting engine thread.
//Default global options for scripting engine is chosen.
// struct ScriptingEngineThread {
//     ScriptingEngine scripting_engine;
//     Thread scripting_engine_tread;


//     void start () {
//         scripting_engine = ScriptingEngine(options.scripting_engine);

//         void delegate() _scripting_engine_delegate;
//         _scripting_engine_delegate.funcptr = &ScriptingEngine.run;
//         _scripting_engine_delegate.ptr = &scripting_engine;
//         scripting_engine_tread = new Thread ( _scripting_engine_delegate ).start();
//     }
// }


struct ScriptingEngine {

    string _listener_ip_address;
    immutable ushort _listener_port;

    this (Options.ScriptingEngine se_options) {
        _listener_ip_address = se_options.listener_ip_address;
        _listener_port = se_options.listener_port;
    }

    ~this () {
        //Implement desct. to free network res. Maybe call close function.
    }

    bool run_scripting_engine = true;

    void stop () {
        writeln("Stops scripting engine API");
        run_scripting_engine = false;
    }

    void run () {

        writefln("Started scripting engine API started on %s:%s.", _listener_ip_address, _listener_port);

        while ( run_scripting_engine ) {
            Thread.sleep(500.msecs);
        }
    }

}

