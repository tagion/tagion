/// This module handles and pre-validates the Smart contract send to the network
module tagion.prior_services.TransactionService;

import core.time;
import std.stdio : writeln, writefln;
import std.format;
import std.socket;
import core.thread;
import std.concurrency;
import std.exception : assumeUnique, assumeWontThrow;
import std.socket : SocketType, AddressFamily, SocketOptionLevel, SocketOption;

import tagion.network.ServerAPI;
import tagion.network.SSLSocket : SSLSocket;

import tagion.network.FiberServer : FiberServer, FiberRelay, SocketTimeout;
import tagion.logger.Logger;
import tagion.prior_services.Options : Options, setOptions, options;
import tagion.options.CommonOptions : commonOptions;
import tagion.basic.Types : Control, Buffer;

import tagion.hibon.Document;
import tagion.communication.HiRPC;
import tagion.hibon.HiBON;
import tagion.script.prior.StandardRecords : Contract, _SignedContract, PayContract;
import tagion.script.prior.SmartScript;
import tagion.crypto.SecureNet : StdSecureNet;

import tagion.actor.exceptions : fatal, taskfailure;
import tagion.basic.tagionexceptions : TagionException;

//import tagion.dart.DARTFile;
import tagion.dart.DART;
import tagion.dart.Recorder : RecordFactory;
import tagion.dart.DARTBasic;
import tagion.dart.DARTcrud : dartRead;

@safe class HiRPCNet : StdSecureNet {
    this(string passphrase) {
        super();
        generateKeyPair(passphrase);
    }
}

