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
import tagion.logger.LogRecords;
import tagion.services.Options : Options, setOptions, setDefaultOption;
import tagion.options.CommonOptions : commonOptions;
import tagion.basic.Types : Control, Buffer;
import tagion.network.SSLFiberService;
import tagion.network.SSLServiceAPI;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.basic.TagionExceptions : fatal, taskfailure;

//import tagion.script.ScriptBuilder;

/**
 * \struct LogSubscriptionFilter
 * Struct store valid filters for each client
 */
struct LogSubscriptionFilter
{
    /** Tid for communicating with LoggerService */
    Tid logger_service_tid;
    /** filters array for storing all curent filters, received for subscribers */
    LogFilter[][uint] filters;

    /** Used when new listener want to receive logs
      * As soon as new listener is added, update filters and notify LoggerService
      *     @param listener_id - unique identification of new listener
      *     @param log_info - log level of needed messages for listener
      */
    void addSubscription(uint listener_id, LogFilter log_info) @trusted
    {
        writeln("Added new listener ", listener_id);
        filters[listener_id] ~= log_info;
        notifyLogService;
    }
    /** Used when listener want to stop receiving logs or disconnected
     *  Update current filters and notify LoggerService about them
     *      @param listener_id - unique identification of new listener
     *      @see \link LoggerService
     */
    void removeSubscription(uint listener_id) @trusted
    {
        filters.remove(listener_id);
        notifyLogService;
    }

    /// Send all current filters to LoggerService
    void notifyLogService()
    {
        import std.array;

        if (logger_service_tid != Tid.init)
        {
            logger_service_tid.send(LogFilterArray(filters.values.join.idup));
        }
        else
        {
            log.warning("Unable to notify logger service");
        }
    }

    /** Check received from LoggerService logs
     *      @param task_name Represent from which task we received logs
     *      @param log_level Represent log level for all logs from task
     *      @return Array of all clients_id that need this logs
     */
    uint[] matchFilters(LogFilter filter)
    {
        uint[] clients;
        foreach (client_id; filters.keys)
        {
            foreach (client_filter; filters[client_id])
            {
                // temporary debug solution - send to all connected subscribers
                //if (client_filter.match(filter))
                {
                    clients ~= client_id;
                    break;
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
void logSubscriptionServiceTask(Options opts) nothrow
{
    try
    {
        scope (success)
        {
            ownerTid.prioritySend(Control.END);
        }

        LogSubscriptionFilter subscribers;

        subscribers.logger_service_tid = locate(opts.logger.task_name);

        log.register(opts.logSubscription.task_name);

        log("SocketThread port=%d addresss=%s", opts.logSubscription.service.port, opts
                .logSubscription.service.address);

        import std.conv;

        @safe class LogSubscriptionRelay : SSLFiberService.Relay
        {
            bool agent(SSLFiber ssl_relay)
            {
                import tagion.hibon.HiBONJSON;

                @trusted const(Document) receivessl()
                {
                    try
                    {
                        immutable buffer = ssl_relay.receive;
                        const result = Document(buffer);
                        // if (result.isInorder) {
                        return result;
                        // }
                    }
                    catch (Exception t)
                    {
                        log.warning("%s", t.msg);
                    }
                    return Document();
                }

                const doc = receivessl();

                try
                {
                    const listener_id = ssl_relay.id();
                    auto filter_received = LogFilter(
                        doc["$msg"].get!Document["params"].get!Document);

                    subscribers.addSubscription(listener_id, filter_received);
                }
                catch (Exception e)
                {
                    log.error("Recieved document is wrong");
                }

                return false;
            }

            void terminate(uint id)
            {
                subscribers.removeSubscription(id);
            }
        }

        auto relay = new LogSubscriptionRelay;
        SSLServiceAPI logsubscription_api = SSLServiceAPI(opts.logSubscription.service, relay);
        logsubscription_api.start;

        bool stop;
        void control(Control ts)
        {
            with (Control) switch (ts)
            {
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

        @trusted void receiver(LogFilter filter, Document data)
        {
            // THIS IS DRAFT IMPLEMENTATION
            import std.stdio;
            import tagion.hibon.HiBONJSON;

            // writeln("......................................................");
            // writefln("receiver: %s: %s: %s", filter.log_level, filter.task_name, data.toPretty);
            writefln("......................... log from %s (text: %s) .............................", filter
                    .task_name, filter
                    .isTextLog);

            writeln(subscribers.filters.length);
            auto clients = subscribers.matchFilters(filter);
            writefln("clients: %s", clients);
            foreach (client; clients)
            {
                HiRPC hirpc;
                // TODO: send both filter and document
                const sender = hirpc.action("letter from LogSubscription!", data);
                immutable sender_data = sender.toDoc.serialize();
                logsubscription_api.send(client, sender_data);
            }
        }

        ownerTid.send(Control.LIVE);
        while (!stop)
        {
            receiveTimeout(500.msecs, //Control the thread
                &control,
                &taskfailure,
                &receiver,
            );
        }
    }
    catch (Throwable t)
    {
        fatal(t);
    }
}

/** \page LogSubscriptionService
 * Some stuff about service
 * How to link?
 * logSubscriptionServiceTask
 */
