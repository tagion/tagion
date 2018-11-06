module tagion.script.ScriptingEngine;

import std.stdio : writeln, writefln;
import tagion.Options;
import tagion.Base : Control;
import core.thread;
import std.socket : InternetAddress, Socket, SocketException, SocketSet, TcpSocket, SocketShutdown, shutdown, AddressFamily;
import tagion.network.SslSocket;


alias SSocket = OpenSslSocket;

class SSLFiber : Fiber {
    private {
        static Fiber[uint] fibers;
        static uint fiber_counter;
        static uint[] free_fibers;
        static uint[] fibers_to_execute;
        static Fiber duration_fiber;
        static ScriptingEngineOptions s_e_options;
        uint reuse_counter;

        void acceptAsync()
        in {
            assert(s_e_options !is null);
        }
        body {
        //     bool operation_complete;
        //     uint client_index;
        //     try {
        //     SSocket client;
        //     if ( key == 0 ) {
        //         writeln("Key is 0");
        //         key = useNextKey;
        //         writeln("Key is:", key);
        //     } else {
        //         client = _clients[key];
        //     }

        //     if ( numberOfClients >= s_e_options.max_connections ) {
        //             _listener.rejectClient();
        //             assert( _listener.isAlive );
        //     }
        //     else {
        //         writeln("In main accept");
        //         bool operation_complete;
        //         writefln("Is client nul? %s", client is null);
        //         writeln("trying to accept");
        //         writefln("Is listener null: %s", _listener is null);
        //         operation_complete = _listener.acceptSslAsync(client);
        //         if ( key !in _clients ) {
        //             _clients[key] = client;
        //         }
        //         writeln("Operation complete: ", operation_complete);
        //         if ( !operation_complete ) {
        //             return false;
        //         }
        //         else {
        //             assert( client.isAlive );
        //             assert( _listener.isAlive );

        //             if ( numberOfClients < s_e_options.max_connections )
        //             {
        //                 writefln( "Connection from %s established.", client.remoteAddress().toString() );
        //                 _shared_clients.add(client, key);
        //                 writefln( "\tTotal connections: %d", numberOfClients );
        //             }
        //         }
        //     }

        // } catch(SocketException ex) {
        //     writefln("SslSocketException: %s", ex);
        // }

            do {
                writeln("Calling accept async with client_index: ", client_index);
                operation_complete = clients.acceptAsync(client_index);
                writeln("Operation complete: ", operation_complete);
                if ( !operation_complete ) {
                    Fiber.yield();
                }
            } while(!operation_complete);
        }

        // void readDataAllClients(ref SocketSet socket_set)
        // in{
        //     assert(socket_set !is null);
        // }
        // body {
        //     if ( !active ) {
        //         return;
        //     }
        //     auto clients = cast(SSocket[uint]) *_locate_clients;
        //     foreach ( key, client; clients) {
        //         if( socket_set.isSet(client) )  {
        //             char[1024] buffer;
        //             auto data_length = client.receive( buffer[] );

        //             if ( data_length == Socket.ERROR ) {
        //                 writeln( "Connection error" );
        //             }

        //             else if ( data_length != 0) {
        //                 writefln ( "Received %d bytes from %s: \"%s\"", data_length, client.remoteAddress.toString, buffer[0..data_length] );
        //                 client.send(buffer[0..data_length] );

        //                 //Check dataformat
        //                 //Call scripting engine
        //                 //Send response back
        //             }

        //             else {
        //                 try {
        //                     writefln("Connection from %s closed.", client.remoteAddress().toString());
        //                 }
        //                 catch ( SocketException ) {
        //                     writeln("Connection closed.");
        //                 }
        //             }

        //             client.disconnect();

        //             this.removeClient(key);

        //             writefln("\tTotal connections: %d", this.length);
        //         }

        //         else if ( !client.isAlive ) {
        //             client.disconnect();

        //             this.removeClient(key);

        //             writefln("\tTotal connections: %d", this.length);
        //         }
        //     }
        // }

        void reuseCount() {
            reuse_counter++;
        }


        bool reuse()
        in{
             assert(s_e_options !is null);
        }
        body{
            return reuse_counter < s_e_options.max_number_of_fiber_reuse;
        }

        void durationTimer() {
            uint counter;
            while (counter < s_e_options.max_number_of_fiber_reuse) {
                const start_cycle_timestamp = MonoTime.currTime;
                Fiber.yield();
                const end_cycle_timestamp = MonoTime.currTime;
                Duration time_elapsed = end_cycle_timestamp - start_cycle_timestamp;
                writeln("Time elapsed: ", time_elapsed);
                if ( time_elapsed < s_e_options.min_duration_full_fibers_cycle_ms ) {
                    Thread.sleep(s_e_options.min_duration_full_fibers_cycle_ms - time_elapsed);
                    writeln("Sleeping");
                }

                counter++;
            }
        }

        static bool active() {
            writefln("min number of fibers: %d, and current free fibers: %d", s_e_options.min_number_of_fibers, free_fibers.length);
            return fibers_to_execute.length > 0;
        }
    }

