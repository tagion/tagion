module tagion.services.LogSubscriptionService;

import std.stdio : writeln, writefln;
import std.format;
import std.socket;
import core.thread;
import std.concurrency;
import std.exception : assumeUnique, assumeWontThrow;
import std.array : join;

// import tagion.network.SSLServiceAPI;
// import tagion.network.SSLFiberService : SSLFiberService, SSLFiber;

import tagion.logger.Logger;
import tagion.services.Options : Options, setOptions;
import tagion.options.CommonOptions : commonOptions;
import tagion.basic.Basic : Control, Buffer;

import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.basic.TagionExceptions : fatal, taskfailure;

struct LogSubscriptionFilters {
    LogFilter[][uint] filters;

    void addSubscription(uint listener_id, LogFilter[] filters_array) {
        filters[listener_id] = filters_array.dup;
        notifyLogService;
    }

    void removeSubscription(uint listener_id) {
        filters.remove(listener_id);
        notifyLogService;
    }

    void notifyLogService() const {
        if (logger_service_tid != Tid.init) {
            logger_service_tid.send(LogFilterArray(filters.values.join.idup));
        }
    }

    bool matchListenerFilter(uint listener_id, string task_name, LoggerType log_level) {
        foreach (filter; filters[listener_id]) {
            if (filter.match(task_name, log_level)) {
                return true;
            }
        }
        return false;
    }
}

private static Tid logger_service_tid;

void logSubscriptionServiceTask(immutable(Options) opts) nothrow {
    try {
        scope (success) {
            ownerTid.prioritySend(Control.END);
        }

        LogSubscriptionFilters subscription_filters;

        setOptions(opts);

        log.register(opts.logSubscription.task_name);
        logger_service_tid = ownerTid;

        // TODO: this call is for testing purposes,
        // remove when it will be able to add real subscription
        subscription_filters.addSubscription(8888, [LogFilter("", LoggerType.INFO)]);
        subscription_filters.addSubscription(1111, [LogFilter("", LoggerType.ERROR)]);
        subscription_filters.addSubscription(2222, [LogFilter("", LoggerType.WARNING)]);

        // log("SockectThread port=%d addresss=%s", opts.logSubscription.service.port, commonOptions.url);

        // import std.conv;

        // @safe class LogSubscriptionRelay : SSLFiberService.Relay {
        //     bool agent(SSLFiber ssl_relay) {
        //         import tagion.hibon.HiBONJSON;

        //         //Document doc;
        //         @trusted const(Document) receivessl() {
        //             try {
        //                 immutable buffer = ssl_relay.receive;
        //                 const result = Document(buffer);
        //                 if (result.isInorder) {
        //                     return result;
        //                 }
        //             }
        //             catch (Exception t) {
        //                 log.warning("%s", t.msg);
        //             }
        //             return Document();
        //         }

        //         const doc = receivessl();
        //         log("%s", doc.toJSON);
        //         {
        //             import tagion.script.ScriptBuilder;
        //             import tagion.script.ScriptParser;
        //             import tagion.script.Script;

        //             const listener_id = ssl_relay.id();

        //             // addSubscription(listener_id, doc);
        //         }

        //         return true;
        //     }

        //     void terminate(uint id) {
        //         // removeSubscription(id);
        //     }
        // }

        // auto relay = new LogSubscriptionRelay;
        // SSLServiceAPI logsubscription_api = SSLServiceAPI(opts.logSubscription.service, relay);
        // auto logsubscription_thread = logsubscription_api.start;

        bool stop;
        void handleState(Control ts) {
            with (Control) switch (ts) {
            case STOP:
                writeln("Stopping LogSubscriptionService...");
                // writefln("Subscription STOP %d", opts.logSubscription.service.port);
                // log("Kill socket thread port %d", opts.logSubscription.service.port);
                // logsubscription_api.stop;
                stop = true;
                break;
            default:
                log.error("Bad Control command %s", ts);
            }
        }

        void receiveLogs(string task_name, LoggerType log_level, string log_output) {
            foreach (listener_id; subscription_filters.filters.keys) {
                if (subscription_filters.matchListenerFilter(listener_id, task_name, log_level)) {
                    writeln(format("sent {%s} to %d", log_output, listener_id));
                    //immutable log_buffer = log_output.seliaze();
                    //send(log_buffer, listener_id);
                }
            }
        }

        ownerTid.send(Control.LIVE);
        while (!stop) {
            receiveTimeout(500.msecs, //Control the thread
                    &handleState,
                    &taskfailure,
                    &receiveLogs,
            );
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}
