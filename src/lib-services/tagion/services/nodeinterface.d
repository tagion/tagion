/// Interface for the Node against other Nodes
/// https://docs.tagion.org/docs/architecture/NodeInterface
module tagion.services.nodeinterface;

@safe:

import core.time;
import core.thread : thread_attachThis;

import std.format;
import std.conv;
import std.exception;
import std.algorithm;
import std.typecons;

import tagion.actor;
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

///
struct NodeInterfaceOptions {
    uint send_timeout = 200; // Milliseconds
    uint recv_timeout = 200; // Milliseconds
    uint send_max_retry = 0;
    string node_address = "tcp://[::1]:10700"; // Address

    import tagion.utils.JSONCommon;

    mixin JSONCommon;
}

struct Peer {
    import libnng;

    enum State {
        ready,
        dial,
        receive,
        send,
    }

    // disable copy/postblitz
    @disable this(this);

    int id;

    // taskname is used inside the nng callback to know which thread to notify
    string ownerTask;
    string address;
    shared State state;

    nng_stream* socket;
    nng_aio* aio;
    nng_iov sendiov;
    ubyte[] sendbuf;

    nng_stream_dialer* dialer;

    this(int id, nng_stream* socket) @trusted {
        this.id = id;
        int rc = nng_aio_alloc(&aio, &callback, self);
        check(rc == nng_errno.NNG_OK, nng_errstr(rc));
        ownerTask = thisActor.task_name;
        this.socket = socket;
        sendbuf = new ubyte[](23);
        sendiov.iov_buf = &sendbuf[0];
    }

    this(int id, string address) @trusted {
        this.id = id;
        int rc = nng_aio_alloc(&aio, &callback, self);
        check(rc == nng_errno.NNG_OK, nng_errstr(rc));
        ownerTask = thisActor.task_name;
        sendbuf = new ubyte[](23);
        sendiov.iov_buf = &sendbuf[0];

        rc = nng_stream_dialer_alloc(&dialer, &address[0]);
        check(rc == nng_errno.NNG_OK, nng_errstr(rc));
    }

    ~this() {
        nng_stream_free(socket);
        nng_aio_free(aio);
    }


    alias This = typeof(this);
    private void* self () @trusted {
        return cast(void*)&this;
    }

    static void callback(void* ctx) @trusted nothrow {
        try {
            thread_attachThis();
            This* _this = cast(This*)ctx;
            check(_this !is null, "did not get this* through the ctx");

            int rc = nng_aio_result(_this.aio);
            if(rc != nng_errno.NNG_OK) {
                // FIXME: send up an error message
                return;
            }

            switch(_this.state) {
                case state.dial:
                    imported!"std.stdio".writefln("dialit!! %s", _this.ownerTask);
                    ActorHandle(_this.ownerTask).send(NodeConn(), _this.id);
                    _this.state = State.ready;
                    break;
                case state.receive:
                    nng_msg* recv_msg = nng_aio_get_msg(_this.aio);
                    if (recv_msg is null) {
                        // error
                        return;
                    }

                    Buffer buf = cast(Buffer)nng_msg_body(recv_msg)[0 .. nng_msg_len(recv_msg)]; 

                    ActorHandle(_this.ownerTask).send(NodeRecv(), _this.id, buf);
                    
                    _this.state = State.ready;
                    break;
                default:
                    imported!"std.stdio".writefln("sendit!! %s", _this.ownerTask);
                    ActorHandle(_this.ownerTask).send(NodeAIOTask(), _this.state);
                    _this.state = State.ready;
                    break;
            }

        } catch(Exception e) {
            log(e);
            // error
        }
    }

    void dial() {
        check(state is State.ready, "Can not call dial when not ready");
        state = State.dial;
        nng_stream_dialer_dial(dialer, aio);
    }

    void send(ubyte[] data) @trusted {
        check(state is State.ready, "Can not call send when not ready");
        state = State.send;
        sendbuf = data;
        sendiov.iov_len = data.length;

        int rc = nng_aio_set_iov(aio, 1, &sendiov);
        check(rc == 0, nng_errstr(rc));
        nng_stream_send(socket, aio);
    }

    void* get_output() {
        return nng_aio_get_output(aio, 0);
    }

    void recv() {
        /* check(state = State.stale); */
        state = State.receive;
        nng_stream_recv(socket, aio);
    }
}

/// Manages p2p node connections by pubkey
struct PeerMgr {
    import libnng;

    // disable copy/postblitz
    @disable this(this);

    // TODO: eject lru connections when max connections is exceeded
    this(SecureNet net, string address) @trusted {
        this.net = net;
        this.hirpc = HiRPC(net);
        int rc = nng_aio_alloc(&aio_conn, &callback, self);
        check(rc == 0, nng_errstr(rc));
        rc = nng_aio_alloc(&aio_none, null, null);
        check(rc == 0, nng_errstr(rc));
        this.task_name = thisActor.task_name;

        this.address = address;
        address ~= '\0';
        assert(this.address.length < address.length);
        rc = cast(nng_errno)nng_stream_listener_alloc(&listener, &address[0]);
        check(rc == nng_errno.NNG_OK, nng_errstr(rc));
    }

    ~this() {
        nng_aio_free(aio_conn);
        nng_aio_free(aio_none);
        nng_stream_listener_free(listener);
    }

    private {
        nng_stream_listener* listener;
        nng_socket listener_sock;
    }

    SecureNet net;
    HiRPC hirpc;
    string address;

    // All the peers who we know the public key off
    Peer*[Pubkey] peers;

    // We store all peers with an id
    // Since we don't know their public key if we are receing from them for the first time
    Peer*[long] all_peers;

