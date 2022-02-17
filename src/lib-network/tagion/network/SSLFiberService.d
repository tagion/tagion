module tagion.network.SSLFiberService;

import std.string : format;
import core.thread : Thread, Fiber;
import core.time; // : dur, Duration, MonoTime;
import std.socket : SocketSet, SocketException, Socket, AddressFamily;
import std.exception;
import std.socket : SocketShutdown;
import std.concurrency;

import tagion.network.SSLSocket;
import tagion.network.SSLOptions;
import tagion.network.NetworkExceptions : check;
import tagion.basic.Message;
import tagion.basic.Basic : Buffer;
import tagion.logger.Logger;
import tagion.basic.ConsensusExceptions;
import tagion.basic.TagionExceptions : taskfailure, fatal;

//import tagion.services.LoggerService;
import LEB128 = tagion.utils.LEB128;

/++
 The exception used by the fiber service
+/
@safe
class SSLSocketFiberException : SSLSocketException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, SSLErrorCodes.SSL_ERROR_NONE, file, line);
    }
}

/++
 Fiber timeout exception
+/
@safe
class SSLSocketTimeout : SSLSocketFiberException {
    const Duration timeout;
    this(const Duration timeout, string file = __FILE__, size_t line = __LINE__) {
        this.timeout = timeout;
        super(format("Timeout %s", timeout).idup, file, line);
    }
}

/++
 Interface used for by the SSLFiberService Relay delegate
+/
@safe
interface SSLFiber {
    alias Time = typeof(MonoTime.currTime);
    void startTime(); /// Start the timeout timer
    void checkTimeout() const; /// Check the timeout

    bool locked() const pure nothrow;
    void lock() nothrow;
    void unlock() nothrow;

    Buffer response(); /// Response from the service
    @property uint id();
    immutable(ubyte[]) receive(); /// Recives from the service socket
    void send(immutable(ubyte[]) buffer); /// Send to the service socket
}

/++
 SSL Service
+/
@safe
class SSLFiberService {
    immutable(SSLOption) ssl_options;
    @safe interface Relay {
        bool agent(SSLFiber sslfiber);
    }
    //alias Relay = bool delegate(SSLRelay) @safe;

    @safe
    this(immutable(SSLOption) opts, SSLSocket listener, Relay relay) {
        this.ssl_options = opts;
        this.listener = listener;
        this.relay = relay;
        handler = new Response;
    }

