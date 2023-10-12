/// Service created for filtering and sending proper logs to subscribers

module tagion.prior_services.LogSubscriptionService;

import std.algorithm : map, filter;
import std.algorithm.searching : canFind;
import std.array : array, join;
import std.stdio : writeln;
import core.thread : msecs;
import std.socket : SocketType, AddressFamily;

import tagion.basic.basic : TrustedConcurrency;
import tagion.basic.Types : Control;
import tagion.actor.exceptions : fatal, taskfailure;
import tagion.communication.HiRPC : HiRPC;
import tagion.logger.Logger : log, LogLevel, Topic;
import tagion.logger.LogRecords;
import tagion.prior_services.Options : Options;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : GetLabel;
import tagion.network.FiberServer : FiberServer, FiberRelay;
import tagion.network.ServerAPI : ServerAPI;
import tagion.network.SSLSocket : SSLSocket;

mixin TrustedConcurrency;

/**
 * \struct LogSubscribersInfo
 * Struct stores info about connected subscribers
 */
struct LogSubscribersInfo {
    /** Tid for communicating with LoggerService */
    Tid logger_service_tid;
    /** Array of filters for each connected subscriber_id */
    LogFilter[][uint] filters;

    this(Tid logger_service_tid) {
        this.logger_service_tid = logger_service_tid;
    }

    /** Method that saves filters for newly added subscriber
      * As soon as new subscriber is added, method updates filters and notify LoggerService
      *     @param subscriber_id - unique identificator of new subscriber
      *     @param subscriber_filters - filters received from new subscriber
      *     @see \link LoggerService
      */
    void addSubscription(uint subscriber_id, LogFilter[] subscriber_filters) @trusted {
        log("Added new subscriber: %s", subscriber_id);

        // Firstly get filter updates
        updateLogServiceFilters(getFilterUpdates(subscriber_filters), LogFiltersAction.ADD);

        // Secondly update filters storage
        filters[subscriber_id] = subscriber_filters;
    }

    /** Method that used when subscriber want to stop receiving logs or disconnected
      * Updates current filters and notify LoggerService about them
      *     @param subscriber_id - unique identificator of new subscriber
      *     @see \link LoggerService
      */
    void removeSubscription(uint subscriber_id) @trusted {
        auto filters_to_remove = filters[subscriber_id];

        // Firstly remove subscriber from filters map
        filters.remove(subscriber_id);

        // Secondly get filter updates
        updateLogServiceFilters(getFilterUpdates(filters_to_remove), LogFiltersAction.REMOVE);
    }

    /** Method that sends filter updates to LoggerService
      *     @param update_filters - list of filters to update
      *     @param action - type of update action ADD or REMOVE
      *     @see \link LoggerService
      */
    void updateLogServiceFilters(LogFilter[] update_filters, LogFiltersAction action) {
        pragma(msg, "fixme(ib): could be redesigned using shared storage");
        if (logger_service_tid != Tid.init) {
            logger_service_tid.send(LogFilterArray(update_filters.idup), action);
        }
        else {
            log.error("Unable to notify logger service");
        }
    }

    /** Method creates list of subscribers interested in given filter
      *     @param info - log info of received log
      *     @return list of all subscriber_ids that need this log
      */
    @safe uint[] getInterestedSubscribers(LogInfo info) const {
        uint[] result;
        foreach (subscriber_id; filters.keys) {
            foreach (subscriber_filter; filters[subscriber_id]) {
                if (subscriber_filter.match(info)) {
                    result ~= subscriber_id;
                    break;
                }
            }
        }
        return result;
    }

    /** Get list of unique LogFilters that updates current list of filters.
      * Function filters out elements that already exists in some LogFilters and leaves only LogFilters that differs
      *     @param received_filters - array of LogFilters to filter
      *     @return Array of LogFilters that are not present in current stored filters
      */
    LogFilter[] getFilterUpdates(LogFilter[] received_filters) const {
        return received_filters.filter!(a => !filters.values.join.canFind(a)).array;
    }
}

