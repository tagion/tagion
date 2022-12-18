module tagion.network.FiberServer;

import core.thread : Thread, Fiber;
import core.time; // : dur, Duration, MonoTime;
import std.socket : SocketSet, SocketException, Socket, AddressFamily, SocketShutdown;
import std.exception;
import std.concurrency;
import std.format;

//import tagion.network.SSLSocket;
import tagion.network.SSLServiceOptions : ServerOptions;
import tagion.network.NetworkExceptions : check;
import tagion.network.SSLSocketException : SSLSocketException;
import tagion.basic.Message;
import tagion.basic.Types : Buffer, Control;
import tagion.logger.Logger;
import tagion.basic.ConsensusExceptions;
import tagion.basic.TagionExceptions : taskfailure, fatal;
import io = std.stdio;
import LEB128 = tagion.utils.LEB128;

/++
 The exception used by the fiber service
+/
@safe
class SocketFiberException : SSLSocketException {
    import tagion.network.SSL : SSLErrorCodes;

    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, SSLErrorCodes.SSL_ERROR_NONE, file, line);
    }
}

/++
 Fiber timeout exception
+/
@safe
class SocketTimeout : SocketFiberException {
    const Duration timeout;
    this(const Duration timeout, string file = __FILE__, size_t line = __LINE__) {
        this.timeout = timeout;
        super(format("Timeout %s", timeout).idup, file, line);
    }
}

/++
 Interface used for by the FiberServer Relay delegate
+/
@safe
interface FiberRelay {
    alias Time = typeof(MonoTime.currTime);
    void startTime(); /// Start the timeout timer
    void checkTimeout() const; /// Check the timeout

    bool locked() const pure nothrow;
    void lock() nothrow;
    void unlock() nothrow;

    Buffer response(); /// Response from the service
    bool available();
    @property uint id();
    immutable(ubyte[]) receive(); /// Recives from the service socket
    void send(immutable(ubyte[]) buffer); /// Send to the service socket
    void raw_send(immutable(ubyte[]) buffer); // Send directly to socket
}

/++
Server using one fibers per connection 
+/
@safe
class FiberServer {
    immutable(ServerOptions) opts;
    @safe interface Relay {
        bool agent(FiberRelay sslfiber);
    }
    //alias Relay = bool delegate(SSLRelay) @safe;

    @safe
    this(immutable(ServerOptions) opts, Socket listener, Relay relay) {
        this.opts = opts;
        this.listener = listener;
        this.relay = relay;
        handler = new Response;
    }

    protected {
        SocketFiber[uint] active_fibers;
        SocketFiber[] recycle_fibers;
        uint _fiber_id;
        Relay relay;
        Socket listener;
        Tid response_service_tid;
        uint next_fiber_id() {
            if (_fiber_id == 0) {
                _fiber_id = 1;
            }
            else {
                _fiber_id++;
            }
            return _fiber_id;
        }

        shared Response handler;
    }

    /++
     Response buffer from a services
     +/
    synchronized static class Response {
        protected shared(Buffer[uint]) responses;
        /++
         set response buffer
         Params:
         fiber_id = Id of the fiber which should handle this response
         response = Reponse buffer
         +/
        void set(immutable uint fiber_id, ref Buffer response) {
            scope (exit) {
                response = null;
            }
            responses[fiber_id] = response;
        }

        /++
         Get the reponse buffer and remove it
         Params:
         fiber_id = Id of the fiber which should handle this response
         +/
        Buffer get(immutable uint fiber_id) {
            if (fiber_id in responses) {
                auto result = responses[fiber_id];
                scope (exit) {
                    responses.remove(fiber_id);
                }
                return assumeUnique(result);
            }
            return null;
        }

        /++
         Returns:
         true if the a response is available on the fiber_id
         +/
        bool available(immutable uint fiber_id) const pure nothrow {
            return (fiber_id in responses) !is null;
        }

        /++
         Removes the response from the fiber_id
         +/
        void remove(immutable uint fiber_id) nothrow {
            assumeWontThrow(io.writefln("avaliable %s", available(fiber_id)));
            responses.remove(fiber_id);
        }
    }

    void addSocketSet(ref SocketSet socket_set) {
        foreach (fiber; active_fibers) {
            if (!fiber.locked) {
                socket_set.add(fiber.client);
            }
        }
    }

    /++
     Close all the fiber services
     +/
    @trusted
    void closeAll() {
        recycle_fibers = null;
        while (active_fibers.length) {
            foreach (fiber_id, fiber; active_fibers) {
                fiber.call;
                if (fiber.state is Fiber.State.TERM) {
                    fiber.shutdown;
                    active_fibers.remove(fiber_id);
                    handler.remove(fiber_id);
                }
            }
            Thread.sleep(opts.client_timeout.msecs);
        }
    }

