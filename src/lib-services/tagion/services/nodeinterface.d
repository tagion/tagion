/// Interface for the Peer to Peer communicatio
/// https://docs.tagion.org/docs/architecture/NodeInterface
module tagion.services.nodeinterface;

@safe:

import core.time;
import core.atomic;

import std.format;
import std.conv;
import std.exception;
import std.algorithm;
import std.typecons;
import std.traits;

import tagion.actor;
import tagion.actor.exceptions;
import tagion.basic.Types;
import tagion.crypto.Types;
import tagion.gossip.AddressBook;
import tagion.hibon.Document;
import tagion.utils.Random;
import tagion.logger;
import tagion.services.messages;
import tagion.services.exception;
import tagion.crypto.SecureNet;
import tagion.communication.HiRPC;

import nngd;
import libnng;

///
struct NodeInterfaceOptions {
    uint send_timeout = 200; // Milliseconds
    uint recv_timeout = 200; // Milliseconds
    uint send_max_retry = 0;
    string node_address = "tcp://[::1]:10700"; // Address

    import tagion.utils.JSONCommon;

    mixin JSONCommon;
}

///
enum NodeErrorCode {
    invalid_state,
    nng_err,
    empty_msg,
}

/**
 * A Single pending outgoing connection
 * All aio tasks notify the calling thread by sending a message
 */
struct Dialer {
    /// copy/postblit disabled
    @disable this(this);

    int id;
    string address;
    nng_stream_dialer* dialer;
    nng_aio* aio;
    string owner_task;
    Pubkey pkey;

    ///
    this(int id, string address_, Pubkey pkey) @trusted {
        int rc = nng_aio_alloc(&aio, &callback, self);
        this.pkey = pkey;
        this.id = id;

        this.address = address_;
        address_ ~= '\0';

        rc = nng_stream_dialer_alloc(&dialer, &address[0]);
        check(rc == nng_errno.NNG_OK, nng_errstr(rc));
        owner_task = thisActor.task_name;
    }

    /// free nng memory
    ~this() {
        nng_aio_free(aio);
        nng_stream_dialer_free(dialer);
    }

    /// Initiate a connection to the address
    void dial() {
        nng_stream_dialer_dial(dialer, aio);
    }

    // TODO: Use nullable?
    nng_stream* get_output() @trusted {
        return cast(nng_stream*)nng_aio_get_output(aio, 0);
    }

    static callback(void* ctx) nothrow {
        This* _this = self(ctx);
        try {
            thread_attachThis();
            ActorHandle(_this.owner_task).send(NodeDial(), _this.id);
        } 
        catch(Exception e) {
            fail(_this.owner_task, e);
        }
    }

    mixin NodeHelpers;
}

/**
 * A Single active socket connection
 * All aio tasks notify the calling thread by sending a message
 */
struct Peer {
    enum State {
        ready,
        receive,
        send,
    }

    /// copy/postblit disabled
    @disable this(this);

    int id;

    // taskname is used inside the nng callback to know which thread to notify
    string owner_task;
    string address;
    shared State state = State.ready;

    nng_stream* socket;
    nng_aio* aio;
    nng_iov sendiov;
    ubyte[] sendbuf;

    enum bufsize = 256;

    ///
    this(int id, nng_stream* socket) @trusted {
        this.id = id;
        int rc = nng_aio_alloc(&aio, &callback, self);
        check(rc == nng_errno.NNG_OK, nng_errstr(rc));
        owner_task = thisActor.task_name;
        this.socket = socket;
        sendbuf = new ubyte[](bufsize);
        sendiov.iov_len = bufsize;
        sendiov.iov_buf = &sendbuf[0];

        rc = nng_aio_set_iov(aio, 1, &sendiov);
        check(rc == 0, nng_errstr(rc));
    }

    /// free nng memory
    ~this() {
        nng_aio_free(aio);
        nng_stream_free(socket);
    }

