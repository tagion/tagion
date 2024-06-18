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
import tagion.utils.LRU;
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
    uint pool_size = 12;
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

    uint id;
    string address;
    nng_stream_dialer* dialer;
    nng_aio* aio;
    string owner_task;

    ///
    this(uint id, string address_,) @trusted {
        int rc;
        rc = nng_aio_alloc(&aio, &callback, self);
        check(rc == nng_errno.NNG_OK, nng_errstr(rc));

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

    nng_stream* get_output() @trusted {
        nng_stream* sock = cast(nng_stream*)nng_aio_get_output(aio, 0);
        assert(sock !is null, "Dialed socket was null");
        return sock;
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

    uint id;

    // taskname is used inside the nng callback to know which thread to notify
    string owner_task;
    State state;
    bool initiater;

    nng_stream* socket;
    nng_aio* aio;
    nng_iov iov;
    ubyte[] msg_buf;

    Queue!Buffer send_queue;

    size_t bufsize = 8182;

    ///
    this(uint id, nng_stream* socket, size_t bufsize) @trusted {
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

    void close() nothrow {
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

    alias PeerLRU = LRU!(uint, Peer*);
    ///
    this(string address, size_t bufsize, uint pool_size) @trusted {
        this.bufsize = bufsize;
        int rc = nng_aio_alloc(&aio_conn, &callback, self);
        check!ServiceError(rc == 0, nng_errstr(rc));
        this.task_name = thisActor.task_name;

        this.address = address;
        address ~= '\0';
        assert(this.address.length < address.length);
        rc = cast(nng_errno)nng_stream_listener_alloc(&listener, &address[0]);
        check!ServiceError(rc == nng_errno.NNG_OK, nng_errstr(rc));

        all_peers = new PeerLRU(
                (scope const uint k, PeerLRU.Element* v) @safe nothrow { 
                    Peer* peer = v.entry.value; 
                    peer.close();
                    destroy(peer);
                    debug(nodeinterface) log("Closed (%s)", k);
                },
                pool_size,
        );
    }

    /// free nng memory
    ~this() {
        nng_aio_free(aio_conn);
        nng_stream_listener_free(listener);
    }

    nng_stream_listener* listener;

    string address;
    size_t bufsize;

    Dialer*[uint] dialers;

    /* Peer*[uint] all_peers; */
    LRU!(uint, Peer*) all_peers;

    nng_aio* aio_conn;

    // This task name is used inside the nng callback to know which thread to notify
    string task_name;

    // This thread callback is used to notify the NodeInterface thread of incoming connections
    static void callback(void* ctx) nothrow {
        This* _this = self(ctx);
        try {
            thread_attachThis(); // Attach the current thread to the gc
            nng_errno rc = cast(nng_errno)nng_aio_result(_this.aio_conn);

            uint id = generateId!uint;

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

    void recv(uint id) {
        all_peers[id].recv;
    }

    /// Connect to an address an associate it with a public key
    void dial(string address, uint id) {
        auto dialer = new Dialer(id, address);
        dialer.dial();
        dialers[id] = dialer;
    }

    void close(uint id) {
        all_peers.remove(id);
    }

    /// Send to an active connection with a known public key
    void send(uint id, Buffer buf) {
        auto peer = all_peers[id]; 
        check!ServiceException(peer !is null, format!"No active connections for this id %s"(id));
        peer.send(buf);
    }

    bool isActive(uint id) const pure nothrow {
        return all_peers.contains(id);
    }

    void abort() {
        nng_aio_abort(aio_conn, int());
        foreach(dialer; dialers.byValue) {
            dialer.abort();
        }
        foreach(peer; all_peers) {
            peer.value.abort();
        }
    }

    private nng_stream* get_listener_output() @trusted {
        nng_stream* socket = cast(nng_stream*)nng_aio_get_output(aio_conn, 0);
        assert(socket !is null, "No connections established?");
        return socket;
    }

    /* ---------------------------------- */

    // You should call this functions after each operation

    void update(NodeAction action, uint id) {
        final switch(action) {
        case NodeAction.received:
            Peer* peer = all_peers[id];
            check!ServiceException(peer !is null, format!"peer is not active %s"(id));
            peer.state = Peer.State.ready;
            break;

        case NodeAction.dialed:
            assert((id in dialers) !is null, "No dialer was allocated for this id");
            scope(exit) {
                dialers.remove(id);
            }

            auto dialer = dialers[id];
            scope(exit) { 
                destroy(dialer);
            }
            nng_stream* socket = dialer.get_output;
            auto peer = new Peer(id, socket, bufsize);
            all_peers[id] = peer;
            break;

        case NodeAction.accepted:
            nng_stream* socket = get_listener_output();
            auto peer = new Peer(id, socket, bufsize);
            all_peers[id] = peer;
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
    uint last_id;
    void unit_handler(ref PeerMgr sender, ref PeerMgr receiver) {
        receiveOnlyTimeout(1.seconds, 
                (NodeAction a, uint id) {
                    if(a is NodeAction.accepted) {
                        receiver.update(a, id);
                        receiver.recv(id);
                    }
                    else if(a is NodeAction.sent) {
                        sender.update(a, id);
                        sender.recv(id);
                    }
                    else {
                        sender.update(a, id);
                    }
                },
                (NodeAction a, uint id, Buffer buf) {
                    last_id = id;
                    receiver.update(a, id);
                }
        );
    }

    thisActor.task_name = "jens";

    import std.stdio;

    auto net1 = new StdSecureNet();
    net1.generateKeyPair("me1");

    auto net2 = new StdSecureNet();
    net2.generateKeyPair("me2");

    auto dialer = PeerMgr("abstract://whomisam" ~ generateId.to!string, 256, 2);
    auto listener = PeerMgr("abstract://whomisam" ~ generateId.to!string, 256, 2);

    dialer.listen();
    listener.listen();

    dialer.dial(listener.address, 1);
    listener.accept();

    unit_handler(dialer, listener);
    unit_handler(dialer, listener);

    assert(dialer.isActive(1));

    assert(dialer.all_peers.length == 1);
    assert(listener.all_peers.length == 1);
    assert(dialer.all_peers[].all!(e => e.value.state is Peer.State.ready));
    assert(listener.all_peers[].all!(e => e.value.state is Peer.State.receive));

    {
        // listener.recv
        Buffer send_payload_p1 = HiRPC(net1).action("manythanks").serialize;

        dialer.send(1, send_payload_p1);

        unit_handler(dialer, listener);
        unit_handler(dialer, listener);

        assert(listener.all_peers.length == 1);
    }

    {
        // dialer.recv
        Buffer send_payload_p2 = HiRPC(net2).action("manythanks").serialize;
        listener.send(last_id, send_payload_p2);

        unit_handler(listener, dialer);
        unit_handler(listener, dialer);
    }

    {
        // listener.recv
        Buffer send_payload_p1 = HiRPC(net1).action("manythanks").serialize;

        dialer.send(1, send_payload_p1);

        unit_handler(dialer, listener);
        unit_handler(dialer, listener);

        assert(listener.all_peers.length == 1);
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
        this.p2p = PeerMgr(opts.node_address, opts.bufsize, opts.pool_size);
    }

    static Topic node_action_event = Topic("node_action");

    Document[uint] queued_sends;
    bool[uint] should_close;

    void node_send(WavefrontReq req, Pubkey channel, Document doc) {
        const nnr = addressbook[channel].get;
        queued_sends[req.id] = doc;
        p2p.dial(nnr.address, req.id);
    }

    void node_respond(WavefrontReq req, const(Document) doc) {
        if(p2p.isActive(req.id)) {
            // We could close immediately if the message is an error and not a result?
            if(!(HiRPC(null).receive(doc).isMethod)) {
                should_close[req.id] = true;
            }
            p2p.send(req.id, doc.serialize);
        }
    }

    void on_action_complete(NodeAction action, uint id, Buffer buf = null) {
        debug(nodeinterface) log("%s %s, connected %s", id, action, p2p.all_peers.length);
        log.event(node_action_event, text(action), NodeInterfaceSub(net.pubkey, id, action));

        final switch(action) {
        case NodeAction.dialed:
            p2p.update(action, id);
            const doc = queued_sends[id];
            queued_sends.remove(id);
            p2p.send(id, doc.serialize);
            break;

        case NodeAction.accepted:
            p2p.update(action, id);
            p2p.all_peers[id].recv(); // Receive from the newly accepted peer
            p2p.accept(); // Accept a new request
            break;

        case NodeAction.sent:
            if((id in should_close) !is null) {
                p2p.close(id);
                should_close.remove(id);
            }
            else {
                p2p.update(action, id);
                p2p.all_peers[id].recv; // Be ready to receive next message
            }
            break;

        case NodeAction.received:
            assert(buf !is null, "Node action should get a buffer");
            debug(nodeinterface) log("received %s bytes", buf.length);

            if(buf.length < 1) {
                on_node_error(NodeError(), NodeErrorCode.buf_empty, id, text(buf.length), __LINE__);
                return;
            }

            const doc = Document(buf);

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
                
                if(hirpcmsg.isMethod) {
                    p2p.update(action, id);
                }
                else {
                    p2p.close(id);
                }

                receive_handle.send(WavefrontReq(id), doc);
            }
            catch(Exception e) {
                on_node_error(NodeError(), NodeErrorCode.exception, id, e.msg, __LINE__);
            }

            break;
        }
    }

    void on_node_error(NodeError, NodeErrorCode code, uint id, string msg, int line) {
        log.error("%s(%s): %s %s", id, line, code, msg);
        p2p.close(id);
    }

    void on_nng_error(NNGError, nng_errno code, uint id, string msg, int line) {
        if (code !is nng_errno.NNG_ECONNSHUT) {
            log.error("%s(%s): %s %s", id, line, nng_errstr(code), msg);
        }
        p2p.close(id);
    }

    void task() {
        p2p.listen();
        log("listening on %s", opts.node_address);
        p2p.accept();

        run(
                (NodeAction a, uint id) {
                    on_action_complete(a, id);
                },
                (NodeAction a, uint id, Buffer buf) {
                    on_action_complete(a, id, buf);
                },
                &node_send,
                &node_respond,
                &on_node_error,
                &on_nng_error
        );
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

import tagion.hibon.HiBONRecord;

// This record is used for internal subscription events
struct NodeInterfaceSub {
    @label(StdNames.owner) Pubkey owner;
    uint id;
    NodeAction action;

    mixin HiBONRecord;
}

void node_error(string owner_task, NodeErrorCode code, uint id, string msg = "", int line = __LINE__) {
    ActorHandle(owner_task).send(NodeError(), code, id, msg, line);
}

void node_error(string owner_task, nng_errno code, uint id, string msg = "", int line = __LINE__) {
    ActorHandle(owner_task).send(NNGError(), code, id, msg, line);
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