    /++
     Allocated a new fiber service
     +/
    SocketFiber allocateFiber() {
        SocketFiber result;
        if (active_fibers.length < opts.max_connections) {
            const fiber_key = next_fiber_id;
            if (recycle_fibers.length > 0) {
                result = active_fibers[fiber_key] = recycle_fibers[$ - 1];
                recycle_fibers = recycle_fibers[0 .. $ - 1];
                result.setId(fiber_key);
            }
            else {
                result = active_fibers[fiber_key] = new SocketFiber(fiber_key);
            }
        }
        return result;
    }

    /++
       This function must be called the first time a client is accepted.
       Returns:
       null if the socket is not accept or if no more fiber are avaible
    +/
    @trusted
    SocketFiber acceptFiber() {
        auto fiber = allocateFiber;
        if (fiber) {
            fiber.call;
        }
        else {
            import tagion.network.SSLSocket;

            io.writefln("Reject!!!");
            auto _listener = cast(SSLSocket) listener;
            if (_listener) {
                _listener.rejectClient;
            }
        }
        return fiber;
    }

    /++
     Returns:
     true if some fibers are active
     +/
    bool fibersActive() const pure nothrow {
        return active_fibers.length > 0;
    }

    /++
     Executes the fiber services for all the socket_set
     +/
    @trusted
    void execute(ref SocketSet socket_set) {
        import std.socket : SocketOSException;

        io.writefln("Execute ");
        foreach (key, ref fiber; active_fibers) {
            void removeFiber() nothrow {
                fiber.shutdown;
                fiber.reset;
                recycle_fibers ~= fiber;
                active_fibers.remove(key);
                handler.remove(key);
            }
            try {

				io.writefln("id=%d", key);
                if (fiber.client is null) {
                    fiber.call;
                }
                else if (fiber.available) {
                    // Response receiver from the service
                    fiber.call;
                }
                else if (fiber.locked) {
                    fiber.call;
                }
                else if (socket_set.isSet(fiber.client)) {
                    fiber.call;
                }
                if (fiber.state is Fiber.State.TERM) {
                    removeFiber;
                }
            }
            catch (SocketOSException e) {
                io.writefln("%s %s", __FUNCTION__, e);
                removeFiber;
            }
            catch (SSLSocketException e) {
                io.writefln("%s %s", __FUNCTION__, e);

                removeFiber;
            }
        }
    }

    @trusted
    void send(uint id, immutable(ubyte[]) buffer)
    in {
        assert(id in active_fibers);
    }
    do {
        active_fibers[id].raw_send(buffer);
    }

    /++
     Socket service fiber
     +/
    class SocketFiber : Fiber, FiberRelay {
        @trusted
        static uint buffer_to_uint(const ubyte[] buffer) pure {
            return *cast(uint*)(buffer.ptr)[0 .. uint.sizeof];
        }

        protected {
            Socket client;
            bool _lock;
            FiberRelay.Time start_timestamp;
            uint fiber_id;
        }

        @property uint id() const pure nothrow {
            return fiber_id;
        }

        final bool locked() const pure nothrow {
            return _lock;
        }

        final void lock() nothrow {
            _lock = true;
        }

        final void unlock() nothrow {
            _lock = false;
        }

        /++
         Construct a service with the ID of fiber_id
         +/
        @trusted
        this(const uint fiber_id) {
            setId(fiber_id);
            super(&run);
        }

        /++
         Change the fiber_id for the service
         +/
        void setId(const uint fiber_id) {
            handler.remove(fiber_id);
            this.fiber_id = fiber_id;
        }

        /++
         Set the start-time for the timeout
         +/
        void startTime() {
            start_timestamp = MonoTime.currTime;
        }

        /++
         Check the time-out
         Throws:
         an SocketTimeout exception is thrown on timeout
         +/
        void checkTimeout() const {
            const time_elapsed = MonoTime.currTime - start_timestamp;
            if (time_elapsed > opts.client_timeout.msecs) {
                throw new SocketTimeout(time_elapsed);
            }
        }

        /++
         Returns:
         the service response
         +/
        Buffer response() {
            return handler.get(fiber_id);
        }

