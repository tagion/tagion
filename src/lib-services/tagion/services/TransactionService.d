module tagion.services.TransactionService;

import std.stdio : writeln, writefln;
import std.format;
import std.socket;
import core.thread;
import std.concurrency;
import std.exception : assumeUnique;

import tagion.network.SSLServiceAPI;
import tagion.network.SSLFiberService : SSLFiberService, SSLFiber;
import tagion.services.LoggerService;
import tagion.Options : Options, setOptions, options;
import tagion.basic.Basic : Control, Payload, Buffer;

//import tagion.communication.HiRPC : HiRPC;
import tagion.hibon.Document;
import tagion.communication.HiRPC;
import tagion.hibon.HiBON;
import tagion.script.StandardRecords : Contract, SignedContract;
import tagion.script.SmartScript;
import tagion.gossip.GossipNet : StdSecureNet;

import tagion.basic.TagionExceptions;

import tagion.dart.DARTFile;
import tagion.dart.DART;

@safe
class HiRPCNet : StdSecureNet {
    this(string passphrase) {
        super();
        generateKeyPair(passphrase);
        // import tagion.utils.Miscellaneous;
        // import tagion.Base;
        // writefln("public=%s", (cast(Buffer)pubkey).toHexString);
    }
}

void transactionServiceTask(immutable(Options) opts) {
    try{
    // Set thread global options
    setOptions(opts);
    immutable task_name=opts.transaction.task_name;
    writefln("opts.transaction.task_name=%s", opts.transaction.task_name);
    writefln("opts.transaction.service.task_name=%s", opts.transaction.service.task_name);


    log.register(task_name);

    log("SockectThread port=%d addresss=%s", opts.transaction.service.port, opts.url);

    import std.conv;

    HiRPC hirpc;
    HiRPC internal_hirpc = HiRPC(null);
    immutable passphrase="Very secret password for the server";
    hirpc.net=new HiRPCNet(passphrase);
    Tid node_tid=locate(opts.node_name);

    @trusted void sendPayload(Payload payload) {
        node_tid.send(payload);
    }
    auto dart_sync_tid = locate(opts.dart.sync.task_name);

    @trusted void requestInputs(Buffer[] inputs, uint id){
        auto sender = DART.dartRead(inputs, internal_hirpc, id);
        auto tosend = internal_hirpc.toHiBON(sender).serialize;
        send(dart_sync_tid, opts.transaction.service.response_task_name, tosend);
        // Buffer response = receiveOnly!Buffer;
        // auto received = internal_hirpc.receive(Document(response));
        // auto recorder = DARTFile.Recorder(hirpc.net, received.params);
        // return recorder;
    }

    @trusted void search(Document doc, uint id){
        import tagion.hibon.HiBONJSON;
        auto n_params=new HiBON;
        n_params["owners"] = doc;
        auto sender = internal_hirpc.search(n_params, id);
        auto tosend = internal_hirpc.toHiBON(sender).serialize;
        send(dart_sync_tid, opts.transaction.service.response_task_name, tosend);
        /// Buffer response = receiveOnly!Buffer;
        // return response;
    }

    @safe class TransactionRelay : SSLFiberService.Relay {
        bool agent(SSLFiber ssl_relay) {
            import tagion.hibon.HiBONJSON;
            Document doc;
            @trusted void receivessl(){
            try{
                immutable buffer = ssl_relay.receive;
                log(cast(string)buffer);
                if (!buffer) {
                    return ;
                }
                doc = Document(buffer);
            }
            catch(Exception e){
                log("ERROR: %s", e.msg);
                throw e;
            }
            catch(Throwable t){
                log("T: %s %d", t.msg, t.line);
            }
            }
            receivessl();
        log("%s", doc.toJSON);
        const hirpc_received = hirpc.receive(doc);
        {
            import tagion.script.ScriptBuilder;
            import tagion.script.ScriptParser;
            import tagion.script.Script;

            const method=hirpc_received.message.method;
            const params=hirpc_received.params;

            void yield() @trusted {
                Fiber.yield;
            }
            log(method);
            switch (method) {
            case "transaction":
                // Should be EXTERNAL
                try {
                    auto signed_contract=SignedContract(params);
                    if (signed_contract.valid) {
                        //
                        // Load inputs to the contract from the DART
                        //

                        auto inputs = signed_contract.contract.input;
                        requestInputs(inputs, ssl_relay.id);
                        yield;
                        //() @trusted => Fiber.yield; // Expect an Recorder resonse for the DART service
                        const response=ssl_relay.response;
                        const received = internal_hirpc.receive(Document(response));
                        const foreign_recorder = DARTFile.Recorder(hirpc.net, received.params);
                        //return recorder;

                        import tagion.script.StandardRecords: StandardBill;
                        // writefln("input loaded %d", foreign_recoder.archive);
                        foreach(archive; foreign_recorder.archives){
                            auto std_bill = StandardBill(archive.doc);
                            signed_contract.input ~= std_bill;
                        }

                        // Send the contract as payload to the HashGraph
                        // The data inside HashGraph is pure payload not an HiRPC
                        SmartScript.check(hirpc.net, signed_contract);
                        Payload payload=signed_contract.toHiBON.serialize;
                        {
                            immutable data=signed_contract.toHiBON.serialize;
                            const json_doc=Document(data);
                            auto json=json_doc.toJSON;

                            log("Contract:\n%s", json.toPrettyString);
                        }
                        sendPayload(payload);
                        auto empty_params = new HiBON;
                        auto empty_response = internal_hirpc.result(hirpc_received, empty_params);
                        ssl_relay.send(hirpc.toHiBON(empty_response).serialize);
                    }
                }
                catch (TagionException e) {
                    log.error("Bad contract: %s", e.msg);
                    auto bad_response = internal_hirpc.error(hirpc_received, e.msg, 1);
                    ssl_relay.send(hirpc.toHiBON(bad_response).serialize);
                    return true;
                }
                {
                    auto response = new HiBON;
                    response["done"]=true;
                    const hirpc_send = hirpc.result(hirpc_received, response);
                    immutable send_buffer=hirpc.toHiBON(hirpc_send).serialize;
                    ssl_relay.send(send_buffer);
                }
                return true;
                break;
            case "search":
                // log("search request received");
                // auto response =
                search(params, ssl_relay.id);  //epoch number?
                yield; /// Expects a response from the DART service
                const response=ssl_relay.response;
                // log(response)
                // auto doc1 = Document(response);
                // log("Response: %s", doc1.toJSON);
                ssl_relay.send(response);
                break;
            default:
                return true;
            }
        }

        return true;
    }
    }


    auto relay=new TransactionRelay;
    SSLServiceAPI script_api=SSLServiceAPI(opts.transaction.service, relay);
    auto script_thread = script_api.start;
    scope(success) {
        writefln("EXIT %d END %s", opts.transaction.service.port, script_thread.isRunning);
//        script_thread.join;
        ownerTid.send(Control.END);
        writeln("After Control.END");
    }

    scope(failure) {
        writefln("EXIT %d Failed %s", opts.transaction.service.port, script_thread.isRunning);
//        script_thread.join;
        ownerTid.send(Control.FAIL);
        writeln("After Control.FAIL");
    }

   // Thread script_thread;


    bool stop;
    void handleState (Control ts) {
        with(Control) switch(ts) {
            case STOP:
                writefln("Transaction STOP %d", opts.transaction.service.port);
                log("Kill socket thread port %d", opts.transaction.service.port);
                script_api.stop;
//                script_thread.join;
                stop = true;
                break;
                // case LIVE:
                //     stop = false;
                //     break;
            default:
                log.error("Bad Control command %s", ts);
                //    stop=true;
            }
    }

    ownerTid.send(Control.LIVE);
    while(!stop) {
        receiveTimeout(500.msecs,
            //Control the thread
            &handleState,
            (immutable(TagionException) e) {
                log.fatal(e.msg);
                ownerTid.send(e);
            },
            (immutable(Exception) e) {
                log.fatal(e.msg);
                ownerTid.send(e);
            },
            (immutable(Throwable) t) {
                log.fatal(t.msg);
                ownerTid.send(t);
            }
            );
    }
    }catch(Exception e){
                log.fatal(e.msg);
    }
}
