module tagion.script.ScriptingEngine;

import std.stdio : writeln, writefln;
import tagion.Options;
import tagion.Base : Control;
import core.thread;
import std.socket : InternetAddress, Socket, SocketException, SocketSet, TcpSocket, SocketShutdown, shutdown, AddressFamily;
import tagion.network.SslSocket;
import core.atomic;

alias SSocket = OpenSslSocket;

synchronized
class SharedClients {
    private shared (SSocket[uint])* _locate_clients;
    private shared uint _client_counter;
    private SSocket[uint] clients;

    bool active() const pure {
        return (_locate_clients !is null && length > 0);
    }

    uint useNextKey () {
        atomicOp!"+="(this._client_counter, 1); //0 is used as a null value in the reference call between accept.
        return cast(uint)_client_counter;
    }

    uint length() pure const  {
        uint res;
        if (_locate_clients !is null ) {
            auto clients = cast(SSocket[uint]) *_locate_clients;
            res = cast(uint)clients.length;
        }
        return res;
    }

    void add(ref SSocket client, uint key)
    in {
        assert(client !is null && key != 0);
        assert(_client_counter <= _client_counter.max);
    }
    body {
        if ( _locate_clients is null ) {
            writeln("Adding the first locate client element");
            clients[key] = cast(typeof(clients.values[0]))client;
            _locate_clients = cast(typeof(_locate_clients))&clients;
            writeln("Added the first locate client element");
        } else {
            auto clients = cast(SSocket[uint]) *_locate_clients;
            clients[key] = client;
        }
    }

    void removeClient(uint key)
    in {
        assert(_locate_clients !is null);
        assert(key in *_locate_clients);
    }
    out{
        assert(key !in *_locate_clients);
    }
    body{
        auto clients = cast(SSocket[uint]) *_locate_clients;
        clients.remove(key);
    }


    void closeAll()  {
        if ( active ) {
            auto clients = cast(SSocket[uint]) *_locate_clients;
            foreach ( key, client; clients ) {
                client.disconnect;
            }
            _locate_clients = null;
            _client_counter = 0;
        }
    }

    void addClientsToSocketSet(ref SocketSet socket_set)
    in {
        assert(socket_set !is null);
    }
    body {
        if ( active ) {
            auto clients = cast(SSocket[uint]) *_locate_clients;
            foreach(client; clients) {
                socket_set.add(client);
                writeln("Added a cloent to socket set");
            }
        }
    }

    void readDataAllClients(ref SocketSet socket_set)
        in{
            assert(socket_set !is null);
        }
        body {
            if ( !active ) {
                return;
            }
            auto clients = cast(SSocket[uint]) *_locate_clients;
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
    static shared(SharedClients) _shared_clients;
    SSocket _listener;
    SSocket[uint] _clients;
    static ScriptingEngineOptions s_e_options;

    void checkSharedClient() {
        if( _shared_clients is null ) {
            _shared_clients = new shared(SharedClients)();
        }
    }

public:

    this(ref SSocket listener, ScriptingEngineOptions se_options)
    in {
        assert(_listener is null);
    }
    out{
        assert(_listener !is null);
    }
    body{
        this._listener = listener;
        s_e_options = se_options;
        checkSharedClient();
    }

    this (ScriptingEngineOptions se_options) {
        s_e_options = se_options;
        checkSharedClient();
    }

    SSocket listener() {
        return _listener;
    }

    uint numberOfClients() const
    in {
        assert(_shared_clients !is null);
    }
    body{
        return _shared_clients.length;
    }

    bool active() const {
        return (_shared_clients !is null) && _shared_clients.active;
    }

    uint useNextKey()
    in{
        assert(_shared_clients !is null);
    }
    body {
        return _shared_clients.useNextKey;
    }

    bool acceptAsync(ref uint key)
    in {
        if ( key != 0) {
            assert (key in _clients);
        }
        assert(s_e_options !is null, "s_e_options is null");
    }
    out {
        assert (key in _clients);
    }
    body {
        try {
            SSocket client;
            if ( key == 0 ) {
                writeln("Key is 0");
                key = useNextKey;
                writeln("Key is:", key);
            } else {
                client = _clients[key];
            }

            if ( numberOfClients >= s_e_options.max_connections ) {
                    _listener.rejectClient();
                    assert( _listener.isAlive );
            }
            else {
                writeln("In main accept");
                bool operation_complete;
                writefln("Is client nul? %s", client is null);
                writeln("trying to accept");
                writefln("Is listener null: %s", _listener is null);
                operation_complete = _listener.acceptSslAsync(client);
                if ( key !in _clients ) {
                    _clients[key] = client;
                }
                writeln("Operation complete: ", operation_complete);
                if ( !operation_complete ) {
                    return false;
                }
                else {
                    assert( client.isAlive );
                    assert( _listener.isAlive );

                    if ( numberOfClients < s_e_options.max_connections )
                    {
                        writefln( "Connection from %s established.", client.remoteAddress().toString() );
                        _shared_clients.add(client, key);
                        writefln( "\tTotal connections: %d", numberOfClients );
                    }
                }
            }

        } catch(SocketException ex) {
            writefln("SslSocketException: %s", ex);
        }

        return true;
    }




    void closeAll() {
        if ( active ) {
            _shared_clients.closeAll;
        }
    }

    void addClientsToSocketSet(ref SocketSet socket_set) {
        if ( socket_set !is null && active ) {
            _shared_clients.addClientsToSocketSet(socket_set);
        }
    }

    void readDataAllClients(ref SocketSet socket_set) {
        if ( active ) {
            _shared_clients.readDataAllClients(socket_set);
        }
    }
}


class SSLFiber : Fiber {
    private {
        static Fiber[uint] fibers;
        static uint fiber_counter;
        static uint[] free_fibers;
        static uint[] fibers_to_execute;
        static Fiber duration_fiber;
        static SharedClientAccess shared_client_access;
        static ScriptingEngineOptions s_e_options;
        alias clients = shared_client_access;
        uint reuse_counter;

        void acceptAsync()
        in {
            assert(s_e_options !is null);
        }
        body {
            bool operation_complete;
            uint client_index;

            do {
                writeln("Calling accept async with client_index: ", client_index);
                operation_complete = clients.acceptAsync(client_index);
                writeln("Operation complete: ", operation_complete);
                if ( !operation_complete ) {
                    Fiber.yield();
                }
            } while(!operation_complete);
        }

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
     enum max_number_calls = 10;

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
    SharedClientAccess shared_clients_access;
    alias clients = this.shared_clients_access;
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


        auto s_e_w_c = startScriptingEngineWorker();

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

ScriptingEngineContext startScriptingEngine () {
    auto s_e_c = ScriptingEngineContext();

    s_e_c.scripting_engine = ScriptingEngine();

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
    SharedClientAccess shared_client_access;
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
        auto s_e_options = new ScriptingEngineOptions(options.scripting_engine);
        shared_client_access = SharedClientAccess(s_e_options);
        while (run_scripting_engine_worker) {
        if ( clients.active ) {
            clients.addClientsToSocketSet(socket_set);
            const res = Socket.select(socket_set, null, null, dur!"msecs"(50));
            if ( res > 0) {
                clients.readDataAllClients(socket_set);
            }
            socket_set.reset;
        }
           Thread.sleep(dur!"msecs"(50));
        }

        scope(exit) {
            writeln("Closing scripting engine worker.");
        }
    }
}
