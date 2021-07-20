module tagion.Options;

import JSON = std.json;
import std.format;
import std.traits;
import std.file;
import std.getopt;
import std.array : join;
import std.string : strip;

//import stdio=std.stdio;
import tagion.basic.Basic : basename, DataFormat;
import tagion.basic.TagionExceptions;
import tagion.Keywords : NetworkMode, ValidNetwrokModes;
import tagion.basic.Logger : LoggerType;

/++
+/
@safe class OptionException : TagionException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure
    {
        super(msg, file, line);
    }
}

alias check = Check!OptionException;
// @safe
// void check(bool flag, string msg, string file = __FILE__, size_t line = __LINE__) {
//     if (!flag) {
//         throw new OptionException(msg, file, line);
//     }
// }

/++
 mixin for implememts a JSON interface for a struct
+/
mixin template JSONCommon()
{
    /++
     Returns:
     JSON of the struct
     +/
    JSON.JSONValue toJSON() const
    {
        JSON.JSONValue result;
        foreach (i, m; this.tupleof)
        {
            enum name = basename!(this.tupleof[i]);
            alias type = typeof(m);
            static if (is(type == struct))
            {
                result[name] = m.toJSON;
            }
            else
            {
                static if (is(type : immutable(ubyte[])))
                {
                    result[name] = m.toHexString;
                }
                else
                {
                    result[name] = m;
                }
            }
        }
        return result;
    }

    /++
     Stringify the struct
     Params:
     pretty = if true the return string is prettified else the string returned is compact
     +/
    string stringify(bool pretty = true)() const
    {
        static if (pretty)
        {
            return toJSON.toPrettyString;
        }
        else
        {
            return toJSON.toString;
        }
    }

    /++
     Intialize a struct from a JSON
     Params:
     json_value = JSON used
     +/
    private void parse(ref JSON.JSONValue json_value)
    {
        foreach (i, ref m; this.tupleof)
        {
            enum name = basename!(this.tupleof[i]);
            alias type = typeof(m);
            static if (is(type == struct))
            {
                m.parse(json_value[name]);
            }
            else static if (is(type == enum))
            {
            TypeCase:
                switch (json_value[name].str)
                {
                    foreach (E; EnumMembers!type)
                    {
                        enum E_text = strip(E.stringof, `"`);
                case E_text:
                        m = E;
                        break TypeCase;
                    }
                default:
                    string _EnumList()
                    {
                        string[] enum_list;
                        static foreach (i, E; EnumMembers!type)
                        {
                            enum_list ~= E.stringof;
                        }
                        if (enum_list.length is 1)
                        {
                            return enum_list[0];
                        }
                        else
                        {
                            return format!("%s and %s")(enum_list[0 .. $ - 1].join(", "),
                                    enum_list[$ - 1]);
                        }
                    }

                    enum EnumList = _EnumList;
                    check(0, format("Illegal value of %s only %s supported not %s",
                            name, EnumList, json_value[name].str));
                }
            }
            else static if (is(type == string))
            {
                m = json_value[name].str;
            }
            else static if (isIntegral!type || isFloatingPoint!type)
            {
                static if (isIntegral!type)
                {
                    auto value = json_value[name].integer;
                }
                else
                {
                    auto value = json_value[name].floating;
                }
                check((value >= type.min) && (value <= type.max),
                        format("Value %d out of range for type %s of %s",
                            value, type.stringof, m.stringof));
                m = cast(type) value;

            }
            else static if (is(type == bool))
            {
                check((json_value[name].type == JSON.JSONType.true_)
                        || (json_value[name].type == JSON.JSONType.false_),
                        format("Type %s expected for %s but the json type is %s",
                            type.stringof, m.stringof, json_value[name].type));
                m = json_value[name].type == JSON.JSONType.true_;
            }
            else
            {
                check(0, format("Unsupported type %s for %s member", type.stringof, m.stringof));
            }
        }
    }

}

/++
 Options for the network
+/
struct Options
{
    struct Host
    {
        ulong timeout;
        uint max_size;
        mixin JSONCommon;
    }

    Host host;

    uint nodes; /// Number of concurrent nodes (Test mode)

    uint seed; /// Random seed for pseudo random sequency (Test mode)

    uint delay; /// Delay between heart-beats in ms (Test mode)
    uint timeout; /// Timeout for between nodes
    uint loops; /// Number of heart-beats until the program stops (Test mode)

    bool infinity; /// Runs forever

    string url; /// URL to be used for the sockets
    bool trace_gossip; /// Enable the package dump for the transeived packagies
    string tmp; /// Directory for the trace files etc.
    string stdout; /// Overwrites the standard output

