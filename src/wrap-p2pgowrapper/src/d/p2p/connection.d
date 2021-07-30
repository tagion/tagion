module p2p.connection;

import lib = p2p.lib.libp2p;
import p2p.node;
import core.time;
import std.datetime;
import std.stdio;

synchronized class ConnectionPool(T : shared(Stream), TKey) {
    private shared final class ActiveConnection {
        protected T connection; //TODO: try immutable/const
        protected SysTime last_timestamp;

        protected const bool update_timestamp;

        /*
            update_timestamp - for long-live connection
        */
        this(ref shared T value, const bool update_timestamp = false) {
            connection = value;
            this.update_timestamp = update_timestamp;
            this.last_timestamp = Clock.currTime();
        }

        bool isExpired(const Duration dur) {
            return (Clock.currTime - last_timestamp) > dur;
        }

        void send(Buffer data) {
            if (update_timestamp) {
                cast() this.last_timestamp = Clock.currTime();
            }
            connection.writeBytes(data);
        }

        void close() {
            writeln("CLOSING EXPIRED STREAM");
            connection.close();
            // destroy(connection);
        }
    }

    protected ActiveConnection[TKey] shared_connections;
    protected immutable Duration timeout;

    this(const Duration timeout = Duration.zero) {
        this.timeout = cast(immutable) timeout;
    }

    void add(const TKey key, shared T connection, const bool long_lived = false)
    in {
        assert(connection.alive);
    }
    do {
        if (!contains(key)) {
            auto activeConnection = new shared ActiveConnection(connection, long_lived);
            shared_connections[key] = activeConnection;
        }
        else {
            writeln("ignore key: ", key);
        }
    }

    void close(const TKey key) {
        writeln("CONNECTION!! Close stream: key: ", key);
        auto connection = get(key);
        if (connection) {
            shared_connections.remove(key);
            connection.close();
        }
    }

    void closeAll()
    out {
        assert(empty);
    }
    do {
        foreach (key, connection; shared_connections) {
            shared_connections.remove(key);
            connection.close();
        }
    }

    ulong size() {
        return shared_connections.length;
    }

    bool empty() {
        return size == 0;
    }

    bool contains(const TKey key) {
        return get(key) !is null;
    }

    protected shared(ActiveConnection)* get(const TKey key) {
        auto valuePtr = (key in shared_connections);
        return valuePtr;
    }

    bool send(const TKey key, Buffer data)
    in {
        assert(data.length != 0);
    }
    do {
        auto connection = this.get(key);
        if (connection !is null) {
            (*connection).send(data);
            writeln("LIBP2P: SENDED");
            return true;
        }
        else {
            writeln("LIBP2P: Connection not found");
            return false;
        }
    }

    void broadcast(Buffer data)
    in {
        assert(data.length != 0);
    }
    do {
        foreach (connection; shared_connections) {
            connection.send(data);
        }
    }

    void tick() {
        if (timeout != Duration.zero) {
            foreach (key, connection; shared_connections) {
                if (connection.isExpired(timeout)) {
                    // writeln("STREAM EXPIRED");
                    close(key);
                }
            }
        }
    }
}
// version(none)
unittest {
    @trusted synchronized class FakeStream : Stream {
        protected bool _writeBytesCalled = false;
        @property bool writeBytesCalled() {
            return _writeBytesCalled;
        }

        this() {
            super(null, 0);
        }

        override void writeBytes(Buffer data) {
            _writeBytesCalled = true;
        }
    }

    { //ConnectionPool: send to exist connection
        auto connectionPool = new shared(ConnectionPool!(shared FakeStream, uint))(10.seconds);
        auto fakeStream = new shared(FakeStream)();

        connectionPool.add(0, fakeStream);

        auto result = connectionPool.send(0, cast(Buffer)[0]);
        assert(result);
        assert(fakeStream.writeBytesCalled);
    }
    { //ConnectionPool: send to non-exist connection
        auto connectionPool = new shared(ConnectionPool!(shared FakeStream, uint))(10.seconds);
        auto fakeStream = new shared(FakeStream)();

        connectionPool.add(0, fakeStream);

        auto result = connectionPool.send(1, cast(Buffer)[0]);
        assert(!result);
        assert(!fakeStream.writeBytesCalled);
    }
}