    // FIXME: sending and receive of partial buffers
    static void callback(void* ctx) @trusted nothrow {
        This* _this = self(ctx);
        try {
            thread_attachThis();

            int rc = nng_aio_result(_this.aio);
            if(rc != nng_errno.NNG_OK) {
                node_error(_this.owner_task, NodeErrorCode.nng_err, _this.id, nng_errstr(rc));
                return;
            }

            switch(_this.state) {
                case state.receive:
                    size_t msg_size = nng_aio_count(_this.aio);
                    if(msg_size <= 0) {
                        node_error(_this.owner_task, NodeErrorCode.empty_msg, _this.id);
                    }
                    Buffer buf = _this.sendbuf[0..msg_size].idup;
                    check(buf !is null, "Got invalid buf output");

                    _this.state.atomicStore(State.ready);
                    ActorHandle(_this.owner_task).send(NodeRecv(), _this.id, buf);
                    break;
                default:
                    _this.state.atomicStore(State.ready);
                    ActorHandle(_this.owner_task).send(NodeSendDone(), _this.id);
                    break;
            }
        } catch(Exception e) {
            fail(_this.owner_task, e);
        }
    }

    /// Send a buffer to the peer
    void send(const(ubyte)[] data) @trusted {
        assert(socket !is null, "This peer is not connected");
        check(state is State.ready, "Can not call send when not ready");
        state = State.send;
        sendbuf[0..data.length] = data[0..data.length];
        sendiov.iov_len = data.length;

        int rc = nng_aio_set_iov(aio, 1, &sendiov);
        check(rc == 0, nng_errstr(rc));
        nng_stream_send(socket, aio);
    }

    /// Receive a buffer from the peer
    void recv() {
        assert(socket !is null, "This peer is not connected");
        /* check(state = State.stale); */
        state = State.receive;
        nng_stream_recv(socket, aio);
    }

    mixin NodeHelpers;
}

/**
 * Establishes new connections either by dial or accept
 * And associates active connections with a public key
 * Most operations are asynchronous and when completed will send a message to the calling thread.
 */
struct PeerMgr {

    /// copy/postblit disabled
    @disable this(this);

    ///
    this(const(SecureNet) net, string address) @trusted {
        this.net = net;
        this.hirpc = HiRPC(net);
        int rc = nng_aio_alloc(&aio_conn, &callback, self);
        check!ServiceError(rc == 0, nng_errstr(rc));
        this.task_name = thisActor.task_name;

        this.address = address;
        address ~= '\0';
        assert(this.address.length < address.length);
        rc = cast(nng_errno)nng_stream_listener_alloc(&listener, &address[0]);
        check!ServiceError(rc == nng_errno.NNG_OK, nng_errstr(rc));
    }

    /// free nng memory
    ~this() {
        nng_aio_free(aio_conn);
        nng_stream_listener_free(listener);
    }

    nng_stream_listener* listener;

    const SecureNet net;
    const HiRPC hirpc;
    string address;

    Dialer*[int] dialers;

    // All the peers who we know the public key off
    Peer*[Pubkey] peers;

    // We store all peers with an id
    // Since we don't know their public key if we are receing from them for the first time
    Peer*[int] all_peers;

    nng_aio* aio_conn;

    // This task name is used inside the nng callback to know which thread to notify
    string task_name;

    // This thread callback is used to notify the NodeInterface thread of incoming connections
    static void callback(void* ctx) nothrow {
        This* _this = self(ctx);
        try {
            thread_attachThis(); // Attach the current thread to the gc
            int rc = nng_aio_result(_this.aio_conn);

            int id = generateId!int;

            if(rc == nng_errno.NNG_OK) {
                ActorHandle(_this.task_name).send(NodeAccept(), id);
            }
            else {
                node_error(_this.task_name, NodeErrorCode.nng_err, id);
            }
        }
        catch(Exception e) {
            fail(_this.task_name, e);
        }
    }

    /**
     * Listen on the specified address. 
     * This should be called before doing anything else.
     * Finishes immediately
    */
    void listen() {
        int rc = nng_stream_listener_listen(listener);
        check(rc == nng_errno.NNG_OK, nng_errstr(rc));
    }

    // Accept incoming connections
    void accept() {
        nng_stream_listener_accept(listener, aio_conn);
    }

    /// Connect to an address an associate it with a public key
    void dial(string address, Pubkey pkey) {
        int id = generateId!int;
        auto dialer = new Dialer(id, address, pkey);
        dialer.dial();
        dialers[id] = dialer;
    }