    //bool sequential;       /// Sequential test mode, used to replace the same graph from a the seed value

    string separator; /// Name separator
    string nodeprefix; /// Node name prefix used in emulator mode to set the node name and generate keypairs
    string logext; /// logfile extension
    string path_arg; /// Search path
    uint node_id; /// This is use to set the node_id in emulator mode in normal node this is allways 0
    string node_name; /// Name of the node
    string ip;
    ulong port;
    ulong port_base;
    ushort min_port; /// Minum value of the port number
    string path_to_shared_info;
    bool p2plogs;
    uint scrap_depth;

    string net_mode;
    mixin JSONCommon;

    struct HostBootstrap
    {
        bool enabled;
        ulong check_timeout;
        string bootstrapNodes;

        mixin JSONCommon;
    }

    HostBootstrap hostbootrap;

    struct ServerFileDiscovery
    {
        string url;
        ulong delay_before_start;
        ulong update;
        string tag;
        string token;
        string task_name;

        mixin JSONCommon;
    }

    ServerFileDiscovery serverFileDiscovery;

    struct Discovery
    {
        string protocol_id;
        string task_name;
        Host host;
        ulong delay_before_start;
        ulong interval;
        bool notify_enabled;
        mixin JSONCommon;
    }

    Discovery discovery;

    struct Heatbeat
    {
        string task_name; /// Name of the Heart task
        mixin JSONCommon;
    }

    Heatbeat heartbeat;

    struct SSLService
    {
        string task_name; /// Task name of the SSLService used
        string response_task_name; /// Name of the respose task name (If this is not set the respose service is not started)
        string prefix;
        string address; /// Ip address
        ushort port; /// Port
        uint max_buffer_size; /// Max buffer size
        uint max_queue_length; /// Listener max. incomming connection req. queue length

        uint max_connections; /// Max simultanious connections for the scripting engine

        //        uint   max_number_of_accept_fibers;        /// Max simultanious fibers for accepting incomming SSL connections.

        //        uint   min_duration_full_fibers_cycle_ms; /// Min duration between a full call cycle for all fibers in milliseconds;

        //        uint   max_number_of_fiber_reuse;   /// Number of times to reuse a fiber

        //        uint min_number_of_fibers;
        //        uint min_duration_for_accept_ms;
        uint select_timeout; /// Select timeout in ms
        string certificate; /// Certificate file name
        string private_key; /// Private key
        uint client_timeout; /// Client timeout
        // string name;
        // uint max_accept_call_tries() const pure {
        //     const tries = min_duration_for_accept_ms / min_duration_full_fibers_cycle_ms;
        //     return tries > 1 ? tries : 2;
        // }

        mixin JSONCommon;
    }

    //SSLService scripting_engine;

    struct Transcript
    {
        string task_name; /// Name of the transcript service
        // This maybe removed later used to make internal transaction test without TLS connection
        // bool enable;

        uint pause_from; // Sets the from/to delay between transaction test
        uint pause_to;
        string prefix;

        bool epoch_debug;
        mixin JSONCommon;
    }

    Transcript transcript;

    struct Monitor
    {
        string task_name; /// Use for the montor task name
        string prefix;
        uint max; /++ Maximum number of monitor sockets open
                              If this value is set to 0
                              one socket is opened for each node
                              +/
        ushort port; /// Monitor port
        uint timeout; /// Socket listerne timeout in msecs
        DataFormat dataformat;
        /++ This specifies the data-format which is transmitted from the Monitor
         Option is json or hibon
        +/
        mixin JSONCommon;
    }

    Monitor monitor;

    struct Transaction
    {
        string protocol_id;
        string task_name; /// Transaction task name
        string net_task_name;
        string prefix;
        uint timeout; /// Socket listerne timeout in msecs
        SSLService service; /// SSL Service used by the transaction service
        Host host;
        ushort max; // max == 0 means all
        mixin JSONCommon;
    }

    Transaction transaction;

    struct DART
    {
        string task_name; /// Name of the DART service
        string protocol_id;
        Host host;
        string name;
        string prefix;
        string path;
        ushort from_ang;
        ushort to_ang;
        ubyte ringWidth;
        int rings;
        bool initialize;
        bool generate;
        bool synchronize;
        bool angle_from_port;
        bool request;
        bool fast_load;
        ulong tick_timeout;
        bool master_from_port;

        struct Synchronize
        {
            ulong maxSlaves;
            ulong maxMasters;
            ulong maxSlavePort;
            ushort netFromAng;
            ushort netToAng;
            ulong tick_timeout;
            ulong replay_tick_timeout;
            string task_name;
            string protocol_id;

