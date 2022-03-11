module tagion.services.TransactionService;

import std.stdio : writeln, writefln;
import std.format;
import std.socket;
import core.thread;
import std.concurrency;
import std.exception : assumeUnique, assumeWontThrow;

import tagion.network.SSLServiceAPI;
import tagion.network.SSLFiberService : SSLFiberService, SSLFiber;
import tagion.logger.Logger;
import tagion.services.Options : Options, setOptions, options;
import tagion.options.CommonOptions : commonOptions;
import tagion.basic.Basic : Control, Buffer;

import tagion.hibon.Document;
import tagion.communication.HiRPC;
import tagion.hibon.HiBON;
import tagion.script.StandardRecords : Contract, SignedContract, PayContract;
import tagion.script.SmartScript;
import tagion.crypto.SecureNet : StdSecureNet;

import tagion.basic.TagionExceptions : fatal, taskfailure, TagionException;

import tagion.dart.DART;
import tagion.dart.Recorder : RecordFactory;

@safe class HiRPCNet : StdSecureNet {
    this(string passphrase) {
        super();
        generateKeyPair(passphrase);
    }
}

void transactionServiceTask(immutable(Options) opts) nothrow  {
    try {
        scope (success) {
            ownerTid.prioritySend(Control.END);
        }

        // Set thread global options
        setOptions(opts);
        immutable task_name = opts.transaction.task_name;

        log.register(task_name);

        log("SockectThread port=%d addresss=%s", opts.transaction.service.port, commonOptions.url);

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
        auto tagion_tid  = locate(opts.node_name);

        @trusted void requestInputs(Buffer[] inputs, uint id) {
            auto sender = DART.dartRead(inputs, internal_hirpc, id);
            auto tosend = sender.toDoc.serialize; //internal_hirpc.toHiBON(sender).serialize;
            send(dart_sync_tid, opts.transaction.service.response_task_name, tosend);
        }

        @trusted void search(Document doc, uint id) {
            import tagion.hibon.HiBONJSON;

            auto n_params = new HiBON;
            n_params["owners"] = doc;
            auto sender = internal_hirpc.search(n_params, id);
            auto tosend = sender.toDoc.serialize;
            send(dart_sync_tid, opts.transaction.service.response_task_name, tosend);
        }

        @trusted void areWeInGraph(uint id) {
            auto sender = internal_hirpc.healthcheck(new HiBON(), id);
            auto tosend = sender.toDoc.serialize;
            send(tagion_tid, opts.transaction.service.response_task_name, tosend);
        }

        @safe class TransactionRelay : SSLFiberService.Relay {
            bool agent(SSLFiber ssl_relay) {
                log("new connection");
                import tagion.hibon.HiBONJSON;

                @trusted const(Document) receivessl() {
                    try {
                        immutable buffer = ssl_relay.receive;
                        const result = Document(buffer);
                        if (result.isInorder) {
                            return result;
                        }
                    }
                    catch (Exception t) {
                        log.warning("%s", t.msg);
                    }
                    return Document();
                }

                const doc=receivessl();
                log("%s", doc.toJSON);
                const hirpc_received = hirpc.receive(doc);
                {
                    import tagion.script.ScriptBuilder;
                    import tagion.script.ScriptParser;
                    import tagion.script.Script;

                    const method_name = hirpc_received.method.name;
                    const params = hirpc_received.method.params;

                    void yield() @trusted {
                        Fiber.yield;
                    }

                    log(method_name);
                    switch (method_name) {
                    case "transaction":
                        // Should be EXTERNAL
                        try {
                            auto signed_contract = SignedContract(params);
                                //
                                // Load inputs to the contract from the DART
                                //

                                auto inputs = signed_contract.contract.input;
                                requestInputs(inputs, ssl_relay.id);
                                yield;
                                const response = ssl_relay.response;
                                const received = internal_hirpc.receive(Document(response));
                                const foreign_recorder = rec_factory.recorder(
                                        received.response.result);
                                log("constructed");

                                import tagion.script.StandardRecords : StandardBill;

                                PayContract payment;

                                foreach (archive; foreign_recorder[]) {
                                    auto std_bill = StandardBill(archive.filed);
                                    payment.bills ~= std_bill;
                                }
                                signed_contract.input = payment.toDoc;
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
                        break;
                    case "search":
                        search(params, ssl_relay.id); //epoch number?
                        
                        do {
                            yield;/// Expects a response from the DART service
                        }
                        while (!ssl_relay.available());
                        const response = ssl_relay.response;
                        ssl_relay.send(response);
                        break;
                    case "healthcheck":
                    
                        log("sending healthcheck request");
                        areWeInGraph(ssl_relay.id);
                        do {
                            yield;
                            log("available - %s" , ssl_relay.available());
                        }
                        while (!ssl_relay.available());
                        const response = ssl_relay.response;
                        log("sending healthcheck response %s", Document(response).toJSON);
                        ssl_relay.send(response);
                        break;
                    default:
                        return true;
                    }
                }

                return true;
            }
        }

        auto relay = new TransactionRelay;
        SSLServiceAPI script_api = SSLServiceAPI(opts.transaction.service, relay);
        auto script_thread = script_api.start;

        bool stop;
        void handleState(Control ts) {
            with (Control) switch (ts) {
            case STOP:
                writefln("Transaction STOP %d", opts.transaction.service.port);
                log("Kill socket thread port %d", opts.transaction.service.port);
                script_api.stop;
                stop = true;
                break;
            default:
                log.error("Bad Control command %s", ts);
            }
        }
        ownerTid.send(Control.LIVE);
        while (!stop) {
            receiveTimeout(
                500.msecs, //Control the thread
                &handleState,
                &taskfailure,
                );
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}
