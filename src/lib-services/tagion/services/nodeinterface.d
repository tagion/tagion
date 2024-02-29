/// Interface for the Node against other Nodes
module tagion.services.nodeinterface;

@safe:

import core.time;

import std.format;
import std.conv;
import std.ascii;
import std.exception;
import std.array;
import std.algorithm;

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
    string node_address = "tcp://*:10700"; // Address

    import tagion.utils.JSONCommon;

    // Convert the first number in a string to a number
    static int node_name_to_number(string node_name) pure nothrow {
        long i;
        foreach_reverse(c; node_name) {
            if(!c.isDigit) {
                break;
            }
            i++;
        }
        try {
            return node_name[$-i..$].to!int;
        } catch(Exception e) {
        }
        return 0;
    }

    void setPrefix(string prefix) nothrow {
        enum ABSTRACT = "abstract://";
        // FIXME: need proper address parser
        // 🤮🤮🤮
        if(node_address.startsWith("tcp://")) {
            const port = node_name_to_number(node_address) + node_name_to_number(prefix);
            const split_str = node_address.split(":");
            node_address = split_str[0] ~ ":" ~ split_str[1] ~ ":" ~ assumeWontThrow(port.to!string);
        }
        else if(node_address.startsWith(ABSTRACT)) {
            node_address = node_address[0 .. ABSTRACT.length] ~ prefix ~ node_address[ABSTRACT.length .. $];
        }
    }

    mixin JSONCommon;
}

unittest {
    NodeInterfaceOptions opt;
    assert(opt.node_name_to_number("1") == 1);
    assert(opt.node_name_to_number("no-9") == 9);
    assert(opt.node_name_to_number("node39") == 39);
    assert(opt.node_name_to_number("node0") == 0);
    assert(opt.node_name_to_number("39node") == 0);
    assert(opt.node_name_to_number("no39de") == 0);
    assert(opt.node_name_to_number("no-39de") == 0);
    assert(opt.node_name_to_number("node") == 0);
    
    opt.node_address = "tcp://*:10700";
    opt.setPrefix("node_1");
    assert(opt.node_address == "tcp://*:10701", opt.node_address);
    opt.setPrefix("node_1");
    assert(opt.node_address == "tcp://*:10702", opt.node_address);

    opt.node_address = "abstract://NODEINTERFACE";
    opt.setPrefix("node_1");
    assert(opt.node_address == "abstract://node_1NODEINTERFACE");
}

///
struct NodeInterfaceService {

    Topic event_send = Topic("node_send");
    Topic event_recv = Topic("node_recv");

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
        if (rc != 0) {
            log.error("attempt to dial (%s)%s %s", channel.encodeBase64, nnr.address, nng_errstr(sock_send.m_errno));
            return;
        }
        rc = sock_send.send(payload.serialize);
        if (rc != 0) {
            log.error("attempt to send (%s)%s %s", channel.encodeBase64, nnr.address, nng_errstr(sock_send.m_errno));
            return;
        }
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
