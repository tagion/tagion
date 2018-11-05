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

synchronized
class SharedClients {
    private shared (SSocket[uint])* locate_clients;
    private shared(uint) client_counter;


    this(ref SSocket[uint] clients)
    in {
        assert(locate_clients is null);
    }
    out {
        assert(locate_clients !is null);
        client_counter=cast(uint)clients.length;
    }
    do {
        locate_clients = cast(typeof(locate_clients))&clients;
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
    body {
        auto clients = *locate_clients;
        auto shared_client = cast(shared(SSocket))client;
        clients[client_counter] = shared_client;
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

    void readDataAllClients(ref SocketSet socket_set) {
        auto clients = cast(SSocket[uint]) *locate_clients;
        foreach ( key, client; clients) {
            if( socket_set.isSet(client) )  {
                char[1024] buffer;
                auto data_length = client.receive( buffer[] );

                if ( data_length == Socket.ERROR ) {
                    writeln( "Connection error" );
                }

                else if ( data_length != 0) {
                    writefln ( "Received %d bytes from %s: \"%s\"", data_length, client.remoteAddress.toString, buffer[0..data_length] );
                    client.send(buffer[0..data_length] );

                    //Check dataformat
                    //Call scripting engine
                    //Send response back
                }

                else {
                    try {
                        writefln("Connection from %s closed.", client.remoteAddress().toString());
                    }
                    catch ( SocketException ) {
                        writeln("Connection closed.");
                    }
                }

                client.disconnect();

                this.removeClient(key);

                writefln("\tTotal connections: %d", this.length);
            }

            else if ( !client.isAlive ) {
                client.disconnect();

                this.removeClient(key);

                writefln("\tTotal connections: %d", this.length);
            }
        }
    }
}

struct SharedClientAccess {
private:
    static shared(SharedClients) shared_clients;
    SSocket[uint] clients;

public:

    uint numberOfClients() const{
        uint res;
        if ( shared_clients !is null ) {
            res = shared_clients.length;
        }
         return res;
    }

    bool active() const {
        return (shared_clients !is null) && shared_clients.active;
    }

    void addClient( ref SSocket client ) {
        if ( shared_clients is null ) {
            clients[0] = client;
            writeln("Adding client in null shared_clients");
            shared_clients = new shared(SharedClients)(clients);
        } else {
            writeln("Adding client in shared_clients");
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

    void readDataAllClients(ref SocketSet socket_set) {
        if ( active ) {
            shared_clients.readDataAllClients(socket_set);
        }
    }
}

ScriptingEngineWorkerContext startScriptingEngineWorker () {
    auto s_e_w_c = ScriptingEngineWorkerContext();

    s_e_w_c.scripting_engine_worker = ScriptingEngineWorker();

    void delegate() scr_eng_del;
    scr_eng_del.funcptr = &ScriptingEngineWorker.run;
    scr_eng_del.ptr = &s_e_w_c.scripting_engine_worker;
    s_e_w_c.scripting_engine_worker_thread = new Thread ( scr_eng_del ).start();

    return s_e_w_c;
}

struct ScriptingEngineWorkerContext {
    ScriptingEngineWorker scripting_engine_worker;
    Thread scripting_engine_worker_thread;
}

struct ScriptingEngineWorker {
private:
    enum _buffer_size = 1024;
    SharedClientAccess shared_client_access = SharedClientAccess();
    alias clients = shared_client_access;
    bool run_scripting_engine_worker = true;

public:

    void stop () {
        writeln("Stops scripting engine worker");
        run_scripting_engine_worker = false;
    }

    auto socket_set = new SocketSet();

    void run() {
        writeln("Startet scripting engine worker.");
        while (run_scripting_engine_worker) {
            clients.addClientsToSocketSet(socket_set);
            Socket.select(socket_set, null, null, dur!"msecs"(50));

            clients.readDataAllClients(socket_set);
            socket_set.reset;
        }

        scope(exit) {
            writeln("Closing scripting engine worker.");
        }
    }
}

class SSLFiberGeneral {
    immutable uint max_number_of_fibers;
    immutable uint max_number_of_fiber_reuse;
    enum min_number_of_fibers = 2;
    immutable uint max_connections;

    private Duration _min_full_cycle_time;
    private SharedClientAccess _clients;
    private SSocket _listener;

    Duration min_full_cycle_time () {
        return _min_full_cycle_time;
    }

    SharedClientAccess clients () {
        return _clients;
    }

    SSocket listener () {
        return _listener;
    }

    this(const uint max_number_of_fibers,
        const uint max_number_of_fiber_reuse,
        const uint max_connections,
        Duration min_full_cycle_time,
        SharedClientAccess shared_client_access,
        ref SSocket listener) {
        this.max_number_of_fibers = max_number_of_fibers;
        this.max_number_of_fiber_reuse = max_number_of_fiber_reuse;
        this.max_connections = max_connections;
        this._min_full_cycle_time = min_full_cycle_time;
        this._clients = shared_client_access;
        this._listener = listener;
    }

}

class SSLFiber : Fiber {
    private {
        static SSLFiberGeneral ssl_gen;
        static Fiber[uint] fibers;
        static uint fiber_counter;
        static uint[] free_fibers;
        static uint[] fibers_to_execute;
        static Fiber duration_fiber;
        static SSLFiber first_fiber;

        void accept() {
            try {
                SSocket client = null;
                if ( ssl_gen.clients.numberOfClients >= ssl_gen.max_connections ) {
                        writefln( "Rejected connection from %s; too many connections.", client.remoteAddress().toString() );
                        client.disconnect();
                        assert( !client.isAlive );
                        assert( ssl_gen.listener.isAlive );
                }
                else {
                    bool operation_complete;
                    writefln("Is client nul? %s", client is null);
                    do {
                        writeln("trying to accept");
                        writefln("Is ssl_gen null: %s, is listener null: %s", ssl_gen is null, ssl_gen.listener is null);
                        operation_complete = ssl_gen.listener.acceptSslAsync(client);
                        writeln("Operation complete: ", operation_complete);
                        if ( !operation_complete ) {
                            Fiber.yield();
                        }
                    } while(!operation_complete);

                    assert( client.isAlive );
                    assert( ssl_gen.listener.isAlive );

                    if ( ssl_gen.clients.numberOfClients < ssl_gen.max_connections )
                    {
                        writefln( "Connection from %s established.", client.remoteAddress().toString() );
                        ssl_gen.clients.addClient(client);
                        writefln( "\tTotal connections: %d", ssl_gen.clients.numberOfClients );
                    }
                }
            } catch(SocketException ex) {
                writefln("SslSocketException: %s", ex);
            }
        }

        // void reuseCount() {
        //     reuse_counter++;
        // }


        // bool reuse() {
        //     return reuse_counter < ssl_gen.max_number_of_fiber_reuse;
        // }

        void durationTimer() {
            uint counter;
            while (counter < ssl_gen.max_number_of_fiber_reuse) {
                const start_cycle_timestamp = MonoTime.currTime;
                Fiber.yield();
                const end_cycle_timestamp = MonoTime.currTime;
                Duration time_elapsed = end_cycle_timestamp - start_cycle_timestamp;
                writeln("Time elapsed: ", time_elapsed);
                if ( time_elapsed < ssl_gen.min_full_cycle_time ) {
                    Thread.sleep(ssl_gen.min_full_cycle_time - time_elapsed);
                    writeln("Sleeping");
                }

                counter++;
            }
        }

        static bool active() {
            writefln("min number of fibers: %d, and current free fibers: %d", ssl_gen.min_number_of_fibers, free_fibers.length);
            return fibers_to_execute.length > 0;
        }
    }

    public {

        this ()
        in {
            assert(ssl_gen.listener !is null);
        }
        do {
            super(&this.accept);
            if ( first_fiber is null ) {
                first_fiber = this;
                writeln("Set first fiber");
            }
        }

        this (void function() func)
        in {
            assert(ssl_gen.listener !is null);
            assert(func !is null);
            assert(first_fiber !is null);
        }
        do {
            super(func);
        }


        static acceptWithFiber()
        in{
            assert(fibers !is null);
            assert(ssl_gen.listener !is null);
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
                if ( fibers.length >= ssl_gen.max_number_of_fibers ) {
                    writeln("Service denial: Max number of fibers used and no free fibers avaliable.");
                    ssl_gen.listener.rejectClient();
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
            assert(ssl_gen !is null);
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
                if ( fib.state == Fiber.State.TERM ) {
                    if ( SSLFiber.first_fiber !is fib ) { //not the first fiber, which holds the context
                        if ( key < ssl_gen.min_number_of_fibers ) { //If the key is less than min number of fibers
                            writeln("Adding terminated fiber to free fiber");
                            fib.reset;
                            addFreeFiber(key);
                        } else { //remove the fiber
                            writeln("Removing fiber from fibers.");
                            //fibers.remove(key);
                        }
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
            assert(ssl_gen !is null);
        }
        out {
            assert(fibers !is null);
            assert(fiber_counter == ssl_gen.min_number_of_fibers);
            assert(free_fibers !is null);
        }
        body {
            writeln("InitFibers;");
            for(int i = 0; i < ssl_gen.min_number_of_fibers ; i++) {
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


struct ScriptingEngine {

private:
    SharedClientAccess shared_clients_access = SharedClientAccess();
    alias clients = this.shared_clients_access;
    immutable char[] _listener_ip_address;
    immutable ushort _listener_port;
    const uint _max_connections;
    immutable uint _listener_max_queue_length;
    const uint _max_number_of_accept_fibers;
    const Duration _min_full_cycle_time_accept_fibers;
    const uint _max_number_of_fiber_reuse;

    OpenSslSocket _listener;
    enum _buffer_size = 1024;

public:

    this (Options.ScriptingEngine se_options) {
        _listener_ip_address = se_options.listener_ip_address;
        _listener_port = se_options.listener_port;
        _listener_max_queue_length = se_options.listener_max_queue_lenght;
        _max_connections = se_options.max_connections;
        _max_number_of_accept_fibers = se_options.max_number_of_accept_fibers;
        _min_full_cycle_time_accept_fibers = dur!"msecs"(se_options.min_duration_full_fibers_cycle_ms);
        _max_number_of_fiber_reuse = se_options.max_number_of_fiber_reuse;
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

        _listener = new SSocket(AddressFamily.INET, EndpointType.Server);
        assert(_listener.isAlive);
        _listener.configureContext("pem_files/domain.pem", "pem_files/domain.key.pem");
        _listener.blocking = false;
        _listener.bind( new InternetAddress( _listener_ip_address, _listener_port ) );
        _listener.listen( _listener_max_queue_length );
        writefln("Started scripting engine API started on %s:%s.", _listener_ip_address, _listener_port);

        auto s_e_w_c = startScriptingEngineWorker();
        if ( SSLFiber.ssl_gen is null ) {
            SSLFiber.ssl_gen = new SSLFiberGeneral(_max_number_of_accept_fibers,
                                                    _max_number_of_fiber_reuse,
                                                    _max_connections,
                                                    _min_full_cycle_time_accept_fibers,
                                                    clients,
                                                    _listener);
        }

        SSLFiber.initFibers;
        writeln("Initiated fibers");

        auto socket_set = new SocketSet(1);
        Fiber ssl_accept_fib;
        while ( run_scripting_engine ) {

            socket_set.add( _listener );

            int sel_res;

            if ( SSLFiber.active ) {
                writeln("SSLFiber active");
                sel_res = Socket.select( socket_set, null, null, dur!"msecs"(1000));
            }
            else {
                writeln("SSLFiber not active");
                sel_res = Socket.select( socket_set, null, null);
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
            s_e_w_c.scripting_engine_worker.stop();
            s_e_w_c.scripting_engine_worker_thread.join;
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