            uint attempts;

            bool master_angle_from_port;
            uint max_handlers;

            Host host;
            mixin JSONCommon;
        }

        Synchronize sync;

        struct Subscribe
        {
            ulong master_port;
            Host host;
            string master_task_name;
            string slave_task_name;
            string protocol_id;
            ulong tick_timeout;
            mixin JSONCommon;
        }

        Subscribe subs;

        struct Commands
        {
            ulong read_timeout;
            mixin JSONCommon;
        }

        Commands commands;

        mixin JSONCommon;
    }

    DART dart;

    struct Logger
    {
        string task_name; /// Name of the logger task
        string file_name; /// File used for the logger
        bool flush; /// Will automatic flush the logger file when a message has been received
        bool to_console; /// Will duplicate logger information to the console
        uint mask; /// Logger mask
        mixin JSONCommon;
    }

    Logger logger;

    struct Message
    {
        string language; /// Language used to print message
        bool update; /// Update the translation tabel
        enum default_lang = "en";
        mixin JSONCommon;
    }

    Message message;

    void parseJSON(string json_text)
    {
        auto json = JSON.parseJSON(json_text);
        parse(json);
    }

    void load(string config_file)
    {
        if (config_file.exists)
        {
            auto json_text = readText(config_file);
            parseJSON(json_text);
        }
        else
        {
            save(config_file);
        }
    }

    void save(string config_file)
    {
        config_file.write(stringify);
    }

}

protected static Options options_memory;
static immutable(Options*) options;

shared static this()
{
    options = cast(immutable)(&options_memory);
}

//@trusted
/++
+  Sets the thread global options opt
+/
@safe static void setOptions(ref const(Options) opt)
{
    options_memory = opt;
}

/++
+ Returns:
+     a copy of the options
+/
static Options getOptions()
{
    Options result = options_memory;
    return result;
}

struct TransactionMiddlewareOptions
{
    // port for the socket
    ushort port;
    // address for the socket
    string address;
    //  port for the socket to the tagion network
    ushort network_port;
    //  address for the socket to the tagion network
    string network_address;

    string logext;
    string logname;
    string logpath;

    mixin JSONCommon;

    void parseJSON(string json_text)
    {
        auto json = JSON.parseJSON(json_text);
        parse(json);
    }

    void load(string config_file)
    {
        if (config_file.exists)
        {
            auto json_text = readText(config_file);
            parseJSON(json_text);
        }
        else
        {
            save(config_file);
        }
    }

    void save(string config_file)
    {
        config_file.write(stringify);
    }

}

//__gshared static TransactionMiddlewareOptions transaction_middleware_options;

