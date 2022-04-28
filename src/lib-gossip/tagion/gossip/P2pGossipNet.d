module tagion.gossip.P2pGossipNet;

import std.stdio;
import std.concurrency : Tid, thisTid;
import std.format;
import std.array : join;
import std.conv : to;
import std.file;
import std.file : fwrite = write;
import std.typecons;

import tagion.options.HostOptions;
import tagion.dart.DARTOptions;

import tagion.basic.Basic : EnumText, Buffer, Pubkey, buf_idup, basename, isBufferType, Control, assumeTrusted;

import tagion.utils.Miscellaneous : cutHex;

import tagion.utils.LRU;
import tagion.utils.Queue;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : HiBONRecord, RecordType;
import tagion.hibon.Document : Document;
import tagion.gossip.InterfaceNet;
import tagion.gossip.AddressBook : NodeAddress, addressbook;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraphBasic : convertState, ExchangeState;
import tagion.basic.ConsensusExceptions;

import tagion.logger.Logger;
import tagion.crypto.secp256k1.NativeSecp256k1;

import p2p.callback;
import p2plib = p2p.interfaces;

import std.array;
import tagion.utils.StdTime;

import tagion.dart.DART;
import tagion.communication.HiRPC;
import std.random : Random, unpredictableSeed, uniform;

import std.datetime;

private {
    import concurrency = std.concurrency;

    alias ownerTid = assumeTrusted!(concurrency.ownerTid);
    alias locate = assumeTrusted!(concurrency.locate);

    Tid spawn(Args...)(Args args) @trusted {
        return concurrency.spawn(args);
    }

    void send(Args...)(Args args) @trusted {
        concurrency.send(args);
    }

    void prioritySend(Args...)(Args args) @trusted {
        concurrency.prioritySend(args);
    }

    void receive(Args...)(Args args) @trusted {
        concurrency.receive(args);
    }

    T receiveOnly(T)() @trusted {
        return concurrency.receiveOnly!T;
    }
}

@safe
synchronized
class ConnectionPool(T : shared(p2plib.StreamI), TKey) {
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
            connection.close();
        }
    }

    protected ActiveConnection[TKey] shared_connections;
    protected immutable Duration timeout;

    this(const Duration timeout = Duration.zero) {
        this.timeout = cast(immutable) timeout;
    }

    void add(
            const TKey key,
            shared T connection,
            const bool long_lived = false)
    in {
        assert(connection.alive);
    }
    do {
        if (!contains(key)) {
            auto activeConnection = new shared ActiveConnection(connection, long_lived);
            shared_connections[key] = activeConnection;
        }
    }

    void close(const TKey key) {
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
            return true;
        }
        else {
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
                    close(key);
                }
            }
        }
    }
}