    /// Receive messages from all the peers that are not doing anything else
    void recv_all_ready() {
        foreach(peer; all_peers) {
            if(peer.state !is Peer.State.ready) {
                continue;
            }

            peer.recv();
        }
    }

    /// Send to an active connection with a known public key
    void send(Pubkey pkey, immutable(ubyte)[] buf) {
        assert(isActive(pkey), "No established connection");
        peers[pkey].send(buf);
    }

    /// Check if an active known connection exists with this public key
    bool isActive(const(Pubkey) channel) const pure nothrow {
        return ((channel in peers) !is null);
    }

    // --- Message handlers --- //

    // TODO: use envelope
    void on_recv(NodeRecv, int id, Buffer buf) {

        assert(buf.length > 1);

        Document doc = buf;
        /* imported!"std.stdio".writefln("received %s bytes %s", buf.length, doc.topretty); */

        if(!doc.isInorder && !doc.empty) {
            // error
            return;
        }

        const hirpcmsg = hirpc.receive(doc);
        if(hirpcmsg.pubkey == this.net.pubkey) {
            // "Do you really want to send a message to yourself?");
            return;
        }
        if(hirpcmsg.signed !is HiRPC.SignedState.VALID) {
            // error
            return;
        }

        // Add to the list of known connections
        peers.require(hirpcmsg.pubkey, all_peers[id]);
    }

    // A connection was established by dial
    void on_dial(NodeDial, int id) {
        assert((id in dialers) !is null, "No dialer was allocated for this id");
        auto dialer = dialers[id];
        scope(exit) {
            dialers.remove(id);
            /* destroy(dialer); */
        }

        nng_stream* socket = dialer.get_output;
        auto peer = new Peer(id, socket);

        all_peers[id] = peer;
        peers[dialer.pkey] = peer;
    }

    // A connections was established by accept
    void on_accept(NodeAccept, int id) @trusted {
        nng_stream* socket = cast(nng_stream*)nng_aio_get_output(aio_conn, 0);
        assert(socket !is null, "No connections established?");

        all_peers[id] = new Peer(id, socket);
    }

    // A send task was completed
    void on_send(NodeSendDone, int id) {
    }

    mixin NodeHelpers;
}

///
unittest {
    thisActor.task_name = "jens";

    import std.stdio;

    auto net1 = new StdSecureNet();
    net1.generateKeyPair("me1");

    auto net2 = new StdSecureNet();
    net2.generateKeyPair("me2");

    auto dialer = PeerMgr(net1, "abstract://whomisam" ~ generateId.to!string);
    auto listener = PeerMgr(net2, "abstract://whomisam" ~ generateId.to!string);

    dialer.listen();
    listener.listen();

    dialer.dial(listener.address, net2.pubkey);
    listener.accept();

    /* writefln("Connected dialer: %s, listener: %s", dialer.all_peers.length, listener.all_peers.length); */
    receiveOnlyTimeout(2.seconds, &dialer.on_dial, &listener.on_accept);
    receiveOnlyTimeout(2.seconds, &dialer.on_dial, &listener.on_accept);
    /* writefln("Connected dialer: %s, listener: %s", dialer.all_peers.length, listener.all_peers.length); */

    assert(dialer.isActive(listener.net.pubkey));
    assert(!listener.isActive(dialer.net.pubkey));

    assert(dialer.all_peers.length == 1);
    assert(listener.all_peers.length == 1);
    assert(dialer.all_peers.byValue.all!(p => p.state is Peer.State.ready));
    assert(listener.all_peers.byValue.all!(p => p.state is Peer.State.ready));

    {
        listener.recv_all_ready();
        Buffer send_payload_p1 = HiRPC(net1).action("manythanks").serialize;

        dialer.send(net2.pubkey, send_payload_p1);

        receiveOnlyTimeout(1.seconds, &dialer.on_send, &listener.on_recv);
        receiveOnlyTimeout(1.seconds, &dialer.on_send, &listener.on_recv);

        assert(listener.peers.length == 1);
    }

    {
        dialer.recv_all_ready;
        Buffer send_payload_p2 = HiRPC(net2).action("manythanks").serialize;
        listener.send(net1.pubkey, send_payload_p2);

        receiveOnlyTimeout(1.seconds, &dialer.on_recv, &listener.on_send);
        receiveOnlyTimeout(1.seconds, &dialer.on_recv, &listener.on_send);
    }

    {
        listener.recv_all_ready();
        Buffer send_payload_p1 = HiRPC(net1).action("manythanks").serialize;

        dialer.send(net2.pubkey, send_payload_p1);

        receiveOnlyTimeout(1.seconds, &dialer.on_send, &listener.on_recv);
        receiveOnlyTimeout(1.seconds, &dialer.on_send, &listener.on_recv);

        assert(listener.peers.length == 1);
    }
}

