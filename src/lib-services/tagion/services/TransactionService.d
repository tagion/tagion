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
import tagion.Base : Control;

import tagion.communication.HiRPC : HiRPC;
import tagion.hibon.Document;
import tagion.communication.HiRPC;
import tagion.hibon.HiBON;
import tagion.script.StandardRecords : Contract, ContractType;

import tagion.gossip.GossipNet : StdSecureNet;

import tagion.TagionExceptions;

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

    HiRPC hirpc;
    immutable passphrase="Very secret password for the server";
    hirpc.net=new HiRPCNet(passphrase);
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
                    auto contract=Contract!(ContractType.INTERNAL)(params);
                    if (contract.valid) {
                        auto source=params["script"].get!string;
                        auto src=ScriptParser(source);
                        Script script;
                        auto builder=ScriptBuilder(src[]);
                        builder.build(script);

                        auto sc=new ScriptContext(10, 10, 10);
                        sc.push(params["stack"].get!uint);
                        sc.trace=true;
                        script.execute("start", sc);
                    }
                }
                catch (TagionException e) {
                    writeln("Bad contract:%s", e.msg);
                }
                break;
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
