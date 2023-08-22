/// Service for validating inputs sent via socket
/// [Documentation documents/architecture/InputValidator](https://docs.tagion.org/#/documents/architecture/InputValidator)
module tagion.services.inputvalidator;

import std.socket;
import std.stdio;
import std.algorithm : remove;

import core.time;

import tagion.actor;
import tagion.logger.Logger;
import tagion.utils.pretend_safe_concurrency;
import tagion.script.StandardRecords;
import tagion.network.ReceiveBuffer;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.communication.HiRPC;
import tagion.basic.basic : forceRemove;
import tagion.basic.Debug : __write;
import tagion.GlobalSignals : stopsignal;
import tagion.utils.JSONCommon;
version(NNG_INPUT) import nngd;

/// Msg Type sent to actors who receive the document
alias inputDoc = Msg!"inputDoc";

@safe
struct InputValidatorOptions {
    string sock_addr;
    // uint mbox_timeout = 10; // msecs
    uint socket_select_timeout = 1000; // msecs
    uint max_connections = 1;
    mixin JSONCommon;
}

/** 
 *  InputValidator actor
 *  Examples: [tagion.testbench.services.inputvalidator]
 *  Sends: (inputDoc, Document) to receiver_task;
**/
version(NNG_INPUT) {
struct InputValidatorService {
    void task(immutable(InputValidatorOptions) opts, string receiver_task,) {
        NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PULL);
        ReceiveBuffer buf;
        s.recvtimeout = opts.socket_select_timeout.msecs;
        const listening = s.listen(opts.sock_addr);
        if (listening == 0) {
            log("listening on addr: %s", opts.sock_addr);
        }
        else {
            log.error("Failed to listen on addr: %s, %s", opts.sock_addr, nng_errstr(listening));
            assert(0); // fixme
        }
        const recv = (void[] b) @trusted { 
	    size_t ret = s.receivebuf(cast(ubyte[]) b); 
            return (ret < 0)? 0 : cast(ptrdiff_t)ret;
        };
        setState(Ctrl.ALIVE);
        while(!thisActor.stop){
            auto result = buf.append(recv);
            if (s.m_errno != nng_errno.NNG_OK) {
                log.error("Failed to receive: %s", s.m_errno, nng_errstr(s.m_errno));
                // fail()
            }

            if (result.size != 0) {
                Document doc = Document(cast(immutable) result.data);
                __write("Received %d bytes.", result.size);
                __write("Document status code %s", doc.valid);

                    if(doc.valid is Document.Element.ErrorCode.NONE 
                    && doc.isRecord!(HiRPC.Sender)) {
                    __write("sending to %s", receiver_task);
                    locate(receiver_task).send(inputDoc(), doc);
                }
            }

            // Check for control signal
            receiveTimeout(
                    Duration.zero,
                    &signal,
                    &ownerTerminated,
                    &unknown
            );
        }
        log("RR: bye!");
    }
}
}
else {
struct InputValidatorService {
    void task(immutable(InputValidatorOptions) opts, string receiver_task,) {
        // setState(Ctrl.STARTING);
        auto listener = new Socket(AddressFamily.UNIX, SocketType.STREAM);
        assert(listener.isAlive);
        listener.blocking = false;
        try {
            listener.bind(new UnixAddress(opts.sock_addr));
        }
        catch (SocketOSException e) {
            pragma(msg, "TODO: implement pidfile lock on non-linux");
            import std.exception;

            log.fatal("Failed to open socket address %s, is the program already running?", opts.sock_addr);
            stopsignal.set;
            fail(e);
            return;
        }

        listener.listen(1);
        log("Listening on address %s.", opts.sock_addr);
        scope (exit) {
            log("Closing listener %s", opts.sock_addr);
            listener.close();
            assert(!listener.isAlive);
        }

        auto socketSet = new SocketSet(opts.max_connections + 1); // Room for listener.
        Socket[] reads;
        ReceiveBuffer buf;

        setState(Ctrl.ALIVE);
        while (!thisActor.stop) {
            try {
                socketSet.add(listener);
                foreach (sock; reads) {
                    socketSet.add(sock);
                }
                Socket.select(socketSet, null, null, opts.socket_select_timeout.msecs);

                foreach (i, ref read; reads) {
                    if (socketSet.isSet(read)) {
                        auto result = buf.append(&read.receive);
                        Document doc = Document(cast(immutable) result.data);
                        __write("Received %d bytes.", result.size);
                        __write("Document status code %s", doc.valid);
                        if (result.size != 0 && doc.valid is Document.Element.ErrorCode.NONE && doc.isRecord!(HiRPC
                                .Sender)) {
                            __write("sending to %s", receiver_task);
                            locate(receiver_task).send(inputDoc(), doc);
                        }
                        // release socket resources now
                        read.close();
                        reads = reads.remove(i);
                        // i will be incremented by the for, we don't want it to be.
                        i--;
                    }
                }

                /// Accept incoming reguests
                if (socketSet.isSet(listener)) {
                    Socket sn = null;
                    scope (failure) {
                        writefln("Error accepting");

                        if (sn)
                            sn.close();
                    }
                    sn = listener.accept();
                    assert(sn.isAlive);
                    assert(listener.isAlive);

                    if (reads.length < opts.max_connections) {
                        writefln("Connection established.");
                        reads ~= sn;
                    }
                    else {
                        writefln("Rejected connection; too many connections.");
                        sn.close();
                        assert(!sn.isAlive);
                        assert(listener.isAlive);
                    }
                }
                socketSet.reset();

                // Check for control signal
                receiveTimeout(Duration.zero,
                        &signal,
                        &ownerTerminated,
                        &unknown
                );
            }
            catch (Exception e) {
                fail(e);
            }
        }
    }
}
}

alias InputValidatorHandle = ActorHandle!InputValidatorService;