///
struct NodeInterfaceService_ {
    NodeInterfaceOptions opts;
    const(SecureNet) net;
    const(HiRPC) hirpc;
    ActorHandle receive_handle;

    PeerMgr p2p;

    ///
    this(immutable(NodeInterfaceOptions) opts, shared(StdSecureNet) shared_net, string message_handler_task) {
        this.opts = opts;
        this.net = new StdSecureNet(shared_net);
        this.hirpc = HiRPC(this.net);
        this.receive_handle = ActorHandle(message_handler_task);
        this.p2p = PeerMgr(this.net, opts.node_address);
    }

    // Messages which are waiting for dial connection
    // TODO: use LRU?
    Document[Pubkey] msg_queue;

    void node_send(NodeSend, Pubkey channel, Document payload) {
        debug(nodeinterface) log("%s %s", __FUNCTION__, HiRPC(null).receive(payload).method.name);
        p2p.isActive(channel);
        if (p2p.isActive(channel)) {
            // TODO: check if this peer is already doing something
            p2p.send(channel, payload.serialize);
        }
        else {
            msg_queue[channel] = payload;
            const nnr = addressbook[channel].get;
            p2p.dial(nnr.address, channel);
        }
    }

    void on_dial(NodeDial m, int id) {
        debug(nodeinterface) log(__FUNCTION__);
        Pubkey channel = p2p.dialers[id].pkey;

        Document payload = msg_queue[channel];
        scope(exit) {
            msg_queue.remove(channel);
        }

        // Update state of connections
        p2p.on_dial(m, id);
        p2p.send(channel, payload.serialize);
    }

    void on_accept(NodeAccept m, int id) {
        debug(nodeinterface) log(__FUNCTION__);
        p2p.on_accept(m, id);
        p2p.all_peers[id].recv();
        p2p.accept(); // Accept a new request
    }

    void on_recv(NodeRecv, int id, Buffer buf) {
        debug(nodeinterface) log(__FUNCTION__);

        debug(nodeinterface) log("received %s bytes", buf.length);

        assert(buf.length >= 1);

        const(Document) doc = buf;

        if(!doc.isInorder && !doc.empty) {
            // error
            return;
        }

        const hirpcmsg = hirpc.receive(doc);
        if(hirpcmsg.pubkey == this.net.pubkey) {
            // "Do you really want to send a message to yourself?");
            return;
        }
        if(hirpcmsg.signed !is HiRPC.SignedState.VALID) {
            // error
            return;
        }

        // Add to the list of known connections
        p2p.peers.require(hirpcmsg.pubkey, p2p.all_peers[id]);

        // Send to hasgraph/epoch_creator
        receive_handle.send(ReceivedWavefront(), doc);
    }

    void on_send(NodeSendDone m, int id) {
        debug(nodeinterface) log(__FUNCTION__);
        p2p.on_send(m, id);
        p2p.all_peers[id].recv; // Be ready to receive next message
    }

    void on_error(NodeError, NodeErrorCode code, int id, string msg, int _) {
        log.error("(%s)%s:%s", id, code, msg);
    }

    void task() {
        p2p.listen();
        p2p.accept();

        run(&node_send, &on_accept, &on_recv, &on_send, &on_dial, &on_error);
    }
}

///
struct NodeInterfaceService {

    Topic event_send = Topic("node_send");
    Topic event_recv = Topic("node_recv");

    immutable NodeInterfaceOptions opts;
    ActorHandle receive_handle;

    bool retry(bool delegate() send_) @trusted {
        import conc = tagion.utils.pretend_safe_concurrency;

        int attempts;
        while(attempts <= opts.send_max_retry && !thisActor.stop) {
            attempts++;
            if(send_()) {
                return true;
            }
            nng_sleep(100.msecs);
            conc.receiveTimeout(Duration.zero, &signal);
        }
        return false;
    }

