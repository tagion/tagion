module tagion.network.SSLSocketFiber;

import std.string : format;
import core.thread : Thread, Fiber;
import core.time : dur, Duration, MonoTime;
import std.socket : SocketSet, SocketException, Socket;
import tagion.script.ScriptingEngineOptions;
import tagion.network.SSLSocket;
alias SSocket = OpenSslSocket;

@safe
class SSLSocketFiberException : SSLSocketException {
        this( immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line);
    }
}

@trusted
class SSLSocketFiber : Fiber {
    debug{
        pragma(msg,"Compiles SslFiber in debug mode" );
            enum in_debugging_mode = true;

            import std.stdio : writeln;
            static void printDebugInformation (string msg) {
                int i;
                writeln(msg);
            }
    }

    private {
        static SSLSocketFiber[uint] fibers;
        static uint fiber_counter;
        static uint[] free_fibers;
        static uint[] fibers_to_execute;
        static Fiber duration_fiber;

        static SSocket[uint] clients;
        static uint client_counter;

        ulong _reuse_counter;


        void acceptAsync()
        in {
            assert(s_e_options !is null);
        }
        body {
            bool operation_complete;
            uint accept_call_counter;
            uint key;
            SSocket client;

            try {
                assert( listener.isAlive );

                if ( clientsCount >= s_e_options.max_connections ) {
                    listener.rejectClient();
                }
                else {
                    do {
                        operation_complete = listener.acceptSslNonBlocking(client);
                        accept_call_counter++;

                        if ( accept_call_counter >= s_e_options.max_accept_call_tries ) {
                            throw new SSLSocketFiberException(format("Max accept tries of %d reached.", accept_call_counter));
                        }

                        if ( !operation_complete ) {
                            Fiber.yield;
                        }
                    } while(!operation_complete);

                    if ( clientsCount < s_e_options.max_connections )
                    {
                        addClient(client);
                        static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                            printDebugInformation(format("Connection from %s established.", client.remoteAddress().toString() ) );
                            printDebugInformation(format("\tTotal connections: %d", clientsCount) );
                        }
                    }
                    else {
                        throw new SSLSocketFiberException("Connection refused, to many connections.");
                    }
                }
            }
            catch(SocketException ex) {

                if ( client !is null ) {
                    client.disconnect;
                }
            }
        }

        void durationTimer() {
            uint counter;
            while (counter < s_e_options.max_number_of_fiber_reuse) {
                const start_cycle_timestamp = MonoTime.currTime;
                Fiber.yield();
                const end_cycle_timestamp = MonoTime.currTime;
                Duration time_elapsed = end_cycle_timestamp - start_cycle_timestamp;
                if ( time_elapsed < s_e_options.min_duration_full_fibers_cycle_ms ) {
                    Thread.sleep(s_e_options.min_duration_full_fibers_cycle_ms - time_elapsed);
                }

                counter++;
            }
        }

