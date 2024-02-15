/// Interface for the Node against other Nodes
module tagion.services.nodeInterface;

@safe:

import core.time;

import std.format;

import tagion.actor;
import tagion.basic.Types;
import tagion.crypto.Types;
import tagion.gossip.AddressBook;
import tagion.hibon.Document;
import tagion.logger;
import tagion.services.messages;
import tagion.services.exception;

import nngd;

///
struct NodeInterfaceOptions {
    uint send_timeout = 200; // Milliseconds
    uint recv_timeout = 200; // Milliseconds
    string node_address = "tcp://*:69420"; // Address

    import tagion.utils.JSONCommon;

    mixin JSONCommon;
}

///
struct NodeInterfaceService {

    immutable NodeInterfaceOptions opts;
    ActorHandle receive_handle;

    NNGSocket sock_recv;
    this(immutable(NodeInterfaceOptions) opts, string message_handler_task) @trusted {
        this.opts = opts;
        this.sock_recv = NNGSocket(nng_socket_type.NNG_SOCKET_PAIR);
        assert(sock_recv.m_errno == 0, format("Create recv sock error %s", nng_errstr(sock_recv.m_errno)));
        this.sock_recv.recvtimeout = opts.recv_timeout.msecs;
        this.sock_recv.sendtimeout = opts.send_timeout.msecs;
        this.receive_handle = ActorHandle(message_handler_task);
    }

    void node_send(NodeSend, const(Pubkey) channel, const(Document) payload) @trusted {
        const address = addressbook.getAddress(channel).get.address;
        NNGSocket sock_send = NNGSocket(nng_socket_type.NNG_SOCKET_PAIR);
        assert(sock_send.m_errno == 0, format("Create send sock error %s", nng_errstr(sock_send.m_errno)));
        sock_send.recvtimeout = opts.recv_timeout.msecs;
        sock_send.sendtimeout = opts.send_timeout.msecs;
        int rc = sock_send.dial(address);
        scope (exit) {
            sock_send.close();
        }

        assert(rc != -1, "You did not create the socket you dummy");
        if (rc != 0) {
            log.error("attempt to dial (%s)%s %s", channel.encodeBase64, address, nng_errstr(sock_send.m_errno));
            return;
        }
        rc = sock_send.send(payload.serialize);
        if (rc != 0) {
            log.error("attempt to send (%s)%s %s", channel.encodeBase64, address, nng_errstr(sock_send.m_errno));
            return;
        }
        log.trace("successfully sent %s bytes", payload.data.length);
    }

    void node_receive() @trusted {
        Buffer buf = sock_recv.receive!Buffer;

        if (sock_recv.m_errno != nng_errno.NNG_OK && sock_recv.m_errno != nng_errno.NNG_ETIMEDOUT) {
            throw new ServiceException(nng_errstr(sock_recv.m_errno));
        }

        if (buf.length > 0) {
            log.trace("received %s bytes", buf.length);
            receive_handle.send(NodeRecv(), Document(buf));
        }
    }

    void task() @trusted {
        int rc = sock_recv.listen(opts.node_address);
        assert(rc == 0, nng_errstr(sock_recv.m_errno));

        scope (exit) {
            sock_recv.close();
        }
        log("Listening on %s", opts.node_address);

        runTimeout(opts.send_timeout.msecs, &node_receive, &node_send);
    }
}
