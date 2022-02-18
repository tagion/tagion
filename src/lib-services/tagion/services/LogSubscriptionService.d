/// \file LogSubscriptionService.d

/** @brief Service created for filtering and sending proper logs to subscribers
 */

module tagion.services.LogSubscriptionService;

import std.stdio : writeln, writefln;
import std.format;
import std.socket;
import core.thread;
import std.concurrency;
import std.exception : assumeUnique, assumeWontThrow;

import tagion.communication.HiRPC;

// import tagion.network.SSLServiceAPI;
// import tagion.network.SSLFiberService : SSLFiberService, SSLFiber;

import tagion.logger.Logger;
import tagion.services.LoggerService : LogFilter;
import tagion.services.Options : Options, setOptions, setDefaultOption;
import tagion.options.CommonOptions : commonOptions;
import tagion.basic.Basic : Control, Buffer;
import tagion.network.SSLFiberService;
import tagion.network.SSLServiceAPI;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.basic.TagionExceptions : fatal, taskfailure;
import tagion.script.ScriptBuilder;

/**
 * \struct LogSubscriptionFilter
 * Struct store valid filters for each client
 */
struct LogSubscriptionFilter {
    /** Tid for communicating with LoggerService */
    Tid logger_service_tid;
    /** filters array for storing all curent filters, received for subscribers */
    LogFilter[][uint] filters;

    /** Used when new listener want to receive logs
      * As soon as new listener is added, update filters and notify LoggerService
      *     @param listener_id - unique identification of new listener
      *     @param log_info - log level of needed messages for listener
      */
    void addSubscription(uint listener_id, LogFilter log_info) @trusted {
        writeln("Added new listener ", listener_id);
        filters[listener_id] ~= log_info;
        notifyLogService;
    }
    /** Used when listener want to stop receiving logs or disconnected
     *  Update current filters and notify LoggerService about them
     *      @param listener_id - unique identification of new listener
     *      @see \link LoggerService
     */
    void removeSubscription(uint listener_id) @trusted {
        filters.remove(listener_id);
        notifyLogService;
    }

    /// Send all current filters to LoggerService
    void notifyLogService() {
        import std.array;
        if (logger_service_tid != Tid.init) {
            logger_service_tid.send(filters.values.join.idup);
        }
    }

    /** Check received from LoggerService logs
     *      @param task_name Represent from which task we received logs
     *      @param log_level Represent log level for all logs from task
     *      @return Array of all clients_id that need this logs
     */
    uint[] matchFilters(string task_name, LoggerType log_level) {
        uint[] clients;
        foreach (client_id; filters.keys) {
            foreach(filter; filters[client_id]) {
                if (filter.match(task_name, log_level)) {
                    clients ~= client_id;
                }
            }
        }
        return clients;
    }
}

/**
 * Alias for something to read
 * @tparam T my param
 * @tparam R not my param
 */
/// \snippet HiBON.d Zero Test
alias binread(T, R) = MyStruct.read!(T, Endian.littleEndian, R);

    /** Service interact with ... / receive and store messages from ...
     * All usefull stuff also mys be here
     * Main task for LogSubscriptionService
     * @param opts - options for running this task
     */
void logSubscriptionServiceTask(Options opts) nothrow {
    try {
        scope (success) {
            ownerTid.prioritySend(Control.END);
        }

        LogSubscriptionFilter subscribers;

        subscribers.logger_service_tid = locate(opts.logger.task_name);

        log.register(opts.logSubscription.task_name);

        log("SockectThread port=%d addresss=%s", opts.logSubscription.service.port, opts.logSubscription.service.address);

        import std.conv;

        @safe class LogSubscriptionRelay : SSLFiberService.Relay {
            bool agent(SSLFiber ssl_relay) {
                import tagion.hibon.HiBONJSON;

                writeln("bool agent");

                @trusted const(Document) receivessl() {
                    try {
                        writeln(ssl_relay is null);
                        immutable buffer = ssl_relay.receive;
                        writeln("%s", buffer);
                        const result = Document(buffer);
                        // if (result.isInorder) {
                            return result;
                        // }
                    }
                    catch (Exception t) {
                        log.warning("%s", t.msg);
                    }
                    return Document();
                }

                const doc = receivessl();
                log("%s", doc.toPretty);
                {
                    const listener_id = ssl_relay.id();
                    if (doc.hasMember("task_name") && doc.hasMember("log_level")) {
                        auto task_name = doc.opIndex("task_name").data;
                        auto log_levels = doc.opIndex("log_level").data;
                        ubyte result = 0;
                        foreach (log_level; log_levels) {
                            result += log_level;
                        }
                        LogFilter filter = LogFilter(cast(string)task_name, cast(LoggerType)result);

                        subscribers.addSubscription(listener_id, filter);
                    }
                }
                return false;
            }

            void terminate(uint id) {
                subscribers.removeSubscription(id);
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

        @trusted void receiver(string task_name, LoggerType log_level, string log_output) {
            writeln(subscribers.filters.length);
            auto clients = subscribers.matchFilters(task_name, log_level);
            foreach(client; clients) {
                HiRPC hirpc;
                const sender = hirpc.action(log_output);
                immutable log_buffer = sender.toDoc.serialize();
                logsubscription_api.send(client, log_buffer);
            }
        }

        ownerTid.send(Control.LIVE);
        while (!stop) {
            receiveTimeout(500.msecs, //Control the thread
                &handleState,
                &taskfailure,
                &receiver,
                );
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}

/** \page LogSubscriptionService
 * Some stuff about service
 * How to link?
 * logSubscriptionServiceTask
 */
