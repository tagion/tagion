module tagion.communication.HandlerPool;

import core.time;
import std.datetime;
import std.stdio;
import tagion.basic.Types : Buffer;

@safe
interface ResponseHandler {
    void setResponse(Buffer response);
    bool alive();
    void close();

    @safe
    struct Response(TKey) {
        immutable(TKey) key;
        Buffer data;
        this(const TKey key, Buffer data) inout {
            import std.traits : isArray, isBasicType;

            static if (isBasicType!TKey) {
                this.key = key;
            }
            else if (isArray!TKey) {
                static if (is(ForeachType!Tkey == immutable)) {
                    this.key = key;
                }
                else {
                    this.key = key.idup;
                }
            }
            else if (is(key == immutable)) {
                this.key = key;
            }
            else {
                static assert(0, "TKey " ~ TKey.stringof ~ " not supported");
            }
            this.data = data;
        }
    }
}

@safe
interface HandlerPool(TValue : ResponseHandler, TKey) {
    protected final class ActiveHandler {
        protected TValue handler; //TODO: try immutable/const
        protected SysTime last_timestamp;

        protected const bool update_timestamp;

        /*
            update_timestamp - for long-live connection
        */
        this(TValue value, const bool update_timestamp = false) {
            handler = value;
            this.update_timestamp = update_timestamp;
            this.last_timestamp = Clock.currTime();
        }

        void setResponse(Buffer response) {
            if (update_timestamp) {
                this.last_timestamp = Clock.currTime();
            }
            handler.setResponse(response);
        }

        bool isExpired(const Duration dur) {
            return (Clock.currTime - last_timestamp) > dur;
        }
    }

    ActiveHandler* get(const TKey key);
    bool contains(const TKey key);
    void add(const TKey key, ref TValue value, bool long_lived = false);
    void remove(const TKey key);
    ulong size();
    bool empty();
    void setResponse(immutable ResponseHandler.Response!TKey resp);
    void tick();
}

@safe
class StdHandlerPool(TValue : ResponseHandler, TKey) : HandlerPool!(TValue, TKey) {
    protected ActiveHandler[TKey] handlers; //TODO: should be threadsafe?
    protected immutable Duration timeout;

    this(const Duration timeout = Duration.zero) {
        this.timeout = cast(immutable) timeout;
    }

    ActiveHandler* get(const TKey key) {
        auto valuePtr = (key in handlers);
        // if(valuePtr is null) return null;
        return valuePtr;
    }

    bool contains(const TKey key) {
        return get(key) !is null;
    }

    void add(const TKey key, ref TValue value, bool long_lived = false)
    in {
        assert(!contains(key)); //TODO: special case
    }
    do {
        auto active_handler = new ActiveHandler(value, long_lived);
        handlers[key] = active_handler;
    }

    void remove(const TKey key)
    out {
        assert(!contains(key));
    }
    do {
        auto value_ptr = get(key);
        if (value_ptr !is null) {
            handlers.remove(key);
            (*value_ptr).handler.close();
        }
    }

    ulong size() {
        return handlers.length;
    }

    bool empty() {
        return size == 0;
    }

    void setResponse(immutable ResponseHandler.Response!TKey resp) { //TODO: scope(exit) destroy(resp.stream); ?
        // writeln("set response: ", resp.key);
        auto active_connection_ptr = get(resp.key);
        if (active_connection_ptr !is null) {
            auto active_connection = *active_connection_ptr;
            active_connection.setResponse(resp.data);
            if (!active_connection.handler.alive) {
                remove(resp.key);
            }
        }
        else {
            writeln("no respponse handler found");
        }
        tick;
    }

    void tick() {
        if (timeout != Duration.zero) {
            foreach (key, activeHandler; handlers) {
                if (activeHandler.isExpired(timeout) || !activeHandler.handler.alive()) {
                    // if(activeHandler.isExpired(timeout)) writeln("EXPIRED HANDLER");
                    // else writeln("HANDLER NOT ALIVE");
                    remove(key);
                }
            }
        }
    }
}

@safe
unittest {
    import core.thread;

    @safe
    class FakeResponseHandler : ResponseHandler {
        bool setResponseCalled = false;
        bool alived = true;
        bool closed = false;
        void setResponse(Buffer response) {
            setResponseCalled = true;
        }

        bool alive() {
            return alived;
        }

        void close() {
            closed = true;
        }
    }

    version (none) { //HandlerPool: remove handler on expired
        auto handler_pool = new StdHandlerPool!(FakeResponseHandler, uint)(10.msecs);
        auto fakeResponseHandler = new FakeResponseHandler();
        handler_pool.add(0, fakeResponseHandler);
        assert(!handler_pool.empty);
        handler_pool.tick;
        assert(!handler_pool.empty);
        Thread.sleep(1.msecs);
        handler_pool.tick;
        assert(!handler_pool.empty);
        Thread.sleep(10.msecs);
        handler_pool.tick;
        assert(handler_pool.empty);
    }

    version (none) { //HandlerPool: update timestamp on set response
        auto handler_pool = new StdHandlerPool!(FakeResponseHandler, uint)(10.msecs);
        auto fakeResponseHandler = new FakeResponseHandler();
        handler_pool.add(1, fakeResponseHandler, true);
        assert(!handler_pool.empty);
        handler_pool.tick;
        assert(!handler_pool.empty);
        Thread.sleep(7.msecs);
        handler_pool.tick;
        assert(!handler_pool.empty);
        immutable response = ResponseHandler.Response!uint(1, cast(Buffer)[]);
        handler_pool.setResponse(response);
        assert(fakeResponseHandler.setResponseCalled);
        Thread.sleep(7.msecs);
        handler_pool.tick;
        assert(!handler_pool.empty);
        Thread.sleep(5.msecs);
        handler_pool.tick;
        assert(handler_pool.empty);
    }

    { //HandlerPool: remove handler if not alive after set response
        auto handler_pool = new StdHandlerPool!(FakeResponseHandler, uint)(10.msecs);
        auto fakeResponseHandler = new FakeResponseHandler();
        handler_pool.add(0, fakeResponseHandler);
        assert(!handler_pool.empty);

        fakeResponseHandler.alived = false;
        immutable response = immutable(ResponseHandler.Response!uint)(0, null);
        handler_pool.setResponse(response);
        assert(fakeResponseHandler.closed);
        assert(fakeResponseHandler.setResponseCalled);
        assert(handler_pool.empty);
    }
    { //HandlerPool: remove handler if not alive after tick
        auto handler_pool = new StdHandlerPool!(FakeResponseHandler, uint)(10.msecs);
        auto fakeResponseHandler = new FakeResponseHandler();
        handler_pool.add(0, fakeResponseHandler);
        assert(!handler_pool.empty);
        handler_pool.tick;
        assert(!handler_pool.empty);

        fakeResponseHandler.alived = false;
        handler_pool.tick;
        assert(fakeResponseHandler.closed);
        assert(!fakeResponseHandler.setResponseCalled);
        assert(handler_pool.empty);
    }
}
