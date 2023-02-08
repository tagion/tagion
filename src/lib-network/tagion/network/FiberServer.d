module tagion.network.FiberServer;

import core.thread : Thread, Fiber;
import core.time; // : dur, Duration, MonoTime;
import std.socket : SocketSet, SocketException, Socket, AddressFamily, SocketShutdown;
import std.exception;
import std.concurrency;
import std.format;
import std.algorithm.iteration : each, map, filter;
import std.algorithm.searching : any, find;
import std.range;
import std.typecons : Typedef;

//import tagion.network.SSLSocket;
import tagion.network.SSLServiceOptions : ServerOptions;
import tagion.network.NetworkExceptions : check;
import tagion.network.SSLSocketException : SSLSocketException;
import tagion.basic.Message;
import tagion.basic.Types : Buffer, Control;
import tagion.logger.Logger;
import tagion.basic.ConsensusExceptions;
import tagion.basic.TagionExceptions : taskfailure, fatal;
import tagion.communication.HiRPC : HiRPC;
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
    bool available(); /// True if send buffer is available
    void remove(); /// Remove send buffer
    @property uint id();
    @property void id(const uint _id);
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

    this(immutable(ServerOptions) opts, Relay relay) {
        this.opts = opts;
        socket_fibers.length = opts.max_queue_length;
        foreach (fiber_id, ref fiber; socket_fibers) {
            fiber = new SocketFiber(fiber_id);
        }
        this.relay = relay;
        handler = new shared(Response);
    }

    protected {
        SocketFiber[] socket_fibers;
        Relay relay;
        Tid response_service_tid;
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
        void set(immutable uint id, shared Buffer response) {
            responses[id] = response;
        }

        /++
         Get the reponse buffer and remove it
         Params:
         fiber_id = Id of the fiber which should handle this response
         +/
        Buffer get(immutable uint id) {
            if (id in responses) {
                auto result = responses[id];
                scope (exit) {
                    responses.remove(id);
                }
                return result;
            }
            return null;
        }

        /++
         Returns:
         true if the a response is available on the fiber_id
         +/
        bool available(immutable uint id) const pure nothrow {
            return (id in responses) !is null;
        }

        /++
         Removes the response from the fiber_id
         +/
        void remove(immutable uint id) {
            responses.remove(id);
        }

    }

    /++
     Close all the fiber services
     +/
    @trusted
    void closeAll() {
        foreach (fiber; socket_fibers) {
            fiber.shutdown;
            fiber.reset;
        }
    }

    void addSocketSet(ref SocketSet socket_set) {
        socket_fibers
            .map!(fiber => fiber.client)
            .filter!(client => client !is null)
            .each!(client => socket_set.add(client));
    }

    FiberId responseId(const uint id) pure const {
        auto response_fibers = socket_fibers
            .find!(fiber => fiber.id == id);
        check(!response_fibers.empty, format("Response id %d not found", id));
        return response_fibers.front.fiber_id;
    }
    /++
     Executes the fiber services for all the socket_set
     +/
    @trusted
    void execute(SocketSet socket_set) {
        import std.socket : SocketOSException;

        foreach (fiber; socket_fibers) {
            void removeFiber() nothrow {
                fiber.shutdown;
                fiber.reset;
            }

            try {
                if (fiber.client is null) {
                    if (fiber.state !is Fiber.State.TERM) {
                        fiber.reset;
                    }
                }
                else if (fiber.available && fiber.locked) {
                    // Response receiver from the service
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

    bool slotAvailable() const pure nothrow @nogc {
        return socket_fibers
            .any!(fiber => fiber.client is null);
    }

    void applyClient(Socket client) {
        auto available_fibers = socket_fibers
            .find!(fiber => fiber.client is null);
        check(!available_fibers.empty, "No client is availanble in the service");
        available_fibers.front.client = client;
    }

    void send(uint id, immutable(ubyte[]) buffer) {
        socket_fibers[id].raw_send(buffer);
    }

    alias FiberId = Typedef!(size_t, size_t.init, "FiberId");

    /++
     Socket service fiber
     +/
    class SocketFiber : Fiber, FiberRelay {
        protected {
            Socket client;
            bool _lock;
            FiberRelay.Time start_timestamp; //   uint fiber_id;
            uint _id;
        }
        immutable FiberId fiber_id;
        @property final uint id() const pure nothrow {
            return _id;
        }

        @property final void id(const uint _id) pure nothrow {
            this._id = _id;
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
        this(const size_t fiber_id) {
            this.fiber_id = fiber_id;
            super(&run);
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

        void remove() {
            handler.remove(id);
        }
        /++
         Returns:
         the service response
         +/
        Buffer response() {
            return handler.get(id);
        }

        /++
         Returns:
         true if the service has responded
         +/
        bool available() const {
            return handler.available(id);
        }
        /++
         Receives the buffer from the service socket
         Returns:
         received buffer
         +/
        @trusted
        Buffer receive() {
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
                    check(leb128_index < LEN_MAX,
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
                    checkTimeout;
                }
                else {
                    current = current[rec_data_size .. $];
                }
                yield;
            }
            immutable result = buffer.idup;
            const doc = Document(result);
            check(doc.isInorder, "Bad document format");
            id = HiRPC.getId(doc);
            return result;
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
            startTime; //client = listener.accept;
            scope (exit) {
                //_client.shutdown(SocketShutdown.BOTH);
                shutdown;
                unlock;
            }

            check(client.isAlive, "Client is dear inside server fiber");
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