    public {

        this ()
        in {
            assert(clients.listener !is null);
            assert(s_e_options !is null);
        }
        do {
            super(&this.acceptAsync);
        }

        this (void function() func)
        in {
            assert(clients.listener !is null);
            assert(func !is null);
        }
        do {
            super(func);
        }


        static acceptWithFiber()
        in{
            assert(fibers !is null);
            assert(clients.listener !is null);
        }
        out{
            writefln("Added fiber. Fibers to execute: %d, free fibers: %d, total fibers: %d",
            fibers_to_execute.length, free_fibers.length, fibers.length);
        }
        body {
            auto has_free_fiber = hasFreeFibers;
            if ( has_free_fiber ) {
                writeln("Using free fiber");
                addFiberToExecute( useNextFreeFiber );
            }
            else {
                if ( fibers.length >= s_e_options.max_number_of_accept_fibers ) {
                    writeln("Service denial: Max number of fibers used and no free fibers avaliable.");
                    clients.listener.rejectClient();
                }
                writeln("Added a new fiber");
                auto new_fib = new SSLFiber();
                fibers[fiber_counter] = new_fib;
                assert(fiber_counter < fiber_counter.max);
                addFiberToExecute(fiber_counter);
                fiber_counter++;
            }
        }

        static int useNextFreeFiber()
        in {
            assert(fibers !is null);
            assert(hasFreeFibers);
        }
        body{
            auto res = free_fibers[0];
            free_fibers = free_fibers[1..free_fibers.length];
            return res;
        }

        static bool hasFreeFibers()
        in{
            assert(free_fibers !is null);
        }
        body{
            return free_fibers.length > 0;
        }

        static void ExecuteFiberCycle() {
            Fiber fib;
            uint[] temp_fibers_to_execute;
            temp_fibers_to_execute = fibers_to_execute;
            fibers_to_execute = null;
            assert(temp_fibers_to_execute !is null);
            duration_fiber.call;
            if ( duration_fiber.state == Fiber.State.TERM ) {
                auto dur_func = &durationTimer;
                duration_fiber = new SSLFiber(dur_func);
                duration_fiber.call;
                writeln("Added duration fiber");
            }

            foreach(key; temp_fibers_to_execute) {
                writeln("Executes fibers");
                fib = fibers[key];
                fib.call;
                writeln("Fiber executed");
                if ( fib.state == Fiber.State.TERM ) {
                    if ( key < s_e_options.max_number_of_accept_fibers ) { //If the key is less than min number of fibers
                        writeln("Adding terminated fiber to free fiber");
                        fib.reset;
                        addFreeFiber(key);
                        writeln("Added terminated fiber to free fiber");
                    } else { //remove the fiber
                        writeln("Removing fiber from fibers.");
                        //fibers.remove(key);
                    }

                } else {
                    writeln("Adding fiber to be executed again.");
                    addFiberToExecute(key);
                }
            }
        }

//Remove fibers...
        static void addFiberToExecute(uint fiber_key)
        in  {
            assert(fibers[fiber_key].state == Fiber.State.HOLD);
        }
        body {
            fibers_to_execute ~= fiber_key;
        }

        static void addFreeFiber(uint fiber_key)
        in  {
            assert(fibers[fiber_key].state == Fiber.State.HOLD);
        }
        body {
            free_fibers ~= fiber_key;
        }

        static void initFibers ()
        in {
            assert(fibers is null);
            assert(fiber_counter == 0);
            assert(free_fibers is null);
            assert(s_e_options !is null);
        }
        out {
            assert(fibers !is null);
            assert(fiber_counter == s_e_options.min_number_of_fibers);
            assert(free_fibers !is null);
        }
        body {
            writeln("InitFibers;");
            for(int i = 0; i < s_e_options.min_number_of_fibers ; i++) {
                writeln("Adding fiber");
                auto acc_fib = new SSLFiber();
                fibers[fiber_counter] = acc_fib;
                addFreeFiber(fiber_counter);
                fiber_counter++;
            }

            auto dur_func = &durationTimer;
            duration_fiber = new SSLFiber(dur_func);
            duration_fiber.call;
            writeln("Added dur fiber");
        }
    }
}

