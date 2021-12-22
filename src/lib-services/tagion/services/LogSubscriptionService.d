module tagion.services.LogSubscription;

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
import tagion.services.LoggerService;
import tagion.options.CommonOptions : commonOptions;
import tagion.basic.Basic : Control, Buffer;

import tagion.hibon.Document;
import tagion.communication.HiRPC;
import tagion.hibon.HiBON;
import tagion.script.StandardRecords : Contract, SignedContract, PayContract;
import tagion.script.SmartScript;
import tagion.crypto.SecureNet : StdSecureNet;

import tagion.basic.TagionExceptions : fatal, taskfailure, TagionException;

struct Filter
{
    // protected fields

    void addSubscription(uint listener_id, Document doc) {} // add new listener and notify logService}
    void removeSubscription(uint listener_id) { } // remove listener, all related filters and notify log service}
    void notifyLogService() {} // logService.updateFilter()}
}

//function that should be called from LogService
// add args
void receiveLogs(Document doc)
{
    // filder doc -> return id
    // immutable logs_buffer = doc.seliaze();
    // send(logs_buffer, id)
}

void logSubscriptionServiceTask(immutable(Options) opts) nothrow {
    try {
        scope (success) {
            ownerTid.prioritySend(Control.END);
        }

        setOptions(opts);
        immutable task_name = opts.logSubscription.task_name;

        log.register(task_name);

        log("SockectThread port=%d addresss=%s", opts.logSubscription.service.port, commonOptions.url);

        import std.conv;

        @safe class LogSubscriptionRelay : SSLFiberService.Relay {
            bool agent(SSLFiber ssl_relay) {
                import tagion.hibon.HiBONJSON;

                //Document doc;
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

                const doc = receivessl();
                log("%s", doc.toJSON);
                {
                    import tagion.script.ScriptBuilder;
                    import tagion.script.ScriptParser;
                    import tagion.script.Script;

                    const listener_id = ssl_relay.id();

                    // addSubscription(listener_id, doc);
                }

                return true;
            }

            void terminate(uint id) {
                // removeSubscription(id);
            }
        }

        auto relay = new LogSubscriptionRelay;
        SSLServiceAPI logsubscription_api = SSLServiceAPI(opts.logSubscription.service, relay);
        auto logsubscription_thread = logsubscription_api.start;

        bool stop;
        void handleState(Control ts) {
            with (Control) switch (ts) {
            case STOP:
                writefln("Subscription STOP %d", opts.logSubscription.service.port);
                log("Kill socket thread port %d", opts.logSubscription.service.port);
                logsubscription_api.stop;
                stop = true;
                break;
            default:
                log.error("Bad Control command %s", ts);
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


