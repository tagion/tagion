module tagion.wallet.request;

import core.time;

import std.exception;
import std.stdio;
import std.format;

import tagion.communication.HiRPC;
import tagion.communication.nngurl;
import tagion.hibon.Document;
import tagion.hibon.HiBONtoText;
import tagion.hibon.HiBONRecord;
import tagion.wallet.WalletException;
import tagion.basic.tagionexceptions;

import nngd;

/**
 * Exception type used by for wallet network request errors
 */
@safe
class WalletRequestException : WalletException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

private alias check = Check!WalletRequestException;

pragma(msg, __FILE__ ~ ": fixme(lr) Remove trusted when nng is safe");

HiRPC.Receiver sendHiRPC(string address, HiRPC.Sender contract, HiRPC hirpc = HiRPC(null)) @trusted {
    const url = NNGURL(address);
    switch (url.scheme) {
        case "http":
            return sendShellHiRPC(address, contract, hirpc);
        default:
            return sendKernelHiRPC(address, contract, hirpc);
    }
}

HiRPC.Receiver sendKernelHiRPC(string address, HiRPC.Sender contract, HiRPC hirpc = HiRPC(null)) @trusted {
    int rc;
    NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
    sock.sendtimeout = 1000.msecs;
    sock.sendbuf = 0x4000;
    sock.recvtimeout = 3000.msecs;

    rc = sock.dial(address);
    if (rc != 0) {
        throw new WalletRequestException(format("Could not dial address %s: %s", address, nng_errstr(rc)));
    }

    rc = sock.send(contract.toDoc.serialize);
    check(sock.m_errno == nng_errno.NNG_OK, format("NNG_ERRNO %d", cast(int) sock.m_errno));
    check(rc == 0, format("Could not send bill to network %s", nng_errstr(rc)));

    auto response_data = sock.receive!Buffer;
    auto response_doc = Document(response_data);
    check(response_doc.isRecord!(HiRPC.Receiver), format("Error in response when sending bill %s", response_doc.toPretty));

    return hirpc.receive(response_doc);
}

HiRPC.Receiver sendShellHiRPC(string address, Document doc, HiRPC hirpc) @trusted {
    WebData rep = WebClient.post(address, cast(ubyte[]) doc.serialize, [
        "Content-type": "application/octet-stream"
    ]);

    if (rep.status != http_status.NNG_HTTP_STATUS_OK || rep.type != "application/octet-stream") {
        throw new WalletRequestException(format("send shell submit, received: %s code(%d): %s text: %s", rep.type, rep.status, rep.msg, rep.text));
    }

    Document response_doc = Document(cast(immutable) rep.rawdata);
    check(response_doc.isRecord!(HiRPC.Receiver), format("Error in response when sending hirpc %s", response_doc.toPretty));

    return hirpc.receive(response_doc);
}

HiRPC.Receiver sendShellHiRPC(string address, HiRPC.Sender req, HiRPC hirpc) @safe {
    return sendShellHiRPC(address, req.toDoc, hirpc);
}