        /++
         Returns:
         true if the service has responded
         +/
        bool available() const {
            return handler.available(fiber_id);
        }
        /++
         Receives the buffer from the service socket
         Returns:
         received buffer
         +/
        @trusted
        immutable(ubyte[]) receive() {
            import std.stdio;
            import tagion.hibon.Document : Document;

            ubyte[] buffer;
            ubyte[] current;
            ptrdiff_t rec_data_size;
            // The length of the buffer is in leb128 format
            enum LEN_MAX = LEB128.calc_size(uint.max);
            auto leb128_len_data = new ubyte[LEN_MAX];
            current = leb128_len_data;
            uint leb128_index;
            leb128_loop: for (;;) {
                rec_data_size = client.receive(current);
                if (rec_data_size < 0) {
                    // Not ready yet
                    yield;
                }
                else if (rec_data_size == 0) {
                    // Error
                    return null;
                }
                else {

                    

                        .check(leb128_index < LEN_MAX,
                                message("Invalid size of len128 length field %d", leb128_index));
                    break leb128_loop;
                }
                checkTimeout;
                yield;
            }
            // receive data
            const leb128_len = LEB128.decode!uint(leb128_len_data);
            const buffer_size = leb128_len.value;
            //const buffer_size=buffer_to_uint(len_data);
            if (buffer_size > opts.max_buffer_size) {
                return null;
            }
            buffer = new ubyte[leb128_len.size + leb128_len.value];
            buffer[0 .. rec_data_size] = leb128_len_data[0 .. rec_data_size];
            current = buffer[rec_data_size .. $];
            while (current.length) {
                rec_data_size = client.receive(current);
                if (rec_data_size < 0) {
                    // Not ready yet
                    writeln("Timeout");
                    checkTimeout;
                }
                else {
                    current = current[rec_data_size .. $];
                }
                yield;
            }
            return buffer.idup;
        }

        /++
         send the buffer to the service socket
         +/
        @trusted
        void send(immutable(ubyte[]) buffer) {
            bool done;
            do {
                import tagion.hibon.Document;
                import tagion.hibon.HiBONJSON;

                io.writefln("send %s", Document(buffer).toPretty);
                const ret = client.send(buffer);
                if (ret > 0) {
                    done = true;
                }
                else {
                    yield;
                }
                checkTimeout;
            }
            while (!done);
        }

        /++
         Send directly to socket
         +/
        @trusted
        void raw_send(immutable(ubyte[]) buffer) {
            client.send(buffer);
        }

        /++
         Fiber service loop
         +/
        @trusted
        void run() {
            startTime;
            client = listener.accept;
            scope (exit) {
                //_client.shutdown(SocketShutdown.BOTH);
                shutdown;
                unlock;
            }
            check(client.isAlive, "Client is dear inside server fiber");
            /*
            import tagion.network.SSLSocket;

            auto _listener = cast(SSLSocket) listener;
            SSLSocket _client;
            if (_listener) {
                while (!_listener.acceptSSL(_client, accept_client)) {
                    checkTimeout;
                    yield;
                }
                client = _client;
            }
            else {
                client = accept_client;

            }
            assert(client.isAlive);
*/
            bool stop;
            while (!stop) {
                lock;

                stop = relay.agent(this);
                unlock;
            }
        }

        /++
         shutdown the service socket
         +/
        package void shutdown() nothrow {
            import std.socket : SocketShutdown;

            if (client) {
                client.shutdown(SocketShutdown.BOTH);
                client = null;
            }
            //handler.remove(fiber_id);
        }

        ~this() {
            shutdown;
        }
    }

    /++
     Starts the standard response service
     Params:
     task_name = the name used for the respose service (If the task_name is not defined the response service is not started)
     +/
    @trusted
    void start() {
        check(opts.response_task_name.length !is 0,
                "If a response task is needed the the response_task_name must be defined");
        check(response_service_tid is Tid.init,
                format("Response task %s has already been started", opts.response_task_name));
        response_service_tid = spawn(&responseService, opts.response_task_name, handler);

        check(receiveOnly!Control is Control.LIVE,
                format("%s was not started correctly", opts.response_task_name));
    }

    @trusted stop() {
        if (response_service_tid !is Tid.init) {
            response_service_tid.send(Control.STOP);
            check(receiveOnly!Control is Control.END,
                    format("Task %s did not end correctly", opts.response_task_name));
        }
    }
    /++
     Standard concurrency routine to handle service response
     +/
    @trusted
    static void responseService(
            immutable(string) response_task_name,
            shared Response handler) nothrow {
        try {
            import tagion.basic.Types : Control;
            import tagion.communication.HiRPC;
            import tagion.hibon.Document;

            log.register(response_task_name);
            bool stop;
            scope (exit) {
                ownerTid.send(Control.END);
            }

            void handleState(Control ts) {
                with (Control) {
                    switch (ts) {
                    case STOP:
                        stop = true;
                        break;
                    default:
                        log.error("Bad Control command %s", ts);
                    }
                }
            }

            HiRPC hirpc = HiRPC(null);

            void serviceResponse(Buffer data) {
                const doc = Document(data);
                const hirpc_received = hirpc.receive(doc);
                handler.set(hirpc_received.response.id, data);
            }

            ownerTid.send(Control.LIVE);
            while (!stop) {
                receive(
                        &handleState,
                        &serviceResponse,
                        &taskfailure
                );
            }
        }
        catch (Throwable t) {
            fatal(t);
        }
    }
}
