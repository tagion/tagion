module tagion.script.ScriptingEngine;

import std.stdio : writeln, writefln;
import tagion.Options;
import tagion.Base : Control;
import core.thread;
import std.socket : InternetAddress, Socket, SocketException, SocketSet, TcpSocket, SocketShutdown, shutdown, AddressFamily;
import tagion.network.SslSocket;

ScriptingEngineContext startScriptingEngine () {
    auto s_e_c = ScriptingEngineContext();

    s_e_c.scripting_engine = ScriptingEngine(options.scripting_engine);

    void delegate() scr_eng_del;
    scr_eng_del.funcptr = &ScriptingEngine.run;
    scr_eng_del.ptr = &s_e_c.scripting_engine;
    s_e_c.scripting_engine_tread = new Thread ( scr_eng_del ).start();

    return s_e_c;
}

struct ScriptingEngineContext {
    ScriptingEngine scripting_engine;
    Thread scripting_engine_tread;
}

struct ScriptingEngine {

private:

    immutable char[] _listener_ip_address;
    immutable ushort _listener_port;
    immutable uint _max_connections;
    immutable uint _listener_max_queue_length;
    OpenSslSocket _listener;
    enum _buffer_size = 1024;

public:

    this (Options.ScriptingEngine se_options) {
        _listener_ip_address = se_options.listener_ip_address;
        _listener_port = se_options.listener_port;
        _listener_max_queue_length = se_options.listener_max_queue_lenght;
        _max_connections = se_options.max_connections;
    }

    ~this () {
        //Implement desct. to free network res. Maybe call close function.
    }

    bool run_scripting_engine = true;

    void sPing(const char[] addr, ushort port) {
        auto client = new OpenSslSocket(AddressFamily.INET, EndpointType.Client);
        client.connect(new InternetAddress(addr, port));
    }

    void stop () {
        writeln("Stops scripting engine API");
        run_scripting_engine = false;
        sPing( _listener_ip_address, _listener_port );
    }

    void run () {

        scope ( exit ) {
            writefln( "Shutdown of listener socket. Is there an listener: %s and active: %s", _listener !is null, (_listener !is null &&_listener.isAlive));
            _listener.shutdown(SocketShutdown.BOTH);
            _listener.disconnect();
            Thread.sleep( dur!("seconds") (2));
            writefln( "Destroy of listener socket. Is there an listener: %s and active: %s", _listener !is null, (_listener !is null &&_listener.isAlive));
            _listener.destroy();
            Thread.sleep( dur!("seconds") (2));
        }

        _listener = new OpenSslSocket(AddressFamily.INET, EndpointType.Server);
        assert(_listener.isAlive);
        _listener.configureContext("pem_files/domain.pem", "pem_files/domain.key.pem");
        _listener.blocking = false;
        _listener.bind( new InternetAddress( _listener_ip_address, _listener_port ) );
        _listener.listen( _listener_max_queue_length );
        writefln("Started scripting engine API started on %s:%s.", _listener_ip_address, _listener_port);

        auto socketSet = new SocketSet(_max_connections + 1);
        OpenSslSocket[] reads;

        void resetReads() {
            foreach ( sock; reads ) {
                sock.disconnect();
            }
            reads = null;
        }

        while ( run_scripting_engine ) {
            socketSet.add( _listener );

            foreach ( sock; reads ) {
                socketSet.add ( sock );
            }

            Socket.select( socketSet, null, null);

            for ( size_t i = 0; i < reads.length; i++ ) {

                if( socketSet.isSet(reads[i]) )  {
                    char[1024] buffer;
                    auto data_length = reads[i].receive( buffer[] );

                    if ( data_length == Socket.ERROR ) {
                        writeln( "Connection error" );
                    }

                    else if ( data_length != 0) {
                        writefln ( "Received %d bytes from %s: \"%s\"", data_length, reads[i].remoteAddress.toString, buffer[0..data_length] );
                        reads[i].send(buffer[0..data_length] );

                        //Check dataformat
                        //Call scripting engine
                        //Send response back
                    }

                    else {
                        try {
                            writefln("Connection from %s closed.", reads[i].remoteAddress().toString());
                        }
                        catch ( SocketException ) {
                            writeln("Connection closed.");
                        }
                    }

                    reads[i].disconnect();

                    reads = reads[0..i]~reads[i+1..reads.length];
                    i--;

                    writefln("\tTotal connections: %d", reads.length);
                }

                else if ( !reads[i].isAlive ) {
                    reads[i].disconnect();

                    reads = reads[0..i]~reads[i+1..reads.length];
                    i--;

                    writefln("\tTotal connections: %d", reads.length);
                }
            }

            if (socketSet.isSet(_listener)) {     // connection request
                try {
                    OpenSslSocket req = null;
                    req = cast(OpenSslSocket)_listener.accept();
                    assert( req.isAlive );
                    assert( _listener.isAlive );

                    if ( reads.length < _max_connections )
                    {
                        writefln( "Connection from %s established.", req.remoteAddress().toString() );
                        reads ~= req;
                        writefln( "\tTotal connections: %d", reads.length );
                    }
                    else
                    {
                        writefln( "Rejected connection from %s; too many connections.", req.remoteAddress().toString() );
                        req.disconnect();
                        assert( !req.isAlive );
                        assert( _listener.isAlive );
                    }
                } catch(SocketException ex) {
                    writefln("SslSocketException: %s", ex);
                }

            }

            socketSet.reset();

        }

        resetReads();

    }
}

