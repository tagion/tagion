module tagion.wallet.request;

@safe:

import core.time;

import std.exception;
import std.stdio;
import std.format;

import tagion.communication.HiRPC;
import tagion.hibon.Document;
import tagion.hibon.HiBONtoText;
import tagion.hibon.HiBONRecord;
import tagion.wallet.WalletException;
import tagion.errors.tagionexceptions;

import nngd;

/**
 * Exception type used by for wallet network request errors
 */
class WalletRequestException : WalletException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

private enum DEFAULT_TIMEOUT = 3.seconds;

private alias check = Check!WalletRequestException;

HiRPC.Receiver sendHiRPC(string address, HiRPC.Sender contract, HiRPC hirpc = HiRPC(null), Duration timeout = DEFAULT_TIMEOUT) {
    const url = NNGURL(address);
    switch (url.scheme) {
        case "http":
            return sendShellHiRPC(address, contract, hirpc, timeout);
        default:
            return sendKernelHiRPC(address, contract, hirpc, timeout);
    }
}

HiRPC.Receiver sendKernelHiRPC(string address, HiRPC.Sender contract, HiRPC hirpc = HiRPC(null), Duration timeout = DEFAULT_TIMEOUT) {
    import tagion.network.socket;
    import tagion.network.ReceiveBuffer;

    Socket sock = Socket(address);
    sock.connect();

    const _ = sock.send(contract.toDoc.serialize);
    socket_check(sock.last_error == 0, "Error Sending");

    ReceiveBuffer receive_buffer;
    auto result_buffer = receive_buffer((scope void[] buf) => sock.receive(buf));
    socket_check(result_buffer.size > 0 , "Error receiving");

    Document response_doc = Document((() @trusted => receive_buffer.buffer.assumeUnique)());
    check(response_doc.isRecord!(HiRPC.Receiver), format("Error in response when sending bill %s", response_doc.toPretty));

    return hirpc.receive(response_doc);
}

pragma(msg, __FILE__ ~ ": fixme(lr) Remove trusted when nng is safe");
@trusted
HiRPC.Receiver sendShellHiRPC(string address, Document doc, HiRPC hirpc, Duration timeout = DEFAULT_TIMEOUT) {
    WebData rep = WebClient.post(address, doc.serialize, [
        "Content-type": "application/octet-stream"
    ], timeout);
    if (rep.status != http_status.NNG_HTTP_STATUS_OK || rep.type != "application/octet-stream") {
        throw new WalletRequestException(format("send shell submit, received: %s code(%d): %s text: %s", rep.type, rep.status, rep.msg, rep.text));
    }

    Document response_doc = Document(cast(immutable) rep.rawdata);
    check(response_doc.isRecord!(HiRPC.Receiver), format("Error in response when sending hirpc %s", response_doc.toPretty));

    return hirpc.receive(response_doc);
}

HiRPC.Receiver sendShellHiRPC(string address, HiRPC.Sender req, HiRPC hirpc, Duration timeout = DEFAULT_TIMEOUT) {
    return sendShellHiRPC(address, req.toDoc, hirpc, timeout);
}
