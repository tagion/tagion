module tagion.script.ScriptingEngine;

import std.stdio : writeln, writefln;
import tagion.Options;
import tagion.Base : Control;
import core.thread;
import std.socket : InternetAddress, Socket, SocketException, SocketSet, TcpSocket, SocketShutdown, shutdown, AddressFamily;
import tagion.network.SslSocket;

alias SSocket = OpenSslSocket;


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

    synchronized
    class SharedClients {
        private shared (SSocket[uint])* locate_clients;
        private shared(uint) client_counter;


        this(ref SSocket[uint] _clients)
        in {
            assert(locate_clients is null);
            assert(_clients !is null);
        }
        out {
            assert(locate_clients !is null);
            client_counter=cast(uint)_clients.length;
        }
        do {
            locate_clients = cast(typeof(locate_clients))&_clients;
        }

        bool active() const pure {
            return (locate_clients !is null);
        }

        uint length() pure const {
            auto clients = cast(SSocket[uint]) *locate_clients;
            return cast(uint)clients.length;
        }

        void add(ref SSocket client)
        in {
            assert(locate_clients !is null);
            assert(client !is null);
            assert(client_counter <= client_counter.max);
        }
        out {
            assert(client_counter == locate_clients.length);
        }
        body {
            auto clients = cast(SSocket[uint]) *locate_clients;
            clients[client_counter] = client;
            client_counter = client_counter +1;
        }

        void removeClient(uint key)
        in {
            assert(locate_clients !is null);
            assert(key in *locate_clients);
        }
        out{
            assert(key !in *locate_clients);
        }
        body{
            auto clients = cast(SSocket[uint]) *locate_clients;
            clients.remove(key);
        }


        void closeAll() {
            if ( active ) {
                auto clients = cast(SSocket[uint]) *locate_clients;
                foreach ( key, client; clients ) {
                    client.disconnect;
                }
                locate_clients = null;
                client_counter = 0;
            }
        }

        void addClientsToSocketSet(ref SocketSet socket_set)
        in {
            assert(socket_set !is null);
            assert(active);
        }
        body {
            auto clients = cast(SSocket[uint]) *locate_clients;
            foreach(client; clients) {
                socket_set.add(client);
            }
        }
    }


private:
    SSocket[uint] clients;
    shared(SharedClients) shared_clients;
    immutable char[] _listener_ip_address;
    immutable ushort _listener_port;
    immutable uint _max_connections;
    immutable uint _listener_max_queue_length;
    OpenSslSocket _listener;
    enum _buffer_size = 1024;

    uint numberOfClients() pure const{
        uint res;
        if ( shared_clients !is null ) {
            res = shared_clients.length;
        }
         return res;
    }

    bool active() pure const {
        return (shared_clients !is null) && shared_clients.active;
    }

    void addClient(ref SSocket client) {
        if ( shared_clients is null ) {
            clients[0] = client;
            shared_clients = new shared(SharedClients)(clients);
        }
        else {
            shared_clients.add(client);
        }
    }

    void removeClient(uint key) {
        if ( shared_clients !is null ) {
            shared_clients.removeClient(key);
        }
    }

    void closeAll() {
        if ( active ) {
            shared_clients.closeAll;
        }
    }

    void addClientsToSocketSet(ref SocketSet socket_set) {
        if ( socket_set !is null && active ) {
            shared_clients.addClientsToSocketSet(socket_set);
        }
    }

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
        auto client = new SSocket(AddressFamily.INET, EndpointType.Client);
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

        _listener = new SSocket(AddressFamily.INET, EndpointType.Server);
        assert(_listener.isAlive);
        _listener.configureContext("pem_files/domain.pem", "pem_files/domain.key.pem");
        _listener.blocking = false;
        _listener.bind( new InternetAddress( _listener_ip_address, _listener_port ) );
        _listener.listen( _listener_max_queue_length );
        writefln("Started scripting engine API started on %s:%s.", _listener_ip_address, _listener_port);

        auto socketSet = new SocketSet(_max_connections + 1);
        SSocket[] reads;

        void addToSocketSet(SSocket[] clients) {
            foreach(client; clients) {
                socketSet.add(client);
            }
        }

        void resetReads() {
            foreach(client; reads) {
                client.disconnect;
            }
        }

        while ( run_scripting_engine ) {
            socketSet.add( _listener );

            addToSocketSet(reads);

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

        resetReads;

    }
}