    NNGSocket sock_recv;
    this(immutable(NodeInterfaceOptions) opts, string message_handler_task) @trusted {
        this.opts = opts;
        this.sock_recv = NNGSocket(nng_socket_type.NNG_SOCKET_PAIR);
        assert(sock_recv.m_errno == 0, format("Create recv sock error %s", nng_errstr(sock_recv.m_errno)));
        this.sock_recv.recvtimeout = opts.recv_timeout.msecs;
        this.sock_recv.sendtimeout = opts.send_timeout.msecs;
        this.receive_handle = ActorHandle(message_handler_task);
    }

    void node_send(NodeSend, Pubkey channel, Document payload) @trusted {
        const nnr = addressbook[channel].get;
        NNGSocket sock_send = NNGSocket(nng_socket_type.NNG_SOCKET_PAIR);
        assert(sock_send.m_errno == 0, format("Create send sock error %s", nng_errstr(sock_send.m_errno)));
        sock_send.recvtimeout = opts.recv_timeout.msecs;
        sock_send.sendtimeout = opts.send_timeout.msecs;
        int rc = sock_send.dial(nnr.address);

        scope (exit) {
            sock_send.close();
        }

        assert(rc != -1, "You did not create the socket you dummy");

        retry({
            rc = sock_send.send(payload.serialize);
            if (rc != 0) {
                log.error("attempt to send (%s)%s %s", channel.encodeBase64, nnr.address, nng_errstr(sock_send.m_errno));
                return false;
            }
            return true;
        });

        log.event(event_send, nnr.name ~ channel.encodeBase64, payload);
        log.trace("successfully sent %s bytes", payload.data.length);
    }

    void node_receive() @trusted {
        Buffer buf = sock_recv.receive!Buffer;

        if (sock_recv.m_errno != nng_errno.NNG_OK && sock_recv.m_errno != nng_errno.NNG_ETIMEDOUT) {
            throw new ServiceException(nng_errstr(sock_recv.m_errno));
        }

        if (buf.length > 0) {
            log.trace("received %s bytes", buf.length);
            const doc = Document(buf);

            receive_handle.send(ReceivedWavefront(), doc);

            log.event(event_recv, __FUNCTION__, doc);
        }
    }

    void task() @trusted {
        int rc = sock_recv.listen(opts.node_address);
        assert(rc == 0, format("%s: %s", nng_errstr(sock_recv.m_errno), opts.node_address));

        scope (exit) {
            sock_recv.close();
        }
        log("Listening on %s", opts.node_address);

        runTimeout(opts.send_timeout.msecs, &node_receive, &node_send);
    }
}


void thread_attachThis() @trusted {
    import core.thread : thread_attachThis;
    pragma(msg, "FIXME(lr): find out why thread_attachThis causes issues");
    /* thread_attachThis(); */
}
void fail(string owner_task, Throwable t) nothrow {
    try {
        immutable tf = TaskFailure(thisActor.task_name, t);
        log.event(taskfailure, "taskfailure", tf);
        ActorHandle(owner_task).prioritySend(tf);
    }
    catch(Exception e) {
        log(e);
    }
}

void node_error(string owner_task, NodeErrorCode code, int id, string msg = "", int line = __LINE__) {
    ActorHandle(owner_task).send(NodeError(), code, id, msg, line);
}

mixin template NodeHelpers() {
    alias This = typeof(this);
    private void* self () @trusted @nogc nothrow {
        return cast(void*)&this;
    }

    private static This* self(void* ctx) @trusted @nogc nothrow {
        This* _this = cast(This*)ctx;
        assert(_this !is null, "did not get this* through the ctx");
        return _this;
    }
}

version(unittest) {
    import std.variant;
    import conc = tagion.utils.pretend_safe_concurrency;

    void receiveOnlyTimeout(Args...)(Duration dur, Args handlers) {
        bool received = conc.receiveTimeout(dur, 
            handlers,
            (Variant var) @trusted {
                throw new Exception(format("Unknown msg: %s", var));
            }
        );
        assert(received, "Timed out");
    }
}