    nng_aio* aio_conn;
    nng_aio* aio_none;

    // This task name is used inside the nng callback to know which thread to notify
    string task_name;

    alias This = typeof(this);
    private void* self () @trusted {
        return cast(void*)&this;
    }

    // This thread callback is used to notify the NodeInterface thread of incoming connections
    static void callback(void* ctx) @trusted {
        try {
            thread_attachThis(); // Attach the current thread to the gc
            This* _this = cast(This*)ctx;
            int rc = nng_aio_result(_this.aio_conn);

            int id = generateId!int;

            if(rc == nng_errno.NNG_OK) {
                ActorHandle(_this.task_name).send(NodeConn(), id);
            }
            else {
                // TODO error
            }
        }
        catch(Exception e) {
            log(e);
            // TODO: error
        }
    }


    void listen() {
        int rc = cast(nng_errno)nng_stream_listener_listen(listener);
        check(rc == nng_errno.NNG_OK, nng_errstr(rc));
    }

    void accept() @trusted {
        nng_stream_listener_accept(listener, aio_conn);
    }

    void dial(string address, Pubkey pkey) @trusted {
        int unknown_peer_id = generateId!int;
        Peer* peer_connection = new Peer(unknown_peer_id, address);
        peer_connection.dial();

        peers[pkey] = peer_connection;
        all_peers[unknown_peer_id] = peer_connection;

        // FIXME: dial should be async
        /* nng_aio_wait(aio_none); */
        /* nng_stream* socket = cast(nng_stream*)nng_aio_get_output(aio_none, 0); */
        /* assert(socket !is null); */
        /* if(socket is null) { */
        /*     // error */
        /*     return; */
        /* } */
        /**/
        /* long unknown_peer_id = generateId!long; */
        /* Peer* peer_connection = new Peer(unknown_peer_id, socket); */
        /* all_peers[unknown_peer_id] = peer_connection; */
        /* peers[pkey] = peer_connection; */
    }

    // Receive messages from all the peers that are not doing anything else
    void recv_all_ready() {
        foreach(peer; all_peers) {
            if(peer.state !is Peer.State.ready) {
                continue;
            }

            peer.recv();
        }
    }

    // --- Message handlers --- //

    // TODO: use envelope
    void on_recv(NodeRecv, int id, Buffer buf) {
        // Verify and add to known_peers
        if (buf.length <= 0) {
            // error
            return;
        }

        log.trace("received %s bytes", buf.length);
        Document doc = buf;
        if(!doc.isInorder) {
            // error
            return;
        }

        const hirpcmsg = hirpc.receive(doc);
        if(!hirpcmsg.signed !is HiRPC.SignedState.VALID) {
            // error
            return;
        }

        // Add to the list of known connections
        peers.require(hirpcmsg.pubkey, all_peers[id]);

        // receive_handle.send(ReceivedWavefront(), doc);
    }

    // A connection was established
    // Either by dial or accept
    // FIXME: there is a race condition here so the nng_stream* should probably be sent as a message
    void on_connection(NodeConn, int id) @trusted {
        if((id in all_peers) !is null) {
            Peer* dialed_peer = all_peers[id];
            dialed_peer.socket = cast(nng_stream*)dialed_peer.get_output;
            return;
        }

        /* assert((id in all_peers) is null, "peer id already exists"); */
        // Get the newest result from the nng message box

        nng_stream* socket = cast(nng_stream*)nng_aio_get_output(aio_conn, 0);
        if(socket is null) {
            // error
            return;
        }

        all_peers[id] = new Peer(id, socket);
        // Add the socket to connected peers
    }

    void on_aio_task(NodeAIOTask, Peer.State) {
    }

    void send(NodeSend, Pubkey pkey, ubyte[] buf) {
        check((pkey in peers) !is null, "No established connection");
        peers[pkey].send(buf);
    }

    auto handlers = tuple(&on_recv, &on_connection, &on_aio_task, &send);

    void task() {
    }
}


version(none)
unittest {
    thisActor.task_name = "jens";

    import conc = tagion.utils.pretend_safe_concurrency;
    import std.stdio;
    import std.variant;

    auto net1 = new StdSecureNet();
    net1.generateKeyPair("me1");

    auto net2 = new StdSecureNet();
    net2.generateKeyPair("me2");

    auto dialer = PeerMgr(net1, "abstract://whomisam1");
    auto listener = PeerMgr(net2, "abstract://whomisam2");

    /* dialer.listen(); */
    listener.listen();
    writeln("Connected ", dialer.peers.length);

    dialer.dial(listener.address, net2.pubkey);
    listener.accept();
    writeln("Connected ", dialer.peers.length);
    bool rc = conc.receiveTimeout(2.seconds, &dialer.on_connection, (Variant var) @trusted {assert(0, format("Unknown msg: %s", var)); });
    assert(rc, "not dialed");

    rc = conc.receiveTimeout(2.seconds, &listener.on_connection, (Variant var) @trusted {assert(0, format("Unknown msg: %s", var)); });
    assert(rc, "not accepted");

    assert(dialer.all_peers.length == 1);
    assert(listener.all_peers.length == 1);
    assert(dialer.all_peers.byValue.all!(p => p.state is Peer.State.ready));
    assert(listener.all_peers.byValue.all!(p => p.state is Peer.State.ready));

    listener.recv_all_ready();
    dialer.send(NodeSend(), net2.pubkey, [1,23,53,53]);
    /* rc = conc.receiveTimeout(2.seconds, (NodeAIOTask _, Peer.State s) { writeln(s); }); */
    /* assert(rc, "not sent"); */
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

    void node_send(NodeSend, const(Pubkey) channel, Document payload) @trusted {
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