unittest {
    log.silent = true;
    enum task1 = "task1";
    enum task2 = "task2";
    enum task3 = "task3";
    enum symbol1 = "symbol1";
    enum symbol2 = "symbol2";

    auto log_symbol1 = LogFilter(task1, symbol1);
    auto log_symbol2 = LogFilter(task2, symbol2);
    auto log_text1 = LogFilter(task1, LogLevel.INFO);

    LogFilter[][uint] filters;
    filters[1] = [log_symbol1, log_symbol2];
    filters[2] = [log_text1];
    filters[3] = [log_symbol1];

    auto test_info = LogSubscribersInfo(Tid.init);
    test_info.filters = filters;

    /// LogSubscribersInfo_getInterestedSubscribers
    {
        auto log_text2_info = LogInfo(task3, LogLevel.INFO);
        auto log_text1_info = LogInfo(task1, LogLevel.INFO);
        auto log_symbol1_info = LogInfo(Topic(), task1, symbol1);

        assert(test_info.getInterestedSubscribers(log_text2_info) == []);
        assert(test_info.getInterestedSubscribers(log_text1_info) == [2]);
        assert(test_info.getInterestedSubscribers(log_symbol1_info) == [3, 1]);

        auto no_match_info = LogInfo(task1, LogLevel.NONE);
        assert(test_info.getInterestedSubscribers(no_match_info) == []);
    }

    /// LogSubscribersInfo_getFilterUpdates
    {
        import std.range : empty;

        enum new_symbol = "new_symbol";
        auto new_log1 = LogFilter(task1, new_symbol);
        auto new_log2 = LogFilter(task1, LogLevel.ALL);

        LogFilter[] no_updates = [log_symbol1];
        assert(test_info.getFilterUpdates(no_updates).empty);

        LogFilter[] new_filters = [new_log1, new_log2];
        assert(test_info.getFilterUpdates(new_filters) == new_filters);

        LogFilter[] mixed_filters = [
            log_symbol1, // miss
            log_text1, // miss 
            new_log1, // remain
            new_log2, // remain
        ];
        assert(test_info.getFilterUpdates(mixed_filters) == [new_log1, new_log2]);
    }
}

/** LogSubscriptionService handles network subscription to logs.
  * Service receives logs from LoggerService and dispatch them to interested subscribers
  * Main task for LogSubscriptionService
  *     @param opts - service options for this task
  *     @see \link LoggerService
  */
void logSubscriptionServiceTask(Options opts) nothrow {
    try {
        scope (exit) {
            writeln("Sending END from LogSubService");
            ownerTid.send(Control.END);
        }

        auto subscribers = LogSubscribersInfo(locate(opts.logger.task_name));

        log.register(opts.logsubscription.task_name);

        log("Start service port=%d addresss=%s",
                opts.logsubscription.service.server.port,
                opts.logsubscription.service.server.address);

        @safe class LogSubscriptionRelay : FiberServer.Relay {
            bool agent(FiberRelay ssl_relay) {
                @trusted const(Document) receivessl() {
                    try {
                        immutable buffer = ssl_relay.receive;
                        const result = Document(buffer);
                        // if (result.isInorder) {
                        return result;
                        // }
                    }
                    catch (Exception t) {
                        log.warning("Exception caught: %s", t);
                    }
                    return Document();
                }

                const doc = receivessl();

                try {
                    HiRPC hirpc;
                    const hirpc_received = hirpc.receive(doc);
                    const params = hirpc_received.method.params;

                    const subscriber_id = ssl_relay.id();
                    auto filters_received = params[].map!(e => e.get!LogFilter).array;

                    subscribers.addSubscription(subscriber_id, filters_received);
                }
                catch (Exception e) {
                    log.error("Received document is wrong");
                }

                return false;
            }

            void terminate(uint id) {
                subscribers.removeSubscription(id);
            }
        }

        auto relay = new LogSubscriptionRelay;
        auto listener = new SSLSocket(
                AddressFamily.INET,
                SocketType.STREAM,
                opts.logsubscription.service.cert.certificate,
                opts.logsubscription.service.cert.private_key);
        auto logsubscription_api = ServerAPI(opts.logsubscription.service.server, listener, relay);
        logsubscription_api.start;

        bool stop;

        /** Handler of Control signals
          * STOP signal stops service, all other signals are invalid here
          *     @param control - received signal
          */
        void control(Control control) {
            with (Control) switch (control) {
            case STOP:
                logsubscription_api.stop;
                stop = true;
                break;
            default:
                log.error("Bad Control command %s", control);
            }
        }

        /** Method that receives logs from \link LoggerService
          *     @param filter - metadata about received log
          *     @param data - Document that contains either TextLog or any \link HiBONRecord variable
          */
        @safe void receiveLogs(immutable(LogInfo) info, immutable(Document) doc) {
            auto log_data = new HiBON;
            log_data[GetLabel!(LogFilter).name] = LogFilter(info);
            log_data[GetLabel!(typeof(doc)).name] = doc;

            foreach (subscriber_id; subscribers.getInterestedSubscribers(info)) {
                HiRPC hirpc;
                HiRPC.Response message;
                message.id = subscriber_id;
                message.result = Document(log_data);
                const sender = HiRPC.Sender(hirpc.net, message);

                immutable sender_data = sender.toDoc.serialize();
                logsubscription_api.send(subscriber_id, sender_data);
            }
        }

        ownerTid.send(Control.LIVE);
        while (!stop) {
            receiveTimeout(500.msecs,
                    &control,
                    &taskfailure,
                    &receiveLogs,
            );
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}
