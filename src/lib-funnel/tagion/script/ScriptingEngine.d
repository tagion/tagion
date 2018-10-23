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
        private shared (SSocket[uint])* local_clients;
        private shared(uint) client_counter;


        this(ref SSocket[uint] _clients)
        in {
            assert(local_clients is null);
            assert(_clients !is null);
        }
        out {
            assert(local_clients !is null);
            client_counter=cast(uint)_clients.length;
        }
        do {
            local_clients = cast(typeof(local_clients))&_clients;
        }

        bool active() const pure {
            return (local_clients !is null);
        }

        uint length() pure const {
            return client_counter;
        }

        void add(ref SSocket client)
        in {
            assert(local_clients !is null);
            assert(client !is null);
        }
        out {
            assert(client_counter == local_clients.length);
        }
        body {
            auto clients = cast(SSocket[uint]) *local_clients;
            clients[client_counter] = client;
            client_counter = client_counter +1;
        }

        void removeClient(uint index)
        in {
            assert(local_clients !is null);
            assert(index <= this.length);
        }
        out{
            if ( index < this.length + 1 ) {
                assert(local_clients[index] !is null);
            }
            else if ( index == this.length + 1) {
                assert(local_clients[index] is null);
            }
        }
        body{
            auto clients = cast(SSocket[uint]) *local_clients;
            clients.remove(index);
            client_counter = client_counter -1;
        }



        void close() {
            if ( active ) {
                auto clients = cast(SSocket[uint])*local_clients;
                foreach ( key, client; clients ) {
                    client.disconnect;
                }
                local_clients = null;
                client_counter = 0;
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

    void removeClient(uint index) {
        if ( shared_clients !is null ) {
            shared_clients.removeClient(index);
        }
    }

    void close() {
        if ( active ) {
            shared_clients.close;
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

//TO-DO: Enable unittest
// unittest {
//     auto s_e = ScriptingEngine();
//     auto client1 = new SSocket(AddressFamily.INET, EndpointType.Server);
//     auto client2 = new SSocket(AddressFamily.INET, EndpointType.Server);
//     auto client3 = new SSocket(AddressFamily.INET, EndpointType.Server);
//     assert(s_e.clients is null && s_e.shared_clients is null);
//     assert(s_e.shared_clients.length is 0);
//     assert(!s_e.active);

//     s_e.addClient(client1);
//     assert(s_e.shared_clients.length == 1);
//     assert(s_e.numberOfClients == 1);
//     assert(s_e.active);

//     s_e.addClient(client2);
//     assert(s_e.clients.length == 1);
//     assert(s_e.numberOfClients == 3);

//     s_e.addClient(client3);
//     s_e.removeClient(1);
//     assert(s_e.numberOfClients == 2);
//     s_e.removeClient(1);
//     assert(s_e.numberOfClients == 1);

//     s_e.close;
//     assert(!s_e.active);
//     assert(s_e.numberOfClients == 0);
// }
