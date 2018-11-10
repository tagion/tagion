module tagion.network.ScriptingEngineAPI;

import core.time : dur, Duration;
import core.thread : Thread;
import std.stdio : writeln, writefln;
import std.socket : InternetAddress, Socket, SocketSet, SocketShutdown, shutdown, AddressFamily;
import tagion.network.SSLSocket;
import tagion.script.ScriptingEngineOptions;
import tagion.network.SSLSocketFiber;
import tagion.Options;

alias SSocket = OpenSslSocket;



struct ScriptingEngineAPI {

private:
    ScriptingEngineOptions s_e_options;
    OpenSslSocket _listener;
    enum _buffer_size = 1024;

public:

    bool run_scripting_engine = true;

    void sPing(const char[] addr, ushort port) {
        auto client = new SSocket(AddressFamily.INET, EndpointType.Client);
        client.connect(new InternetAddress(addr, port));
        Thread.sleep(dur!"msecs"(2000));
        client.send("ping");
        client.close;
    }

    void stop () {
        writeln("Stops scripting engine API");
        sPing( s_e_options.listener_ip_address, s_e_options.listener_port );
        run_scripting_engine = false;
    }

    void run () {
        s_e_options = new ScriptingEngineOptions(options.scripting_engine);

        _listener = new SSocket(AddressFamily.INET, EndpointType.Server);
        assert(_listener.isAlive);
        _listener.configureContext("pem_files/domain.pem", "pem_files/domain.key.pem");
        _listener.blocking = false;
        _listener.bind( new InternetAddress( s_e_options.listener_ip_address, s_e_options.listener_port ) );
        _listener.listen( s_e_options.listener_max_queue_length );
        writefln("Started scripting engine API started on %s:%s.", s_e_options.listener_ip_address, s_e_options.listener_port);

        SSLSocketFiber.listener = _listener;
        SSLSocketFiber.s_e_options = s_e_options;
        SSLSocketFiber.initFibers;

        writeln("Initiated fibers");

        auto socket_set = new SocketSet(s_e_options.max_connections+1);

        int sel_res;
        while ( run_scripting_engine ) {
            if ( !_listener.isAlive ){
                writeln("Listener not alive. Shutting down.");
                run_scripting_engine = false;
                break;
            }

            writeln("Another cycle");
            socket_set.add( _listener );
            SSLSocketFiber.addClientsToSocketSet(socket_set);

            if ( SSLSocketFiber.active ) {
                sel_res = Socket.select( socket_set, null, null, dur!"msecs"(1));
            }
            else {
                sel_res = Socket.select( socket_set, null, null);
            }

            if ( sel_res > 0 ) {

                SSLSocketFiber.handleClients(socket_set);

                if (socket_set.isSet(_listener)) {     // connection request
                    SSLSocketFiber.acceptWithFiber();
                }

            }

            writeln("Before handle fiber cycle");
            SSLSocketFiber.ExecuteFiberCycle;
            writeln("After handle fiber cycle");
            socket_set.reset;

        }

        scope ( exit ) {
            SSLSocketFiber.clientsCloseAll;
            writefln( "Shutdown of listener socket. Is there an listener: %s and active: %s", _listener !is null, (_listener !is null &&_listener.isAlive));
            _listener.shutdown(SocketShutdown.BOTH);
            _listener.disconnect();
            Thread.sleep( dur!("seconds") (2));
            writefln( "Destroy of listener socket. Is there n listener: %s and active: %s", _listener !is null, (_listener !is null &&_listener.isAlive));
            _listener.destroy();
            Thread.sleep( dur!("seconds") (4));
        }
    }
}

ScriptingEngineAPIContext startScriptingEngineAPI () {
    auto s_e_api_c = ScriptingEngineAPIContext();

    s_e_api_c.scripting_engine_api = ScriptingEngineAPI();

    void delegate() scr_eng_api_del;
    scr_eng_api_del.funcptr = &ScriptingEngineAPI.run;
    scr_eng_api_del.ptr = &s_e_api_c.scripting_engine_api;
    s_e_api_c.scripting_engine_api_thread = new Thread ( scr_eng_api_del ).start();

    return s_e_api_c;
}

struct ScriptingEngineAPIContext {
    ScriptingEngineAPI scripting_engine_api;
    Thread scripting_engine_api_thread;
}