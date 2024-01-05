///
module tagion.services.nodeInterface;

@safe:

import core.time;

import tagion.services.messages;
import tagion.services.exception;
import tagion.crypto.Types;
import tagion.hibon.Document;
import tagion.gossip.AddressBook;
import tagion.basic.Types;
import tagion.actor;

import nngd;

///
struct NodeInterfaceOptions {
    uint send_timeout = 200;
    string node_address = "tcp://*:69420";

    import tagion.utils.JSONCommon;

    mixin JSONCommon;
}

///
struct NodeInterfaceService {

    immutable NodeInterfaceOptions opts;
    ActorHandle receive_handle;

    NNGSocket sock;
    this(immutable(NodeInterfaceOptions) opts, string message_handler_task) @trusted {
        this.sock = NNGSocket(nng_socket_type.NNG_SOCKET_BUS);
        this.opts = opts;
        this.receive_handle = ActorHandle(message_handler_task);
    }

    ~this() @trusted {
        sock.close();
    }

    void node_send(NodeSend, Pubkey channel, Document payload) @trusted {
        const address = addressbook.getAddress(channel);
        sock.dial(address);
        sock.send(payload.serialize);
    }

    void node_receive() @trusted {
        auto buf = sock.receive!Buffer;

        if (sock.m_errno != nng_errno.NNG_OK && sock.m_errno != nng_errno.NNG_ETIMEDOUT) {
            throw new ServiceException(nng_errstr(sock.m_errno));
        }

        receive_handle.send(Document(buf));
    }

    void task() {
        runTimeout(opts.send_timeout.msecs, &node_receive, &node_send);
    }
}