        static uint useNextKey ()
        out {
            assert(client_counter < client_counter.max);
        }
        body{
            client_counter++;
            return client_counter;
        }


    }

    public {
        static ScriptingEngineOptions s_e_options;
        static SSocket listener;

        this ()
        in {
            assert(s_e_options !is null);
        }
        do {
            super(&this.acceptAsync);
        }

        this (void function() func)
        in {
            assert(func !is null);
        }
        do {
            super(func);
        }

        static bool active() {
            static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                printDebugInformation(format("min number of fibers: %d, and current free fibers: %d of total fibers: %d", s_e_options.min_number_of_fibers, free_fibers.length, fibers.length) );
            }
            return fibers_to_execute.length > 0;
        }

        void reuseCount() {
            _reuse_counter++;
        }

        bool reuse() const
        in{
             assert(s_e_options !is null);
        }
        body{
            return _reuse_counter < s_e_options.max_number_of_fiber_reuse;
        }

        static void addClient(SSocket client)
        in {
            assert(client !is null);
        }
        body {
            auto key = useNextKey;
            clients[key] = client;
        }

        static void removeClient(uint key)
        in {
            assert(clients !is null);
            assert(key in clients);
        }
        out{
            assert(key !in clients);
        }
        body{
            clients.remove(key);
        }


        static void addClientsToSocketSet(ref SocketSet socket_set)
        in {
            assert(socket_set !is null);
        }
        body {
            if ( clientsActive ) {
                foreach(client; clients) {
                    socket_set.add(client);
                }
            }
        }

        static ulong clientsCount() {
            ulong res;
            if (clients !is null ) {
                res = clients.length;
            }
            return res;
        }

        static bool clientsActive() {
            return (clients !is null && clientsCount > 0);
        }

        static void clientsCloseAll()  {
            if ( clientsActive ) {
                foreach ( client; clients ) {
                    client.disconnect;
                }
                clients = null;
                client_counter = 0;
            }
        }

        static void handleClients(SocketSet socket_set)
        in {
            assert(socket_set !is null);
        }
        body{
            if ( clientsActive ) {
                foreach(key, client; clients) {
                    if( socket_set.isSet(client) )  {
                        char[4096] buffer;
                        enum max_data_size = 4096;
                        int pending_data;
                        bool read_done;
                        bool send_done;
                        int rec_data_length;
                        int send_data_length;
                        string result;
                        enum max_read_tries = 100;
                        enum max_send_tries = 100;
                        uint read_counter;
                        uint send_counter;

                        try {
                            do {
                                rec_data_length = client.receiveNonBlocking(buffer[], pending_data);
                                read_counter++;
                                if ( rec_data_length == Socket.ERROR ) {
                                    throw new SSLSocketFiberException("Socket Error.");
                                }

                                if ( rec_data_length > 0) {
                                    result ~= buffer[0..rec_data_length];

                                    if ( pending_data > 0 ) {
                                        if ( (result.length + pending_data) > max_data_size ) {
                                            throw new SSLSocketFiberException("Receive package larger than max data size.");
                                        }
                                    }
                                    else {
                                        read_done = true;
                                    }
                                }

                            } while(!read_done && read_counter < max_read_tries);

                            if ( result.length > 0) {
                                pending_data = 0;
                                do {
                                    send_data_length = client.sendNonBlocking(result[0..result.length], pending_data);

                                        if ( pending_data > 0 ) {
                                            if ( (send_data_length + pending_data) > max_data_size ) {
                                                throw new SSLSocketFiberException("Send package larger than max data size.");
                                            }
                                        }
                                        else {
                                            send_done = true;
                                        }

                                }while(!send_done && send_counter < max_send_tries);

                                //Check dataformat
                                //Call scripting engine
                                //Send response back
                            }
                        }
                        catch(SocketException ex) {
                            writeln(ex);
                        }


                        client.disconnect();

                        removeClient(key);
                    }

                    else if ( !client.isAlive ) {
                        client.disconnect();

                        removeClient(key);
                    }

                    static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                        printDebugInformation(format("\tTotal connections: %d", clientsCount) );
                    }
                }
            }
        }

        static acceptWithFiber()
        in{
            assert(fibers !is null);
        }
        out{
            static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                printDebugInformation( format("Added fiber. Fibers to execute: %d, free fibers: %d, total fibers: %d",
                fibers_to_execute.length, free_fibers.length, fibers.length) );
            }
        }
        body {
            auto has_free_fiber = hasFreeFibers;
            if ( has_free_fiber ) {
                addFiberToExecute( useNextFreeFiber );
            }
            else {
                if ( fibers.length >= s_e_options.max_number_of_accept_fibers ) {
                    static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                        printDebugInformation("Service denial: Max number of fibers used and no free fibers avaliable.");
                    }
                    listener.rejectClient();
                }
                auto new_fib = new SSLSocketFiber();
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
            if(fibers_to_execute is null ) {
                return;
            }
            SSLSocketFiber fib;
            uint[] temp_fibers_to_execute;
            temp_fibers_to_execute = fibers_to_execute;
            fibers_to_execute = null;
            assert(temp_fibers_to_execute !is null);
            duration_fiber.call;
            if ( duration_fiber.state == Fiber.State.TERM ) {
                auto dur_func = &durationTimer;
                duration_fiber = new SSLSocketFiber(dur_func);
                duration_fiber.call;
            }

            foreach(key; temp_fibers_to_execute) {
                fib = fibers[key];
                fib.call;
                if ( fib.state == Fiber.State.TERM ) {
                    if ( key < s_e_options.min_number_of_fibers ) { //If the key is less than min number of fibers
                        if ( fib.reuse ) {
                            fib.reset;
                            fib.reuseCount;
                        } else {
                            fibers[key] = new SSLSocketFiber();
                        }

                        addFreeFiber(key);
                    } else { //remove the fiber
                        fibers.remove(key);
                    }

                } else {
                    addFiberToExecute(key);
                }
            }
        }

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
                auto acc_fib = new SSLSocketFiber();
                fibers[fiber_counter] = acc_fib;
                addFreeFiber(fiber_counter);
                fiber_counter++;
            }

            auto dur_func = &durationTimer;
            duration_fiber = new SSLSocketFiber(dur_func);
            duration_fiber.call;
        }
    }
}