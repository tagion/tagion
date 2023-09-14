module tagion.gossip.P2pGossipNet;

import std.stdio;
import std.concurrency : Tid, thisTid;
import std.format;
import std.array : join;
import std.conv : to;
import std.file;
import std.file : fwrite = write;
import std.typecons;

import tagion.actor.exceptions : fatal;
import tagion.options.HostOptions;
import tagion.prior_services.DARTOptions;

import tagion.basic.Types : Buffer, isBufferType, Control;

import tagion.basic.basic : EnumText, buf_idup, basename, assumeTrusted;
import tagion.crypto.Types : Pubkey;

import tagion.utils.Miscellaneous : cutHex;

import tagion.utils.LRU;
import tagion.utils.Queue;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : HiBONRecord, recordType, fread, fwrite, isSpecialKeyType;
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

import concurrency = std.concurrency;

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

    log.push(LogLevel.NONE);

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
    protected ulong[Pubkey] lookup;

    void removeConnection(ulong connectionId) {
        foreach (key, val; lookup) {
            if (val == connectionId) {
                lookup.remove(key);
            }
        }
    }

    ulong opIndex(const(Pubkey) channel) const pure {
        return lookup.get(channel, 0);
    }

    void opIndexAssign(const ulong i, const(Pubkey) channel) pure nothrow {
        lookup[channel] = i;
    }

    void remove(const(Pubkey) channel) {
        lookup.remove(channel);
    }

    bool contains(const(Pubkey) channel) {
        return (channel in lookup) !is null;
    }

}

@safe
private static string convert_to_net_task_name(string task_name) {
    return task_name ~ "net";
}

@safe
class StdP2pNet : P2pNet {
    Tid sender_tid;
    protected shared p2plib.NodeI node;
    static uint counter;
    protected string owner_task_name;
    protected string internal_task_name;
    protected bool listening;
    protected string discovery_task_name;
    protected const(HostOptions) host;
    this(
            string owner_task_name,
            string discovery_task_name,
            const(HostOptions) host,
            shared p2plib.NodeI node) {
        this.owner_task_name = owner_task_name;
        this.discovery_task_name = discovery_task_name;
        this.host = host;
        this.internal_task_name = convert_to_net_task_name(owner_task_name);
        log.trace("owner_task_name %s internal_task_name %s", owner_task_name, internal_task_name);
        this.node = node;
    }

    @safe
    void start_listening() {
        @trusted
        void spawn_sender() {
            this.sender_tid = concurrency.spawn(
                    &async_send,
                    internal_task_name,
                    discovery_task_name,
                    host,
                    node);
        }

        assert(!listening);
        spawn_sender();
        listening = true;
    }

    @safe
    void close() {
        @trusted
        void send_stop() {
            if (sender_tid !is Tid.init) {
                concurrency.prioritySend(sender_tid, Control.STOP);
                concurrency.receiveOnly!Control;
            }
        }

        send_stop();
    }

    void send(const Pubkey channel, const(HiRPC.Sender) sender) {
        alias tsend = concurrency.send;
        if (sender_tid !is Tid.init) {
            counter++;
            assumeTrusted!({ tsend(sender_tid, channel, sender.toDoc, counter); });
        }
        else {
            log.warning("Sender not found");
        }
    }

    protected void send_remove(Pubkey pk) {
        alias tsend = concurrency.send;
        //auto sender = locate(internal_task_name);
        if (sender_tid !is Tid.init) {
            counter++;
            assumeTrusted!({ tsend(sender_tid, pk, counter); });
        }
        else {
            log.warning("sender not found");
        }
    }
}