    protected {
        SSLSocketFiber[uint] active_fibers;
        SSLSocketFiber[] recycle_fibers;
        uint _fiber_id;
        Relay relay;
        //        const(HiRPC) hirpc;
        SSLSocket listener;
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
        void set(immutable uint fiber_id, shared Buffer response) {
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
        void remove(immutable uint fiber_id) {
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
            Thread.sleep(ssl_options.client_timeout.msecs);
        }
    }

    /++
     Allocated a new fiber service
     +/
    SSLSocketFiber allocateFiber() {
        SSLSocketFiber result;
        if (active_fibers.length < ssl_options.max_connections) {
            const fiber_key = next_fiber_id;
            if (recycle_fibers.length > 0) {
                result = active_fibers[fiber_key] = recycle_fibers[$ - 1];
                recycle_fibers = recycle_fibers[0 .. $ - 1];
                result.setId(fiber_key);
            }
            else {
                result = active_fibers[fiber_key] = new SSLSocketFiber(fiber_key);
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
    SSLSocketFiber acceptFiber() {
        auto fiber = allocateFiber;
        if (fiber) {
            fiber.call;
        }
        else {
            listener.rejectClient;
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

        foreach (key, ref fiber; active_fibers) {
            void removeFiber() {
                fiber.shutdown;
                fiber.reset;
                recycle_fibers ~= fiber;
                active_fibers.remove(key);
                handler.remove(key);
            }

            try {
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
                removeFiber;
            }
            catch (SSLSocketException e) {
                removeFiber;
            }
        }
    }

    /++
     SSL Socket service fiber
     +/
    class SSLSocketFiber : Fiber, SSLFiber {
        version (none) @trusted
        static uint buffer_to_uint(const ubyte[] buffer) pure {
            return *cast(uint*)(buffer.ptr)[0 .. uint.sizeof];
        }

        protected {
            SSLSocket client;
            bool _lock;
            SSLFiber.Time start_timestamp;
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
         an SSLSocketTimeout exception is thrown on timeout
         +/
        void checkTimeout() const {
            const time_elapsed = MonoTime.currTime - start_timestamp;
            if (time_elapsed > ssl_options.client_timeout.msecs) {
                throw new SSLSocketTimeout(time_elapsed);
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
            ubyte[] buffer;
            ubyte[] current;
            ptrdiff_t size;
            for (;;) {
                if (buffer is null) {
                    // The length of the buffer is in leb128 format
                    enum LEN_MAX = LEB128.calc_size(uint.max);
                    auto leb128_len_data = new ubyte[LEN_MAX];
                    current = leb128_len_data;
                    uint leb128_index;
                    leb128_loop: for (;;) {
                        const rec_data_size = client.receive(current);
                        log("curr: %s", leb128_len_data);
                        if (rec_data_size < 0) {
                            // Not ready yet
                            yield;
                        }
                        else if (rec_data_size == 0) {
                            // Error
                            return null;
                        }
                        else {
                            size += rec_data_size;
                            while (leb128_index < size) {

                                

                                    .check(leb128_index < LEN_MAX, message("Invalid size of len128 length field %d", leb128_index));
                                if ((leb128_len_data[leb128_index++] & 0x80) is 0) {
                                    // End of LEB128 size when bit 7 is 0
                                    break leb128_loop;
                                }
                            }
                            current = current[size .. $];

                            checkTimeout;
                            yield;
                        }
                    }
                    const leb128_len = LEB128.decode!uint(leb128_len_data);
                    const buffer_size = leb128_len.value;
                    if (buffer_size > ssl_options.max_buffer_size) {
                        return null;
                    }
                    buffer = new ubyte[leb128_len.size + leb128_len.value];
                    buffer[0 .. leb128_len.size] = leb128_len_data[0 .. leb128_len.size];
                    current = buffer[leb128_len.size .. $];
                }
                current = current[size .. $];
                if (current.length == 0) {
                    return assumeUnique(buffer);
                }
                else {
                    checkTimeout;
                }
                yield;
            }
            assert(0);
        }

        /++
         send the buffer to the service socket
         +/
        @trusted
        void send(immutable(ubyte[]) buffer) {
            bool done;
            do {
                const ret = client.send(buffer);
                if (ret > 0) {
                    done = true;
                }
                else if (ret <= 0) {
                    yield;
                }
                checkTimeout;
            }
            while (!done);
        }

        /++
         Fiber service loop
         +/
        @trusted
        void run() {
            startTime;
            scope accept_client = listener.accept;
            scope (exit) {
                accept_client.shutdown(SocketShutdown.BOTH);
                shutdown;
                unlock;
            }
            assert(accept_client.isAlive);

            while (!listener.acceptSSL(client, accept_client)) {
                checkTimeout;
                yield;
            }
            assert(client.isAlive);

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
        void shutdown() {
            import std.socket : SocketShutdown;

            if (client) {
                client.shutdown(SocketShutdown.BOTH);
                client = null;
            }
            handler.remove(fiber_id);
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
    Tid start(immutable(string) task_name) {
        if (task_name) {
            return spawn(&responseService, task_name, handler);
        }
        return Tid.init;
    }

    /++
     Standard concurrency routine to handle service response
     +/
    @trusted
    static void responseService(immutable(string) task_name, shared Response handler) nothrow {
        try {
            import tagion.basic.Basic : Control;
            import tagion.communication.HiRPC;
            import tagion.hibon.Document;

            log.register(task_name);
            ownerTid.send(Control.LIVE);
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
                shared shared_data = cast(shared) data;
                handler.set(hirpc_received.response.id, shared_data);
            }

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