static ref auto all_getopt(ref string[] args, ref bool version_switch,
        ref bool overwrite_switch, ref scope Options options)
{
    import std.getopt;
    import std.algorithm;
    import std.conv;

    return getopt(// dfmt off
        args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "version",   "display the version",     &version_switch,
        "overwrite|O", "Overwrite the config file", &overwrite_switch,
//        "transcript-enable|T", format("Transcript test enable: default: %s", options.transcript.enable), &(options.transcript.enable),
        "transaction-max|D",    format("Transaction max = 0 means all nodes: default %d", options.transaction.max),  &(options.transaction.max),
        "ip", "Host ip", &(options.ip),
        "port", "Host port", &(options.port),
        "path|I",    "Sets the search path",     &(options.path_arg),
        "trace-gossip|g",    "Sets the search path",     &(options.trace_gossip),
        "nodes|N",   format("Sets the number of nodes: default %d", options.nodes), &(options.nodes),
        "seed",      format("Sets the random seed: default %d", options.seed),       &(options.seed),
        "timeout|t", format("Sets timeout: default %d (ms)", options.timeout), &(options.timeout),
        "delay|d",   format("Sets delay: default: %d (ms)", options.delay), &(options.delay),
        "loops",     format("Sets the loop count (loops=0 runs forever): default %d", options.loops), &(options.loops),
        "url",       format("Sets the url: default %s", options.url), &(options.url),
//        "noserv|n",  format("Disable monitor sockets: default %s", options.monitor.disable), &(options.monitor.disable),
        "sockets|M", format("Sets maximum number of monitors opened: default %s", options.monitor.max), &(options.monitor.max),
        "tmp",       format("Sets temporaty work directory: default '%s'", options.tmp), &(options.tmp),
        "monitor|P",    format("Sets first monitor port of the port sequency (port>=%d): default %d", options.min_port, options.monitor.port),  &(options.monitor.port),
        // "transaction|p",    format("Sets first transaction port of the port sequency (port>=%d): default %d", options.min_port, options.transaction.port),  &(options.transaction.port),
//        "seq|s",     format("The event is produced sequential this is only used in test mode: default %s", options.sequential), &(options.sequential),
        "stdout",    format("Set the stdout: default %s", options.stdout), &(options.stdout),

        "transaction-ip",  format("Sets the listener ip address: default %s", options.transaction.service.address), &(options.transaction.service.address),
        "transaction-port|p", format("Sets the listener port: default %d", options.transaction.service.port), &(options.transaction.service.port),
        "transaction-queue", format("Sets the listener max queue lenght: default %d", options.transaction.service.max_queue_length), &(options.transaction.service.max_queue_length),
        "transaction-maxcon",  format("Sets the maximum number of connections: default: %d", options.transaction.service.max_connections), &(options.transaction.service.max_connections),
        "transaction-maxqueue",  format("Sets the maximum queue length: default: %d", options.transaction.service.max_queue_length), &(options.transaction.service.max_queue_length),

//        "transaction-maxfibres",  format("Sets the maximum number of fibres: default: %d", options.transaction.service.max_number_of_accept_fibers), &(options.transaction.service.max_number_of_accept_fibers),
//        "transaction-maxreuse",  format("Sets the maximum number of fibre reuse: default: %d", options.transaction.service.max_number_of_fiber_reuse), &(options.transaction.service.max_number_of_fiber_reuse),
        //   "transaction-log",  format("Scripting engine log filename: default: %s", options.transaction.service.name), &(options.transaction.service.name),


        "transcript-from", format("Transcript test from delay: default: %d", options.transcript.pause_from), &(options.transcript.pause_from),
        "transcript-to", format("Transcript test to delay: default: %d", options.transcript.pause_to), &(options.transcript.pause_to),
        "transcript-log",  format("Transcript log filename: default: %s", options.transcript.task_name), &(options.transcript.task_name),
        "transcript-debug|e", format("Transcript epoch debug: default: %s", options.transcript.epoch_debug), &(options.transcript.epoch_debug),
        "dart-filename", format("Dart file name. Default: %s", options.dart.path), &(options.dart.path),
        "dart-synchronize", "Need synchronization", &(options.dart.synchronize),
        "dart-angle-from-port", "Set dart from/to angle based on port", &(options.dart.angle_from_port),
        "dart-master-angle-from-port", "Master angle based on port ", &(options.dart.sync.master_angle_from_port),

        "dart-init", "Initialize block file", &(options.dart.initialize),
        "dart-generate", "Generate dart with random data", &(options.dart.generate),
        "dart-from", "Dart from angle", &(options.dart.from_ang),
        "dart-to", "Dart to angle", &(options.dart.to_ang),
        "dart-request", "Request dart data", &(options.dart.request),
        "dart-path", "Path to dart file", &(options.dart.path),
        "logger-filename" , format("Logger file name: default: %s", options.logger.file_name), &(options.logger.file_name),
        "logger-mask|l" , format("Logger mask: default: %d", options.logger.mask), &(options.logger.mask),
        "net-mode", format("Network mode: one of [%s]: default: %s", [EnumMembers!NetworkMode].map!(t=>t.to!string).join(", "), options.net_mode), &(options.net_mode),
        "p2p-logger", format("Enable conssole logs for libp2p: default: %s", options.p2plogs), &(options.p2plogs),
        "server-token", format("Token to access shared server"), &(options.serverFileDiscovery.token),
        "server-tag", format("Group tag(should be the same as in token payload)"), &(options.serverFileDiscovery.tag),
//        "help!h", "Display the help text",    &help_switch,
        // dfmt on
    );
};