void transactionServiceTask(immutable(Options) opts) nothrow {
    try {
        scope (success) {
            ownerTid.prioritySend(Control.END);
        }

        // Set thread global options
        setOptions(opts);
        immutable task_name = opts.transaction.task_name;

        log.register(task_name);

        log("SockectThread port=%d addresss=%s",
                opts.transaction.service.server.port,
                commonOptions.url);

        import std.conv;

        HiRPC internal_hirpc = HiRPC(null);
        pragma(msg, "fixme(cbr): passphrase but set some how");
        immutable passphrase = "Very secret password for the server";
        auto hirpc = HiRPC(new HiRPCNet(passphrase));
        auto rec_factory = RecordFactory(hirpc.net);
        Tid node_tid = locate(opts.node_name);

        @trusted void sendPayload(Document payload) {
            node_tid.send(payload, true);
        }

        auto dart_sync_tid = locate(opts.dart.sync.task_name);

        @trusted void requestInputs(const(DARTIndex[]) inputs, uint id) {
            auto sender = dartRead(inputs, internal_hirpc, id);
            auto tosend = sender.toDoc.serialize; //internal_hirpc.toHiBON(sender).serialize;
            dart_sync_tid.send(opts.transaction.service.server.response_task_name, tosend);
            yield;
        }

        @trusted void search(Document doc, uint id) {
            import tagion.hibon.HiBONJSON;

            auto n_params = new HiBON;
            n_params["owners"] = doc;
            auto sender = internal_hirpc.search(n_params, id);
            auto tosend = sender.toDoc.serialize;
            dart_sync_tid.send(opts.transaction.service.server.response_task_name, tosend);
            yield;
        }

        @trusted void areWeInGraph(uint id) {
            auto sender = internal_hirpc.healthcheck(new HiBON(), id);
            auto tosend = sender.toDoc.serialize;
            prioritySend(node_tid, opts.transaction.service.server.response_task_name, tosend);
            yield;
        }

        @safe class TransactionRelay : FiberServer.Relay {
            bool agent(FiberRelay ssl_relay) {
                import tagion.hibon.HiBONJSON;

                @trusted const(Document) receivessl() {
                    import tagion.hibon.Document;
                    import tagion.hibon.HiBONRecord;

                    immutable buffer = ssl_relay.receive;
                    log("buffer receiver %d", buffer.length);
                    const result = Document(buffer);
                    bool check_doc(const Document main_doc,
                            const Document.Element.ErrorCode error_code,
                            const(Document.Element) current,
                            const(Document.Element) previous) nothrow @safe {
                        return false;
                    }

                    result.valid(&check_doc);
                    return result;
                }

                Document doc;
                uint respone_id;
                try {
                    doc = receivessl();

                    pragma(msg, "fixme(cbr): If doc is empty then return ");

                    pragma(msg, "fixme(cbr): smartscipt should be services not a local");
                    // import tagion.script.ScriptBuilder;
                    // import tagion.script.ScriptParser;
                    // import tagion.script.Script;

                    const hirpc_received = hirpc.receive(doc);
                    ssl_relay.id = hirpc_received.method.id;
                    const method_name = hirpc_received.method.name;
                    const params = hirpc_received.method.params;

                    {
                        void yield() @trusted {
                            Fiber.yield;
                        }

                        switch (method_name) {
                        case "search":
                            ssl_relay.requestResponse();
                            search(params, ssl_relay.id);
                            if (!ssl_relay.available) {
                                log.warning("connection closed to no response");
                                return true;
                            }
                            const response = ssl_relay.response;
                            ssl_relay.send(response);
                            break;
                        case "healthcheck":

                            log("sending healthcheck request");
                            ssl_relay.requestResponse();
                            areWeInGraph(ssl_relay.id);
                            if (!ssl_relay.available) {
                                log.warning("connection closed to no response");
                                return true;
                            }
                            const response = ssl_relay.response;
                            log("sending healthcheck response %s", Document(response).toJSON);
                            ssl_relay.send(response);
                            break;

                        case "transaction":
                            // Should be EXTERNAL
                            try {
                                auto signed_contract = _SignedContract(params);
                                //                            if (signed_contract.valid) {
                                //
                                // Load inputs to the contract from the DART
                                //

                                auto inputs = signed_contract.contract.inputs;
                                ssl_relay.requestResponse();
                                requestInputs(inputs, ssl_relay.id);
                                if (!ssl_relay.available) {
                                    log.warning("connection closed to no response");
                                    return true;
                                }
                                //() @trusted => Fiber.yield; // Expect an Recorder resonse for the DART service
                                const response = ssl_relay.response;
                                const received = internal_hirpc.receive(Document(response));
                                const foreign_recorder = rec_factory.recorder(
                                        received.response.result);

                                import tagion.script.prior.StandardRecords : StandardBill;

                                PayContract payment;

                                foreach (archive; foreign_recorder[]) {
                                    auto std_bill = StandardBill(archive.filed);
                                    payment.bills ~= std_bill;
                                }
                                foreach (input; signed_contract.contract.inputs) {
                                    foreach (bill; payment.bills) {
                                        if (hirpc.net.dartIndex(bill.toDoc) == input) {
                                            signed_contract.inputs ~= bill;
                                        }
                                    }
                                }
                                // Send the contract as payload to the HashGraph
                                // The data inside HashGraph is pure payload not an HiRPC
                                SmartScript.check(hirpc.net, signed_contract);
                                const payload = Document(signed_contract.toHiBON.serialize);
                                sendPayload(payload);
                                auto empty_params = new HiBON;
                                auto empty_response = internal_hirpc.result(hirpc_received,
                                        empty_params);
                                ssl_relay.send(empty_response.toDoc.serialize);
                            }
                            catch (TagionException e) {
                                log.error("Bad contract: %s", e.msg);
                                auto bad_response = internal_hirpc.error(hirpc_received, e.msg, 1);
                                ssl_relay.send(bad_response.toDoc.serialize);
                                return true;
                            }
                            {
                                auto response = new HiBON;
                                response["done"] = true;
                                const hirpc_send = hirpc.result(hirpc_received, response);
                                immutable send_buffer = hirpc_send.toDoc.serialize;
                                ssl_relay.send(send_buffer);
                            }
                            return true;
                        default:
                        }
                    }
                }
                catch (SocketTimeout e) {
                    log.error("Socket timeout: %s", e.msg);
                }
                catch (TagionException e) {
                    log.error("Bad contract: %s", e.msg);
                    const bad_response = hirpc.error(respone_id, e.msg, 1);
                    ssl_relay.send(bad_response.toDoc.serialize);
                }
                catch (Exception e) {
                    log.error("Bad connection: %s", e.msg);
                    const bad_response = hirpc.error(respone_id, e.msg, 1);
                    ssl_relay.send(bad_response.toDoc.serialize);
                }
                log("Stop connection");
                return true;
            }
        }

        auto relay = new TransactionRelay;
        auto listener = new SSLSocket(
                AddressFamily.INET,
                SocketType.STREAM,
                opts.transaction.service.cert.certificate,
                opts.transaction.service.cert.private_key);
        ServerAPI script_api = ServerAPI(opts.transaction.service.server, listener, relay);
        auto script_thread = script_api.start;

        bool stop;
        void handleState(Control ts) {
            with (Control) switch (ts) {

            case STOP:
                log("Stop transaction service: port %d", opts.transaction.service.server.port);
                script_api.stop;
                stop = true;
                break;
            default:
                log.warning("Bad Control command %s", ts);
            }
        }

        ownerTid.send(Control.LIVE);
        while (!stop) {
            receiveTimeout(500.msecs, //Control the thread
                    &handleState,
                    &taskfailure,
            );
        }
    }

    catch (Throwable t) {
        fatal(t);
    }
}