class ScriptingEngineOptions {
    immutable uint max_connections;
    immutable string listener_ip_address;
    immutable ushort listener_port;
    immutable uint listener_max_queue_length;
    immutable uint max_number_of_accept_fibers;
    immutable Duration min_duration_full_fibers_cycle_ms;
    immutable uint max_number_of_fiber_reuse;
    enum min_number_of_fibers = 10;

    this(Options.ScriptingEngine se_options) {
        this.max_connections = se_options.max_connections;
        this.listener_ip_address = se_options.listener_ip_address;
        this.listener_port = se_options.listener_port;
        this.listener_max_queue_length = se_options.listener_max_queue_length;
        this.max_number_of_accept_fibers = se_options.max_number_of_accept_fibers;
        this.min_duration_full_fibers_cycle_ms = dur!"msecs"(se_options.min_duration_full_fibers_cycle_ms);
        this.max_number_of_fiber_reuse = se_options.max_number_of_fiber_reuse;
    }
}

struct ScriptingEngine {

private:
    ScriptingEngineOptions s_e_options;
    OpenSslSocket _listener;
    enum _buffer_size = 1024;

public:

    bool run_scripting_engine = true;

    void sPing(const char[] addr, ushort port) {
        auto client = new SSocket(AddressFamily.INET, EndpointType.Client);
        client.connect(new InternetAddress(addr, port));
    }

    void stop () {
        writeln("Stops scripting engine API");
        run_scripting_engine = false;
        sPing( s_e_options.listener_ip_address, s_e_options.listener_port );
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

        clients = SharedClientAccess(_listener, s_e_options);

        SSLFiber.clients = clients;
        SSLFiber.s_e_options = s_e_options;
        SSLFiber.initFibers;

        writeln("Initiated fibers");

        auto socket_set = new SocketSet(1);
        Fiber ssl_accept_fib;
        while ( run_scripting_engine ) {
            if ( !_listener.isAlive ){
                writeln("Listener not alive. Shutting down.");
                run_scripting_engine = false;
                break;
            }
            socket_set.add( _listener );

            int sel_res;

            if ( SSLFiber.active ) {
                writeln("SSLFiber active");
                sel_res = Socket.select( socket_set, null, null, dur!"msecs"(1000));
            }
            else {
                writeln("SSLFiber not active");
                sel_res = Socket.select( socket_set, null, null);
                writeln("Received a new con. req.");
            }

            if ( sel_res > 0 ) {
                if (socket_set.isSet(_listener)) {     // connection request
                    writeln("Creates ssl_Accept_fiber");
                    // ssl_accept_fib = new SSLFiber();
                    // ssl_accept_fib.call;
                    SSLFiber.acceptWithFiber();
                }
            }

            SSLFiber.ExecuteFiberCycle;

            // if(ssl_accept_fib !is null && ssl_accept_fib.state == Fiber.State.HOLD) {
            //     ssl_accept_fib.call;
            // }

            socket_set.reset;

        }

        scope ( exit ) {
            clients.closeAll;
            writefln( "Shutdown of listener socket. Is there an listener: %s and active: %s", _listener !is null, (_listener !is null &&_listener.isAlive));
            _listener.shutdown(SocketShutdown.BOTH);
            _listener.disconnect();
            Thread.sleep( dur!("seconds") (2));
            writefln( "Destroy of listener socket. Is there an listener: %s and active: %s", _listener !is null, (_listener !is null &&_listener.isAlive));
            _listener.destroy();
            Thread.sleep( dur!("seconds") (2));
        }

    }
}

struct ScriptingEngineContext {
    ScriptingEngine scripting_engine;
    Thread scripting_engine_tread;
}

ScriptingEngineContext startScriptingEngine () {
    auto s_e_c = ScriptingEngineContext();

    s_e_c.scripting_engine = ScriptingEngine();

    void delegate() scr_eng_del;
    scr_eng_del.funcptr = &ScriptingEngine.run;
    scr_eng_del.ptr = &s_e_c.scripting_engine;
    s_e_c.scripting_engine_tread = new Thread ( scr_eng_del ).start();

    return s_e_c;
}
