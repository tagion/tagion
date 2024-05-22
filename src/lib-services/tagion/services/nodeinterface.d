/// Interface for the Peer to Peer communication
/// https://docs.tagion.org/docs/architecture/NodeInterface
module tagion.services.nodeinterface;

@safe:

import core.time;

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
import tagion.hashgraph.HashGraphBasic;
import tagion.script.standardnames;
import tagion.utils.Random;
import tagion.utils.Queue;
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
    size_t bufsize = 0x8000; // 32kb
    string node_address = "tcp://[::1]:10700"; // Address

    import tagion.utils.JSONCommon;

    mixin JSONCommon;
}

///
enum NodeErrorCode {
    invalid_state,
    empty_msg,
    buf_empty,
    doc_inorder,
    msg_self,
    msg_signed,
    exception,
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
        int rc;
        rc = nng_aio_alloc(&aio, &callback, self);
        check(rc == nng_errno.NNG_OK, nng_errstr(rc));

        this.pkey = pkey;
        this.id = id;
        this.address = address_;

        address_ ~= '\0';
        rc = nng_stream_dialer_alloc(&dialer, &address_[0]);
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

            nng_errno rc = cast(nng_errno)nng_aio_result(_this.aio);
            if(rc == nng_errno.NNG_OK) {
                ActorHandle(_this.owner_task).send(NodeAction.dialed, _this.id);
            }
            else {
                node_error(_this.owner_task, rc, _this.id, _this.address);
            }
        } 
        catch(Exception e) {
            fail(_this.owner_task, e);
        }
    }

    void abort() {
        nng_aio_abort(aio, int());
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
    State state;

    nng_stream* socket;
    nng_aio* aio;
    nng_iov iov;
    ubyte[] msg_buf;

    Queue!Buffer send_queue;

    size_t bufsize = 4096;

    ///
    this(int id, nng_stream* socket, size_t bufsize) @trusted {
        this.id = id;
        this.bufsize = bufsize;
        int rc = nng_aio_alloc(&aio, &callback, self);
        check(rc == nng_errno.NNG_OK, nng_errstr(rc));
        owner_task = thisActor.task_name;
        this.socket = socket;
        msg_buf = new ubyte[](bufsize);
        iov.iov_len = bufsize;
        iov.iov_buf = &msg_buf[0];

        rc = nng_aio_set_iov(aio, 1, &iov);
        check(rc == 0, nng_errstr(rc));

        this.send_queue = new Queue!Buffer;
    }

    /// free nng memory
    ~this() {
        nng_aio_free(aio);
        nng_stream_free(socket);
    }

    static void callback(void* ctx) @trusted nothrow {
        This* _this = self(ctx);
        try {
            thread_attachThis();

            nng_errno rc = cast(nng_errno)nng_aio_result(_this.aio);
            if(rc != nng_errno.NNG_OK) {
                node_error(_this.owner_task, rc, _this.id, text(_this.state));
                return;
            }

            switch(_this.state) {
                case state.receive:
                    size_t msg_size = nng_aio_count(_this.aio);
                    if(msg_size <= 0) {
                        node_error(_this.owner_task, NodeErrorCode.empty_msg, _this.id);
                        return;
                    }
                    Buffer buf = _this.msg_buf[0 .. msg_size].idup;
                    check(buf !is null, "Got invalid buf output");

                    ActorHandle(_this.owner_task).send(NodeAction.received, _this.id, buf);
                    break;
                default:
                    ActorHandle(_this.owner_task).send(NodeAction.sent, _this.id);
                    break;
            }
        }
        catch(Exception e) {
            fail(_this.owner_task, e);
        }
    }

    /// Send a buffer to the peer
    void send(const(ubyte)[] data) @trusted {
        assert(data.length <= bufsize, "sent data greater than bufsize");
        assert(socket !is null, "This peer is not connected");
        check(state is State.ready, "Can not call send when not ready");
        state = State.send;
        msg_buf[0 .. data.length] = data[0 .. $];
        iov.iov_len = data.length;

        int rc = nng_aio_set_iov(aio, 1, &iov);
        check(rc == 0, nng_errstr(rc));

        debug(nodeinterface) log("sending %s bytes", iov.iov_len);
        nng_stream_send(socket, aio);
    }

    /// Receive a buffer from the peer
    void recv() @trusted {
        assert(socket !is null, "This peer is not connected");
        check(state is State.ready, "Can not call recv when not ready");
        state = State.receive;

        iov.iov_len = bufsize;
        int rc = nng_aio_set_iov(aio, 1, &iov);
        check(rc == 0, nng_errstr(rc));

        nng_stream_recv(socket, aio);
    }

    void close() {
        nng_stream_close(socket);
    }

    void abort() {
        nng_aio_abort(aio, int());
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
    this(const(SecureNet) net, string address, size_t bufsize) @trusted {
        this.net = net;
        this.hirpc = HiRPC(net);
        this.bufsize = bufsize;
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
    size_t bufsize;

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
            nng_errno rc = cast(nng_errno)nng_aio_result(_this.aio_conn);

            int id = generateId!int;

            if(rc != nng_errno.NNG_OK) {
                node_error(_this.task_name, rc, id);
            }
            else {
                ActorHandle(_this.task_name).send(NodeAction.accepted, id);
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

    void close(int id) {
        if(isActive(id)) {
            all_peers[id].close();
            all_peers.remove(id);

            foreach(channel, peer; peers) {
                if (peer.id == id) {
                    peers.remove(channel);
                    break;
                }
            }
        }
    }

    void close(Pubkey pkey) {
        if(isActive(pkey)) {
            Peer* peer = peers[pkey];
            peer.close();
            all_peers.remove(peer.id);
            peers.remove(pkey);
        }
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
    void send(Pubkey pkey, Buffer buf) {
        assert(isActive(pkey), "No established connection");
        peers[pkey].send(buf);
    }

    /// Check if an active known connection exists with this public key
    bool isActive(const(Pubkey) channel) const pure nothrow {
        return ((channel in peers) !is null);
    }
    bool isActive(int id) const pure nothrow {
        return ((id in all_peers) !is null);
    }

    void abort() {
        nng_aio_abort(aio_conn, int());
        foreach(dialer; dialers.byValue) {
            dialer.abort();
        }
        foreach(peer; peers.byValue) {
            peer.abort();
        }
    }

    private nng_stream* get_listener_output() @trusted {
        nng_stream* socket = cast(nng_stream*)nng_aio_get_output(aio_conn, 0);
        assert(socket !is null, "No connections established?");
        return socket;
    }

    /* ---------------------------------- */

    // You should call this functions after each operation

    void update(NodeAction action, int id, const Pubkey channel = Pubkey.init) {
        final switch(action) {
        case NodeAction.received:
            assert(channel !is Pubkey.init, "received should be called with a public key");
            Peer* peer = all_peers[id];
            peer.state = Peer.State.ready;
            // Add to the list of known connections
            peers.require(channel, peer);
            break;

        case NodeAction.dialed:
            assert((id in dialers) !is null, "No dialer was allocated for this id");
            scope(exit) {
                dialers.remove(id);
            }

            auto dialer = dialers[id];
            nng_stream* socket = dialer.get_output;
            auto peer = new Peer(id, socket, bufsize);
            all_peers[id] = peer;
            peers[dialer.pkey] = peer;
            break;

        case NodeAction.accepted:
            nng_stream* socket = get_listener_output();
            all_peers[id] = new Peer(id, socket, bufsize);
            break;

        case NodeAction.sent:
            all_peers[id].state = Peer.State.ready;
            break;
        }
    }

    mixin NodeHelpers;
}

///
unittest {
    static void unit_handler(ref PeerMgr sender, ref PeerMgr receiver) {
        receiveOnlyTimeout(1.seconds, 
                (NodeAction a, int id) {
                    if(a is NodeAction.accepted) {
                        receiver.update(a, id);
                    }
                    else {
                        sender.update(a, id);
                    }
                },
                (NodeAction a, int id, Buffer buf) {
                    receiver.update(a, id, get_public_key(Document(buf)));
                }
        );
    }

    thisActor.task_name = "jens";

    import std.stdio;

    auto net1 = new StdSecureNet();
    net1.generateKeyPair("me1");

    auto net2 = new StdSecureNet();
    net2.generateKeyPair("me2");

    auto dialer = PeerMgr(net1, "abstract://whomisam" ~ generateId.to!string, 256);
    auto listener = PeerMgr(net2, "abstract://whomisam" ~ generateId.to!string, 256);

    dialer.listen();
    listener.listen();

    dialer.dial(listener.address, net2.pubkey);
    listener.accept();

    unit_handler(dialer, listener);
    unit_handler(dialer, listener);

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

        unit_handler(dialer, listener);
        unit_handler(dialer, listener);

        assert(listener.peers.length == 1);
    }

    {
        dialer.recv_all_ready;
        Buffer send_payload_p2 = HiRPC(net2).action("manythanks").serialize;
        listener.send(net1.pubkey, send_payload_p2);

        unit_handler(listener, dialer);
        unit_handler(listener, dialer);
    }

    {
        listener.recv_all_ready();
        Buffer send_payload_p1 = HiRPC(net1).action("manythanks").serialize;

        dialer.send(net2.pubkey, send_payload_p1);

        unit_handler(dialer, listener);
        unit_handler(dialer, listener);

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
        this.p2p = PeerMgr(this.net, opts.node_address, opts.bufsize);
    }

    Topic node_action_event = Topic("node_action");

    alias MsgQueue = Queue!Document;

    MsgQueue[Pubkey] msg_queues;

    void queue_write(Pubkey channel, Document data) {
        msg_queues.require(channel, new MsgQueue);
        msg_queues[channel].write(data);
    }

    Document queue_read(Pubkey channel) {
        if((channel in msg_queues) is null) {
            return Document.init;
        }
        MsgQueue queue = msg_queues[channel];
        Document doc;
        if(!queue.empty) {
            doc = queue.read;
        }
        if(queue.empty) {
            /// FIXME, msg queue is not cleaned if the node is never reached.
            msg_queues.remove(channel);
        }
        return doc;
    }

    void queued_send(NodeSend, Pubkey channel, Document doc = Document.init) {
        debug(nodeinterface) log("%s: %s", __FUNCTION__, channel.encodeBase64);
        if(!p2p.isActive(channel)) {
            queue_write(channel, doc);
            const nnr = addressbook[channel].get;
            p2p.dial(nnr.address, channel);

            debug(nodeinterface) log("%s: not Active", __FUNCTION__);
            return;
        }

        if(p2p.peers[channel].state !is Peer.State.ready) {
            queue_write(channel, doc);
            debug(nodeinterface) log("%s: not ready %s", __FUNCTION__, p2p.peers[channel].state);
            return;
        }

        Document queued_doc = queue_read(channel);
        if(queued_doc !is Document.init) {
            queue_write(channel, doc);
            p2p.send(channel, queued_doc.serialize);
            debug(nodeinterface) log("%s: sent from queue", __FUNCTION__);
        }
        else if(doc !is Document.init) {
            p2p.send(channel, doc.serialize);
            debug(nodeinterface) log("%s: sent direct", __FUNCTION__);
        }
    }

    void on_action_complete(NodeAction action, int id, Buffer buf = null) {
        debug(nodeinterface) log(text(action));
        log.event(node_action_event, text(action), Document());

        final switch(action) {
        case NodeAction.dialed:
            Pubkey channel = p2p.dialers[id].pkey;

            p2p.update(action, id);
            queued_send(NodeSend(), channel, Document.init);
            break;

        case NodeAction.accepted:
            p2p.update(action, id);
            p2p.all_peers[id].recv(); // Receive from the newly accepted peer
            p2p.accept(); // Accept a new request
            break;

        case NodeAction.sent:
            // TODO: if we sent breaking wave, then close
            p2p.update(action, id);
            p2p.all_peers[id].recv; // Be ready to receive next message
            break;

        case NodeAction.received:
            assert(buf !is null, "Node action should get a buffer");
            debug(nodeinterface) log("received %s bytes", buf.length);

            if(buf.length < 1) {
                on_node_error(NodeError(), NodeErrorCode.buf_empty, id, text(buf.length), __LINE__);
                return;
            }

            const(Document) doc = buf;

            if(!doc.empty && !doc.isInorder(Document.Reserved.no)) {
                on_node_error(NodeError(), NodeErrorCode.doc_inorder, id, text(doc.valid), __LINE__);
                return;
            }

            try {
                const hirpcmsg = hirpc.receive(doc);
                if(hirpcmsg.pubkey == this.net.pubkey) {
                    on_node_error(NodeError(), NodeErrorCode.msg_self, id, "", __LINE__);
                    return;
                }
                if(!hirpcmsg.isSigned) {
                    on_node_error(NodeError(), NodeErrorCode.msg_signed, id, text(hirpcmsg.signed), __LINE__);
                    return;
                }

                Pubkey channel = hirpcmsg.pubkey;
                p2p.update(action, id, channel);

                ExchangeState exchange_state = get_exchange_state(hirpcmsg);
                if (exchange_state is ExchangeState.BREAKING_WAVE || exchange_state is ExchangeState.SECOND_WAVE) {
                    p2p.close(channel);
                }
                
                // Send to hasgraph/epoch_creator
                receive_handle.send(ReceivedWavefront(), doc);
                // queued_send(NodeSend(), channel, Document.init);
            }
            catch(Exception e) {
                on_node_error(NodeError(), NodeErrorCode.exception, id, e.msg, __LINE__);
            }
            break;
        }
    }

    // TODO: timeout

    // TODO: close on error
    void on_node_error(NodeError, NodeErrorCode code, int id, string msg, int line) {
        p2p.close(id);
        log.error("%s(%s): %s %s", id, line, code, msg);
    }

    void on_nng_error(NNGError, nng_errno code, int id, string msg, int line) {
        p2p.close(id);
        if (code !is nng_errno.NNG_ECONNSHUT) {
            log.error("%s(%s): %s %s", id, line, nng_errstr(code), msg);
        }
    }

    void task() {
        p2p.listen();
        log("listening on %s", opts.node_address);
        p2p.accept();

        run(
                (NodeAction a, int id) {
                    on_action_complete(a, id);
                },
                (NodeAction a, int id, Buffer buf) {
                    on_action_complete(a, id, buf);
                },
                &queued_send,
                &on_node_error,
                &on_nng_error
        );
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

void node_error(string owner_task, nng_errno code, int id, string msg = "", int line = __LINE__) {
    ActorHandle(owner_task).send(NNGError(), code, id, msg, line);
}

ExchangeState get_exchange_state(const HiRPC.Receiver receiver) {
    return receiver.params[StdNames.state].get!ExchangeState;
}

Pubkey get_public_key(Document doc) {
    return doc[StdNames.owner].get!Pubkey;
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