static setDefaultOption(ref Options options)
{
    // Main

    with (options)
    {
        nodeprefix = "Node";
        ip = "0.0.0.0";
        port = 4001;
        port_base = 4000;
        scrap_depth = 5;
        logext = "log";
        seed = 42;
        delay = 200;
        timeout = delay * 4;
        nodes = 4;
        loops = 30;
        infinity = false;
        url = "127.0.0.1";
        //port=10900;
        //disable_sockets=false;
        tmp = "/tmp/";
        stdout = "/dev/tty";
        separator = "_";
        //  s.network_socket_port =11900;
        //        sequential=false;
        min_port = 6000;
        path_to_shared_info = "/tmp/info.hibon";
        p2plogs = false;
        with (host)
        {
            timeout = 3000;
            max_size = 1024 * 100;
        }
    }

    with (options.heartbeat)
    {
        task_name = "heartbeat";
    }
    with (options.hostbootrap)
    {
        enabled = false;
        check_timeout = 1000;
        bootstrapNodes = "";
    }
    with (options.serverFileDiscovery)
    {
        url = "";
        delay_before_start = 60_000;
        update = 20_000;
        tag = "tag-1";
        token = "";
        task_name = "server_file_discovery";
    }
    // Transcript
    with (options.transcript)
    {
        pause_from = 333;
        pause_to = 888;
        prefix = "transcript";
        task_name = prefix;
    }
    // Transaction
    with (options.transaction)
    {
        //        port=10800;
        max = 0;
        prefix = "transaction";
        task_name = prefix;
        net_task_name = "transaction_net";
        timeout = 250;
        with (service)
        {
            prefix = "transervice";
            task_name = prefix;
            response_task_name = "respose";
            address = "0.0.0.0";
            port = 10_800;
            select_timeout = 300;
            client_timeout = 4000; // msecs
            max_buffer_size = 0x4000;
            max_queue_length = 100;
            max_connections = 1000;
            // max_number_of_accept_fibers = 100;
            // min_duration_full_fibers_cycle_ms = 10;
            //            max_number_of_fiber_reuse = 1000;
            //            min_number_of_fibers = 10;
            //            min_duration_for_accept_ms = 3000;
            certificate = "pem_files/domain.pem";
            private_key = "pem_files/domain.key.pem";
            task_name = "transaction.service";
        }
        with (host)
        {
            timeout = 3000;
            max_size = 1024 * 100;
        }
    }
    // Monitor
    with (options.monitor)
    {
        port = 10900;
        max = 0;
        prefix = "monitor";
        task_name = prefix;
        timeout = 500;
        dataformat = DataFormat.json;
    }
    // Logger
    with (options.logger)
    {
        task_name = "logger";
        file_name = "/tmp/tagion.log";
        flush = true;
        to_console = true;
        mask = LoggerType.ALL;
    }
    // Discovery
    with (options.discovery)
    {
        protocol_id = "tagion_dart_mdns_pid";
        task_name = "discovery";
        delay_before_start = 10_000;
        interval = 400;
        notify_enabled = false;
        with (host)
        {
            timeout = 3000;
            max_size = 1024 * 100;
        }
    }

    // DART
    with (options.dart)
    {
        task_name = "tagion.dart";
        protocol_id = "tagion_dart_pid";
        with (host)
        {
            timeout = 3000;
            max_size = 1024 * 100;
        }
        name = "dart";
        prefix = "dart_";
        path = "";
        from_ang = 0;
        to_ang = 0;
        ringWidth = 3;
        rings = 3;
        initialize = true;
        generate = false;
        synchronize = true;
        request = false;
        fast_load = false;
        angle_from_port = false;
        tick_timeout = 500;
        master_from_port = true;
        with (sync)
        {
            maxMasters = 1;
            maxSlaves = 4;
            maxSlavePort = 4020;
            netFromAng = 0;
            netToAng = 0;
            tick_timeout = 50;
            replay_tick_timeout = 5;
            protocol_id = "tagion_dart_sync_pid";
            task_name = "dart.sync";

            attempts = 20;

            master_angle_from_port = false;

            max_handlers = 20;

            with (host)
            {
                timeout = 3_000;
                max_size = 1024 * 100;
            }
        }

        with (subs)
        {
            master_port = 4030;
            master_task_name = "tagion_dart_subs_master_tid";
            slave_task_name = "tagion_dart_subs_slave_tid";
            protocol_id = "tagion_dart_subs_pid";
            tick_timeout = 500;
            with (host)
            {
                timeout = 3_000_000;
                max_size = 1024 * 100;
            }
        }

        with (commands)
        {
            read_timeout = 10_000;
        }
    }
    if (options.net_mode.length == 0)
    {
        options.net_mode = NetworkMode.internal;
    }
    switch (options.net_mode)
    {
    case NetworkMode.internal:
        {
            options.dart.fast_load = true;
            options.dart.path = "./data/%dir%/dart.drt";
            break;
        }
    case NetworkMode.local:
        {
            options.dart.fast_load = true;
            options.dart.path = "./data/%dir%/dart.drt";
            options.path_to_shared_info = "./shared-data/info.hibon";
            break;
        }
    case NetworkMode.pub:
        {
            options.dart.fast_load = true;
            options.dart.path = "./data/dart.drt";
            options.hostbootrap.enabled = true;
            options.dart.master_from_port = false;
            break;
        }
    default:
        {
            options.net_mode = NetworkMode.internal;
        }
    }
    //    setThreadLocalOptions();
}
