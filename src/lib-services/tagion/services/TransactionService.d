module tagion.services.TransactionService;

import std.stdio : writeln, writefln;
import std.format;
import std.socket;
import core.thread;
import std.concurrency;
import std.exception : assumeUnique;

import tagion.network.SSLServiceAPI;
import tagion.network.SSLFiberService : SSLRelay;
import tagion.services.LoggerService;
import tagion.Options : Options, setOptions, options;
import tagion.Base : Control, Payload, Buffer;

import tagion.communication.HiRPC : HiRPC;
import tagion.hibon.Document;
import tagion.communication.HiRPC;
import tagion.hibon.HiBON;
import tagion.script.StandardRecords : Contract, SignedContract;
import tagion.script.SmartScript;
import tagion.gossip.GossipNet : StdSecureNet;

import tagion.TagionExceptions;

import tagion.dart.DARTFile;
import tagion.dart.DART;
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
    // Set thread global options
    setOptions(opts);
    immutable task_name=opts.transaction.task_name;
    writefln("opts.transaction.task_name=%s", opts.transaction.task_name);
    writefln("opts.transaction.service.task_name=%s", opts.transaction.service.task_name);


    log.register(task_name);

    log("SockectThread port=%d addresss=%s", opts.transaction.service.port, opts.url);

    import std.conv;

    HiRPC hirpc;
    HiRPC empty_hirpc = HiRPC(null);
    immutable passphrase="Very secret password for the server";
    hirpc.net=new HiRPCNet(passphrase);
    Tid node_tid=locate(opts.node_name);

    @trusted void sendPayload(Payload payload) {
        node_tid.send(payload);
    }
    auto dart_sync_tid = locate(opts.dart.sync.task_name);
    @trusted DARTFile.Recorder requestInputs(Buffer[] inputs){
        auto sender = DART.dartRead(inputs, empty_hirpc);
        auto tosend = empty_hirpc.toHiBON(sender).serialize;
        send(dart_sync_tid, opts.transaction.service.task_name, tosend);
        Buffer response = (receiveOnly!(Buffer, bool))[0];
        auto received = empty_hirpc.receive(Document(response));
        auto recorder = DARTFile.Recorder(hirpc.net, received.params);
        return recorder;
    }
    @trusted Buffer search(int epoch, Document doc){
        import tagion.hibon.HiBONJSON;
        auto n_params=new HiBON;
        // n_params["epoch"] = epoch;
        // n_params["owner"] = doc["owner"].get!Buffer;
        n_params["owners"] = doc;
        auto sender = empty_hirpc.search(n_params);
        auto tosend = empty_hirpc.toHiBON(sender).serialize;
        send(dart_sync_tid, opts.transaction.service.task_name, tosend);
        Buffer response;
        receiveTimeout(5.seconds,
        (Buffer buf, bool flag){
            response = buf;
        });
        // Buffer response = (receiveOnly!(Buffer, bool))[0];
        return response;
    }

    @safe bool relay(SSLRelay ssl_relay) {
        immutable buffer = ssl_relay.receive;
        if (!buffer) {
            return true;
        }
        const doc = Document(buffer);
        const hiprc_received = hirpc.receive(doc);
        {
            import tagion.hibon.HiBONJSON;
            import tagion.script.ScriptBuilder;
            import tagion.script.ScriptParser;
            import tagion.script.Script;

            const method=hiprc_received.message.method;
            const params=hiprc_received.params;

            switch (method) {
            case "transaction":
                // Should be EXTERNAL
                try {
                    auto signed_contract=SignedContract(params);
                    if (signed_contract.valid) {
                        // immutable source=signed_contract.contract.script;
                        // auto src=ScriptParser(source);
                        // Script script;
                        // auto builder=ScriptBuilder(src[]);
                        // builder.build(script);

                        // auto sc=new ScriptContext(10, 10, 10);
                        // if (params.params.length) {
                        //     sc.push(params.params["stack"].get!uint);
                        // }
                        // sc.trace=true;
                        // script.execute("start", sc);
                        //
                        // Load inputs to the contract from the DART
                        //

                        auto inputs = signed_contract.contract.input;
                        auto foreign_recoder=requestInputs(inputs);
                        import tagion.script.StandardRecords: StandardBill;
                        // writefln("input loaded %d", foreign_recoder.archive);
                        foreach(archive; foreign_recoder.archives){
                            auto std_bill = StandardBill(Document(archive.data));
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
                        auto empty_response = empty_hirpc.result(hiprc_received, empty_params);
                        ssl_relay.send(hirpc.toHiBON(empty_response).serialize);
                    }
                }
                catch (TagionException e) {
                    log.error("Bad contract: %s", e.msg);
                    auto bad_response = empty_hirpc.error(hiprc_received, e.msg, 1);
                    ssl_relay.send(hirpc.toHiBON(bad_response).serialize);
                }
                break;
            case "search":{
                // log("search request received");
                auto response = search(0, params);  //epoch number?
                if(response.length){
                    ssl_relay.send(response);
                }else{
                    auto bad_response = hirpc.error(hiprc_received, "Timeout exception", 1);
                    ssl_relay.send(hirpc.toHiBON(bad_response).serialize);
                }
                break;
            }
            default:
                return true;
            }
        }

        {
            auto params = new HiBON;
            params["done"]=true;
            const hirpc_send = hirpc.result(hiprc_received, params);
            immutable send_buffer=hirpc.toHiBON(hirpc_send).serialize;
            ssl_relay.send(send_buffer);

        }
        return true;
    }


//    immutable ssl_options=immutable(Options.ScriptingEngine)(options.scripting_engine);
    writefln("script_api.opts %s", opts.transaction.service.task_name);
    SSLServiceAPI script_api=SSLServiceAPI(opts.transaction.service, &relay);
    auto script_thread = script_api.start;
   // Thread script_thread;

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


    version(none)
    scope(exit) {
        log("EXIT");
        writefln("EXIT %d", opts.transaction.service.port);

        writefln("JOINED %d", opts.transaction.service.port);

    }

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
}