@safe
unittest {
    import tagion.logger.Logger;

    log.push(LoggerType.NONE);

    import p2p.node : Stream;

    @safe
    synchronized
    class FakeStream : Stream {
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

    Buffer one_byte = [0];
    { //ConnectionPool: send to exist connection
        auto connectionPool = new shared(ConnectionPool!(shared FakeStream, uint))(10.seconds);
        auto fakeStream = new shared(FakeStream)();

        connectionPool.add(0, fakeStream);

        auto result = connectionPool.send(0, one_byte);
        assert(result);
        assert(fakeStream.writeBytesCalled);
    }
    { //ConnectionPool: send to non-exist connection
        auto connectionPool = new shared(ConnectionPool!(shared FakeStream, uint))(10.seconds);
        auto fakeStream = new shared(FakeStream)();

        connectionPool.add(0, fakeStream);

        auto result = connectionPool.send(1, one_byte);
        assert(!result);
        assert(!fakeStream.writeBytesCalled);
    }
}

@safe
class ConnectionPoolBridge {
    ulong[Pubkey] lookup;

    void removeConnection(ulong connectionId) {
        log("CPB::REMOVING CONNECTION \n lookup: %s", lookup);
        foreach (key, val; lookup) {
            if (val == connectionId) {
                log("CPB::REMOVING KEY: connection id: %s as pk: %s", val, key.cutHex);
                lookup.remove(key);
                // break;
            }
        }
    }

    bool contains(Pubkey pk) {
        return (pk in lookup) !is null;
    }

}

alias ActiveNodeAddressBook = immutable(AddressBook!Pubkey);

@safe
immutable class AddressBook(TKey) {
    this(const(NodeAddress[TKey]) addrs) @trusted {
        this.data = cast(immutable) addrs.dup;
    }

    immutable(NodeAddress[TKey]) data;
}


@safe
private static string convert_to_net_task_name(string task_name) {
    return task_name ~ "net";
}

@safe
class StdP2pNet : P2pNet {
    shared p2plib.NodeI node;
    Tid sender_tid;
    static uint counter;
    protected string owner_task_name;
    protected string internal_task_name;

    this(
            string owner_task_name,
            string discovery_task_name,
            const(HostOptions) host,
            shared p2plib.NodeI node) {
        this.owner_task_name = owner_task_name;
        this.internal_task_name = convert_to_net_task_name(owner_task_name);
        this.node = node;
        void spawn_sender() {
            this.sender_tid = spawn(&async_send, owner_task_name, discovery_task_name, host, node);
        }

        spawn_sender();
    }

    @safe
    void close() {
        void send_stop() {
            auto sender = locate(internal_task_name);
            if (sender !is Tid.init) {
                sender.prioritySend(Control.STOP);
                receiveOnly!Control;
            }
        }

        send_stop();
    }

    void send(const Pubkey channel, const(HiRPC.Sender) sender) {
        alias tsend = .send;
        auto internal_sender = locate(internal_task_name);
        log("send called");
        if (internal_sender !is Tid.init) {
            counter++;
            log("sending to sender %s", internal_sender);
            auto t = sender.toDoc;
            tsend(internal_sender, channel, sender.toDoc, counter);
        }
        else {
            log("sender not found");
        }
    }

    protected void send_remove(Pubkey pk) {
        alias tsend = .send;
        auto sender = locate(internal_task_name);
        if (sender !is Tid.init) {
            counter++;
            tsend(sender, pk, counter);
        }
        else {
            log("sender not found");
        }
    }
}

@safe
static void async_send(
        string task_name,
        string discovery_task_name,
        const(HostOptions) host,
        shared p2plib.NodeI node) {
    scope (exit) {
        ownerTid.send(Control.END);
    }
    const hirpc = new HiRPC(null);
    const internal_task_name = convert_to_net_task_name(task_name);
    log.register(internal_task_name);

    auto connectionPool = new shared ConnectionPool!(shared p2plib.StreamI, ulong)();
    auto connectionPoolBridge = new ConnectionPoolBridge();

    log("start listening");
    node.listen(internal_task_name, &StdHandlerCallback,
            internal_task_name, host.timeout.msecs, host.max_size);

    scope (exit) {
        log("close listener");
        node.closeListener(internal_task_name);
    }

    void send_to_channel(immutable(Pubkey) channel, Document doc) {

        log("sending to: %s TIME: %s", channel.cutHex, Clock.currTime().toUTC());
        auto streamIdPtr = channel in connectionPoolBridge.lookup;
        auto streamId = streamIdPtr is null ? 0 : *streamIdPtr;
        if (streamId == 0 || !connectionPool.contains(streamId)) {
            auto discovery_tid = locate(discovery_task_name);
            if (discovery_tid != Tid.init) {
                discovery_tid.send(channel, thisTid);
                receive(
                        (NodeAddress node_address) {
                    auto stream = node.connect(node_address.address, node_address.is_marshal, [internal_task_name]);
                    streamId = stream.identifier;
                    import p2p.callback;

                    connectionPool.add(streamId, stream, true);
                    stream.listen(&StdHandlerCallback, internal_task_name, host.timeout.msecs, host
                        .max_size);
                    connectionPoolBridge.lookup[channel] = streamId;
                }
                );
            }
            else {
                log("Can't send: Discovery service is not running");
            }
        }

        try {
            log("send to:%d", streamId);
            auto sended = connectionPool.send(streamId, doc.serialize);
            if (!sended) {
                log("\n\n\n not sended \n\n\n");
            }
        }
        catch (Exception e) {
            log.fatal(e.msg);
            ownerTid.send(channel);
        }
    }

    auto stop = false;
    do {
        log("handling %s", thisTid);
        receive(
                (const(Pubkey) channel, const(Document) doc, uint id) {
            log("received sender %d", id);
            try {
                send_to_channel(channel, doc);
            }
            catch (Exception e) {
                log("Error on sending to channel: %s", e.msg);
                ownerTid.send(channel);
            }
        },
                (Pubkey channel, uint id) {
            log("Closing connection: %s", channel.cutHex);
            try {
                auto streamIdPtr = channel in connectionPoolBridge.lookup;
                if (streamIdPtr !is null) {
                    const streamId = *streamIdPtr;
                    log("connection to close: %d", streamId);
                    connectionPool.close(streamId);
                    connectionPoolBridge.lookup.remove(channel);
                }
            }
            catch (Exception e) {
                log("SDERROR: %s", e.msg);
            }
        },

                (Response!(p2plib.ControlCode.Control_Connected) resp) {
            log("Client Connected key: %d", resp.key);
            connectionPool.add(resp.key, resp.stream, true);
        }, (Response!(p2plib.ControlCode.Control_Disconnected) resp) {
            synchronized (connectionPoolBridge) {
                log("Client Disconnected key: %d", resp.key);
                connectionPool.close(cast(void*) resp.key);
                connectionPoolBridge.removeConnection(resp.key);
            }
        },
                (Response!(p2plib.ControlCode.Control_RequestHandled) resp) {
            import tagion.hibon.Document;

            auto doc = Document(resp.data);
            const receiver = hirpc.receive(doc);
            Pubkey received_pubkey = receiver.pubkey;
            if ((received_pubkey in connectionPoolBridge.lookup) !is null) {
                log("previous cpb: %d, now: %d",
                    connectionPoolBridge.lookup[received_pubkey], resp.stream.identifier);
            }
            else {
                connectionPoolBridge.lookup[received_pubkey] = resp.stream.identifier;
            }
            log("received in: %s", resp.stream.identifier);
            ownerTid.send(receiver.toDoc);
        },
                (Control control) {
            if (control == Control.STOP) {
                stop = true;
            }
        }
        );
    }
    while (!stop);
}

@safe
class P2pGossipNet : StdP2pNet, GossipNet {
    protected {
        sdt_t _current_time;
        //bool[Pubkey] pks;
        Pubkey mypk;
    }
    Random random;

    this(Pubkey pk,
            string owner_task_name,
            string discovery_task_name,
            const(HostOptions) host,
            shared p2plib.NodeI node) {
        super(owner_task_name, discovery_task_name, host, node);
        this.random = Random(unpredictableSeed);
        this.mypk = pk;
    }

    @property
    void time(const(sdt_t) t) {
        _current_time = sdt_t(t);
    }

    @property
    const(sdt_t) time() pure const {
        return _current_time;
    }

    bool isValidChannel(const(Pubkey) channel) const nothrow {
        return channel != mypk && addressbook.isActive(channel);
    }

    const(Pubkey) select_channel(ChannelFilter channel_filter) {
        import std.range : dropExactly;
        const active_nodes=addressbook.numOfActiveNodes;
        foreach (count; 0 .. active_nodes * 2) {
            const node_index = uniform(0, active_nodes, random);
            log("selected index: %d %d", node_index, active_nodes);
            const send_channel = addressbook.selectActiveChannel(node_index);
            // log("trying to select: %s, valid?: %s", send_channel.cutHex, channel_filter(
            //         send_channel));
            if (channel_filter(send_channel)) {
                return send_channel;
            }
        }
        return Pubkey();
    }

    const(Pubkey) gossip(
            ChannelFilter channel_filter, SenderCallBack sender) {
        const send_channel = select_channel(channel_filter);
        if (send_channel.length) {
            send(send_channel, sender());
        }
        return send_channel;
    }

    void add_channel(const Pubkey channel) {
        assert(0, "addressbook should be used instead");
//        pks[channel] = true;
    }

    void remove_channel(const Pubkey channel) {
        assert(0, "addressbook should be used instead");
        //      pks.remove(channel);
    }
}
