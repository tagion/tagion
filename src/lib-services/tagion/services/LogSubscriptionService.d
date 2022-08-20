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

import tagion.logger.Logger;
import tagion.services.LoggerService : LogFilter, LogFilterArray;
import tagion.services.Options : Options, setOptions, setDefaultOption;
import tagion.options.CommonOptions : commonOptions;
import tagion.basic.Types : Control, Buffer;
import tagion.network.SSLFiberService;
import tagion.network.SSLServiceAPI;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.basic.TagionExceptions : fatal, taskfailure;

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
        log("Added new listener %s", listener_id);
        notifyLogService;
        log("Notify Log Service done");
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
            immutable filters = LogFilterArray(filters.values.join.idup);
            logger_service_tid.send(filters);
        }
    }

    /** Check received from LoggerService logs
     *      @param task_name Represent from which task we received logs
     *      @param log_level Represent log level for all logs from task
     *      @return Array of all clients_id that need this logs
     */
    uint[] matchFilters(string task_name, LoggerType log_level)
    {
        uint[] clients;
        foreach (client_id; filters.keys)
        {
            foreach (filter; filters[client_id])
            {
                if (filter.match(task_name, log_level))
                {
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

        log("SockectThread port=%d addresss=%s", opts.logSubscription.service.port, opts
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

                        return result;
                    }
                    catch (Exception t)
                    {
                        log.warning("Receivessl exception in \'%s:%s\' %s", t.file, t.line, t.msg);
                    }
                    log("recievessl end Document()");
                    return Document();
                }

                const listener_id = ssl_relay.id();

                const doc = receivessl();
                const filters = doc["$msg"].get!Document["params"].get!LogFilter;
                log("filter received (\"%s\", LoggerType.%s)", filters.task_name, filters.log_level);

                // TODO: check is it LogFilter
                {
                    subscribers.addSubscription(listener_id, filters);
                }

                return false;
            }

            void terminate(uint id)
            {
                subscribers.removeSubscription(id);
            }
        }

        auto relay = new LogSubscriptionRelay;
        auto logsubscription_api = SSLServiceAPI(opts.logSubscription.service, relay, SSLFiberService
                .Duration.LONGTERM);
        auto logsubscription_thread = logsubscription_api.start;

        bool stop;
        void handleState(Control ts)
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

        @trusted void receiver(string task_name, LoggerType log_level, string log_output)
        {
            writeln(subscribers.filters.length);
            auto clients = subscribers.matchFilters(task_name, log_level);
            foreach (client; clients)
            {
                HiRPC hirpc;
                const sender = hirpc.action(log_output);
                immutable log_buffer = sender.toDoc.serialize();
                logsubscription_api.send(client, log_buffer);
            }
        }

        ownerTid.send(Control.LIVE);
        while (!stop)
        {
            receiveTimeout(500.msecs, //Control the thread
                &handleState,
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

unittest
{
    import std.algorithm;
    import std.getopt;
    import std.stdio;
    import core.thread;
    import std.getopt;
    import std.stdio;
    import std.format;
    import std.socket : InternetAddress, AddressFamily;

    import tagion.hibon.Document : Document;
    import tagion.network.SSLSocket;
    import tagion.services.Options;
    import tagion.options.CommonOptions : setCommonOptions;
    import tagion.services.LogSubscriptionService;
    import tagion.basic.Types : Control, Buffer;

    import tagion.communication.HiRPC;

    import core.thread;

    import std.array : join;
    import tagion.logger.Logger : LoggerType;
    import tagion.services.Options : Options, setDefaultOption;
    import tagion.options.CommonOptions : setCommonOptions;
    import tagion.utils.Miscellaneous;
    import tagion.utils.Gene;

    import std.path;
    import std.getopt;
    import std.stdio;
    import std.file : exists;
    import std.format;
    import std.conv : to;
    import std.array;
    import tagion.utils.Miscellaneous;
    import tagion.utils.Gene;
    import tagion.services.Options : Options, setDefaultOption;
    import tagion.services.LoggerService;
    import tagion.services.RecorderService;
    import tagion.basic.Basic : TrustedConcurrency;
    import tagion.basic.Types : Control, Buffer;
    import tagion.dart.DART : DART;
    import tagion.dart.Recorder : RecordFactory;
    import tagion.communication.HiRPC;
    import tagion.hibon.HiBON;
    import tagion.crypto.SecureInterfaceNet : SecureNet;
    import tagion.crypto.SecureNet : StdSecureNet, StdHashNet;
    import tagion.dart.BlockFile;
    import tagion.hibon.Document;
    import tagion.dart.DARTFile;

    import tagion.tasks.TaskWrapper;

    mixin TrustedConcurrency;

    writeln("START MY TEST...............................................................................................................");

    /** \struct ClientOptions
    *  Client options used to set up socket connection
    */
    struct ClientOptions
    {
        string addr; /// @brief client's addres
        ushort port; /// @brief client's port

        void setDefault()
        {
            addr = "127.0.0.1";
            port = 10700;
        }
    }

    ushort port = 10700;
    string task_name = "faketaskname";
    LoggerType log_info = LoggerType.ERROR;

    /// \link LogFilter
    LogFilter filter = LogFilter(task_name, log_info);

    /// @see Options
    Options service_options;
    service_options.setDefaultOption;
    service_options.logSubscription.enable = true;
    service_options.logSubscription.service.port = port;
    // Set the shared common options for all services
    setCommonOptions(service_options.common);

    writefln("input port: %d; options port: %d.", port, service_options
            .logSubscription.service.port);

    auto loggerService = Task!LoggerTask(service_options.logger.task_name, service_options);
    scope (exit)
    {
        loggerService.control(Control.STOP);
        receiveOnly!Control;
    }

    import std.stdio : stderr;

    writeln("...................1");

    const response = receiveOnly!Control;
    stderr.flush();
    std.stdio.stdout.flush();
    if (response !is Control.LIVE)
    {
        stderr.writeln("ERROR:Logger %s", response);
    }
    writeln("...................2");

    // ClientOptions options;
    // options.setDefault();
    writeln("...................3");
    Thread.sleep(3.seconds);

    /// @see SSLSocket
    auto client = new SSLSocket(AddressFamily.INET, EndpointType.Client);
    writeln("...................4");
    client.connect(new InternetAddress(service_options.logSubscription.service.address, service_options
            .logSubscription.service.port));
    writeln("...................5");

    scope (exit)
    {
        client.close;
    }

    /// @see HiRPC
    HiRPC hirpc;
    const sender = hirpc.action("test", filter.toDoc);
    writeln("...................6");
    immutable data = sender.toDoc.serialize;
    writeln(data);
    writeln("try send");
    client.send(data);
    writeln("done send");
    ptrdiff_t rec_size;
    auto rec_buf = new byte[4000];

    uint count;
    uint max_count = 5;

    do
    {
        writeln(".........................................do outside");
        do
        {
            writeln(".......................do inside try receive");
            rec_size = client.receive(rec_buf); //, current_max_size);
            writeln(".......................do inside done receive");
            //Thread.sleep(1000.msecs);
            string reply = cast(string) rec_buf.idup;
            writeln(reply);
            writeln(".......................do inside reply");
            writeln(".......................do inside sleep");
            ++count;
        }
        while (rec_size < 0);
    }
    while (client.isAlive() && count < max_count);

    writeln("END MY TEST...............................................................................................................");
}