@trusted
static void async_send(
        string task_name,
        string discovery_task_name,
        const(HostOptions) host,
        shared p2plib.NodeI node) nothrow {
    try {
        scope (exit) {
            assumeTrusted!({ concurrency.send(concurrency.ownerTid, Control.END); });
        }
        const hirpc = new HiRPC(null);
        //    const internal_task_name = convert_to_net_task_name(task_name);
        log.register(task_name);

        auto connectionPool = new shared ConnectionPool!(shared p2plib.StreamI, ulong)();
        auto connectionPoolBridge = new ConnectionPoolBridge();

        log("Start listening %s", task_name);
        node.listen(
                task_name,
                &StdHandlerCallback,
                task_name,
                host.timeout.msecs,
                host.max_size);

        scope (exit) {
            log("Close listener %s", task_name);
            node.closeListener(task_name);
        }

        void send_to_channel(immutable(Pubkey) channel, Document doc) {
            log.trace("Sending to channel: %s", channel.cutHex);
            auto streamId = connectionPoolBridge[channel];
            if (streamId == 0 || !connectionPool.contains(streamId)) {
                NodeAddress node_address = addressbook[channel];
                auto stream = node.connect(
                        node_address.address,
                        node_address.is_marshal,
                        [task_name]);
                streamId = stream.identifier;
                import p2p.callback;

                connectionPool.add(streamId, stream, true);
                stream.listen(
                        &StdHandlerCallback,
                        task_name,
                        host.timeout.msecs,
                        host
                        .max_size);
                connectionPoolBridge[channel] = streamId;
            }

            try {
                auto is_sent = connectionPool.send(streamId, doc.serialize);
                if (!is_sent) {
                    log.warning("Sending to %d failed", streamId);
                }
            }
            catch (Exception e) {
                log.fatal(e.msg);
                concurrency.send(concurrency.ownerTid, channel);
            }
        }

        auto stop = false;
        do {
            concurrency.receive(
                    (const(Pubkey) channel, const(Document) doc, uint id) {
                try {
                    send_to_channel(channel, doc);
                }
                catch (Exception e) {
                    log.warning("Error on sending to channel: %s", e);
                }
            },
                    (Pubkey channel, uint id) {
                try {
                    const streamId = connectionPoolBridge[channel];
                    if (streamId !is 0) {
                        connectionPool.close(streamId);
                        connectionPoolBridge.remove(channel);
                    }
                }
                catch (Exception e) {
                    log.warning("Exception caught: %s", e);
                }
            },

                    (Response!(p2plib.ControlCode.Control_Connected) resp) {
                log("Client Connected key: %d", resp.key);
                connectionPool.add(resp.key, resp.stream, true);
            },
                    (Response!(p2plib.ControlCode.Control_Disconnected) resp) {
                synchronized (connectionPoolBridge) {
                    connectionPool.close(cast(void*) resp.key);
                    connectionPoolBridge.removeConnection(resp.key);
                }
            },
                    (Response!(p2plib.ControlCode.Control_RequestHandled) resp) {
                import tagion.hibon.Document;

                auto doc = Document(resp.data);
                const receiver = hirpc.receive(doc);
                Pubkey received_pubkey = receiver.pubkey;
                const streamId = connectionPoolBridge[received_pubkey];
                if (!streamId) {
                    connectionPoolBridge[received_pubkey] = resp.stream.identifier;
                }
                concurrency.send(concurrency.ownerTid, receiver.toDoc);
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
    catch (Exception e) {
        fatal(e);
    }
}

@safe
class P2pGossipNet : StdP2pNet, GossipNet {
    protected {
        sdt_t _current_time;
        //bool[Pubkey] pks;
    }
    immutable(Pubkey) mypk;
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
        return addressbook.isActive(channel);
    }

    const(Pubkey) select_channel(const(ChannelFilter) channel_filter) {
        import std.range : dropExactly;

        const active_nodes = addressbook.numOfActiveNodes;
        log.trace("active_nodes=%d", active_nodes);
        foreach (count; 0 .. active_nodes * 2) {
            const node_index = uniform(0, active_nodes, random);
            const send_channel = addressbook.selectActiveChannel(node_index);
            if ((send_channel != mypk) && channel_filter(send_channel)) {
                return send_channel;
            }
        }
        return Pubkey();
    }

    const(Pubkey) gossip(
            const(ChannelFilter) channel_filter,
            const(SenderCallBack) sender) {
        const send_channel = select_channel(channel_filter);
        log.trace("send_channel %s", send_channel.cutHex);
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
