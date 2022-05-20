module tagion.services.Options;

import JSON = std.json;
import std.format;
import std.traits;
import std.file;
import std.path : setExtension;
import std.getopt;
import std.array : join;
import std.string : strip;
import core.time;

import tagion.basic.Types : FileExtension;
import tagion.basic.Basic : basename;
import tagion.basic.TagionExceptions;
import tagion.logger.Logger : LoggerType;
import tagion.utils.JSONCommon;

/++
+/
@safe
class OptionException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

alias check = Check!OptionException;
// @safe

enum NetworkMode {
    internal,
    local,
    pub
}

/++
 Options for the network
+/
struct Options {
    import tagion.options.HostOptions;

    HostOptions host;

    ushort nodes; /// Number of concurrent nodes (Test mode)

    uint seed; /// Random seed for pseudo random sequency (Test mode)

    uint delay; /// Delay between heart-beats in ms (Test mode)
    uint timeout; /// Timeout for between nodes
    uint loops; /// Number of heart-beats until the program stops (Test mode)

    bool infinity; /// Runs forever
    uint node_id; /// This is use to set the node_id in emulator mode in normal node this is allways 0

    bool trace_gossip; /// Enable the package dump for the transeived packagies
    string tmp; /// Directory for the trace files etc.
    string stdout; /// Overwrites the standard output

    //bool sequential;       /// Sequential test mode, used to replace the same graph from a the seed value

    string logext; /// logfile extension
    string pid_file; /// PID file
    string node_name; /// Name of the node
    string ip;
    ulong port;
    ushort port_base;
    ushort min_port; /// Minum value of the port number
    string path_to_shared_info;
    bool p2plogs;
    uint scrap_depth;

    NetworkMode net_mode;
    import tagion.options.CommonOptions;

    CommonOptions common;

    mixin JSONCommon;

    struct HostBootstrap {
        bool enabled;
        ulong check_timeout;
        string bootstrapNodes;

        mixin JSONCommon;
    }

    HostBootstrap hostbootrap;

    struct ServerFileDiscovery {
        string url;
        ulong delay_before_start;
        ulong update;
        string tag;
        string token;
        string task_name;

        mixin JSONCommon;
    }

    ServerFileDiscovery serverFileDiscovery;

    struct Discovery {
        string protocol_id;
        string task_name;
        HostOptions host;
        ulong delay_before_start;
        ulong interval;
        bool notify_enabled;
        mixin JSONCommon;
    }

    Discovery discovery;

    struct Heatbeat {
        string task_name; /// Name of the Heart task
        mixin JSONCommon;
    }

    Heatbeat heartbeat;

    //SSLService scripting_engine;

    struct Transcript {
        string task_name; /// Name of the transcript service
        // This maybe removed later used to make internal transaction test without TLS connection
        // bool enable;

        uint pause_from; // Sets the from/to delay between transaction test
        uint pause_to;
        string prefix;

        bool epoch_debug;
        mixin JSONCommon;
    }

    import tagion.script.TranscriptOptions;

    TranscriptOptions transcript;

    struct Monitor {
        string task_name; /// Use for the montor task name
        string prefix;
        uint max; /++ Maximum number of monitor sockets open
                              If this value is set to 0
                              one socket is opened for each node
                              +/
        ushort port; /// Monitor port
        uint timeout; /// Socket listerne timeout in msecs
        FileExtension dataformat;
        /++ This specifies the data-format which is transmitted from the Monitor
         Option is json or hibon
        +/
        mixin JSONCommon;
    }

    Monitor monitor;

    struct Transaction {
        string protocol_id;
        string task_name; /// Transaction task name
        string net_task_name;
        string prefix;
        uint timeout; /// Socket listerne timeout in msecs
        import tagion.network.SSLOptions;

        SSLOption service; /// SSL Service used by the transaction service
        HostOptions host;
        ushort max; // max == 0 means all
        mixin JSONCommon;
    }

    Transaction transaction;

    struct LogSubscription {
        string protocol_id;
        string task_name; /// Transaction task name
        string net_task_name;
        string prefix;
        uint timeout; /// Socket listerne timeout in msecs
        import tagion.network.SSLOptions;

        SSLOption service; /// SSL Service used by the transaction service
        HostOptions host;
        ushort max; // max == 0 means all
        mixin JSONCommon;
    }

    LogSubscription logSubscription;

    import tagion.dart.DARTOptions;

    DARTOptions dart;

    struct Logger {
        string task_name; /// Name of the logger task
        string file_name; /// File used for the logger
        bool flush; /// Will automatic flush the logger file when a message has been received
        bool to_console; /// Will duplicate logger information to the console
        uint mask; /// Logger mask
        mixin JSONCommon;
    }

    Logger logger;

    struct LoggerSubscription {
        bool enable; // Enable logger subscribtion  service
        mixin JSONCommon;
    }

    LoggerSubscription sub_logger;

    struct Recorder {
        string task_name; /// Name of the recorder task
        string folder_path; /// Folder used for the recorder service files
        mixin JSONCommon;
    }

    Recorder recorder;

    struct Message {
        string language; /// Language used to print message
        bool update; /// Update the translation tabel
        enum default_lang = "en";
        mixin JSONCommon;
    }

    Message message;

    mixin JSONConfig;
}

protected static Options options_memory;
static immutable(Options*) options;

shared static this() {
    options = cast(immutable)(&options_memory);
}

//@trusted
/++
+  Sets the thread global options opt
+/
@safe
static void setOptions(ref const(Options) opt) {
    options_memory = opt;
}

/++
+ Returns:
+     a copy of the options
+/
static Options getOptions() {
    Options result = options_memory;
    return result;
}

struct TransactionMiddlewareOptions {
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

    void parseJSON(string json_text) {
        auto json = JSON.parseJSON(json_text);
        parse(json);
    }

    void load(string config_file) {
        if (config_file.exists) {
            auto json_text = readText(config_file);
            parseJSON(json_text);
        }
        else {
            save(config_file);
        }
    }

    void save(string config_file) {
        config_file.write(stringify);
    }

}

//__gshared static TransactionMiddlewareOptions transaction_middleware_options;

static ref auto all_getopt(
    ref string[] args,
    ref bool version_switch,
    ref bool overwrite_switch,
    ref scope Options options) {
    import std.getopt;
    import std.algorithm;
    import std.conv;

    return getopt(// dfmt off
        args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "version",   "display the version",     &version_switch,
        "overwrite|O", "Overwrite the config file", &overwrite_switch,
        "transaction-max|D",    format("Transaction max = 0 means all nodes: default %d", options.transaction.max),  &(options.transaction.max),
        "ip", "Host gossip ip", &(options.ip),
        "port", "Host gossip port ", &(options.port),
        "pid", format("Write the pid to %s file", options.pid_file), &(options.pid_file),
//      "path|I",    "Sets the search path", &(options.path_arg),
        "trace-gossip|g",    "Sets the search path",     &(options.trace_gossip),
        "nodes|N",   format("Sets the number of nodes: default %d", options.nodes), &(options.nodes),
        "seed",      format("Sets the random seed: default %d", options.seed),       &(options.seed),
        "timeout|t", format("Sets timeout: default %d (ms)", options.timeout), &(options.timeout),
        "delay|d",   format("Sets delay: default: %d (ms)", options.delay), &(options.delay),
        "loops",     format("Sets the loop count (loops=0 runs forever): default %d", options.loops), &(options.loops),
        "url",       format("Sets the url: default %s", options.common.url), &(options.common.url),
        "sockets|M", format("Sets maximum number of monitors opened: default %s", options.monitor.max), &(options.monitor.max),
        "tmp",       format("Sets temporaty work directory: default '%s'", options.tmp), &(options.tmp),
        "monitor|P", format("Sets first monitor port of the port sequency (port>=%d): default %d", options.min_port, options.monitor.port),  &(options.monitor.port),
        "stdout",    format("Set the stdout: default %s", options.stdout), &(options.stdout),

        "transaction-ip",  format("Sets the listener transaction ip address: default %s", options.transaction.service.address), &(options.transaction.service.address),
        "transaction-port|p", format("Sets the listener transcation port: default %d", options.transaction.service.port), &(options.transaction.service.port),
        "transaction-queue", format("Sets the listener transcation max queue lenght: default %d", options.transaction.service.max_queue_length), &(options.transaction.service.max_queue_length),
        "transaction-maxcon",  format("Sets the maximum number of connections: default: %d", options.transaction.service.max_connections), &(options.transaction.service.max_connections),
        "transaction-maxqueue",  format("Sets the maximum queue length: default: %d", options.transaction.service.max_queue_length), &(options.transaction.service.max_queue_length),

//        "transaction-maxfibres",  format("Sets the maximum number of fibres: default: %d", options.transaction.service.max_number_of_accept_fibers), &(options.transaction.service.max_number_of_accept_fibers),
//        "transaction-maxreuse",  format("Sets the maximum number of fibre reuse: default: %d", options.transaction.service.max_number_of_fiber_reuse), &(options.transaction.service.max_number_of_fiber_reuse),
        //   "transaction-log",  format("Scripting engine log filename: default: %s", options.transaction.service.name), &(options.transaction.service.name),


        "transcript-from", format("Transcript test from delay: default: %d", options.transcript.pause_from), &(options.transcript.pause_from),
        "transcript-to", format("Transcript test to delay: default: %d", options.transcript.pause_to), &(options.transcript.pause_to),
        "transcript-log",  format("Transcript log filename: default: %s", options.transcript.task_name), &(options.transcript.task_name),
        "transcript-debug|e", format("Transcript epoch debug: default: %s", options.transcript.epoch_debug), &(options.transcript.epoch_debug),
        "dart-filename", format("DART file name. Default: %s", options.dart.path), &(options.dart.path),
        "dart-synchronize", "Need synchronization", &(options.dart.synchronize),
        "dart-angle-from-port", "Set dart from/to angle based on port", &(options.dart.angle_from_port),
        "dart-master-angle-from-port", "Master angle based on port ", &(options.dart.sync.master_angle_from_port),

        "dart-init", "Initialize block file", &(options.dart.initialize),
        "dart-generate", "Generate dart with random data", &(options.dart.generate),
        "dart-from", "DART from angle", &(options.dart.from_ang),
        "dart-to", "DART to angle", &(options.dart.to_ang),
        "dart-request", "Request dart data", &(options.dart.request),
        "dart-path", "Path to dart file", &(options.dart.path),
        "logger-filename" , format("Logger file name: default: %s", options.logger.file_name), &(options.logger.file_name),
        "logger-mask|l" , format("Logger mask: default: %d", options.logger.mask), &(options.logger.mask),
        "logsub|L" , format("Logger subscription service enabled: default: %d", options.sub_logger.enable), &(options.sub_logger.enable),
        "net-mode", format("Network mode: one of [%s]: default: %s", [EnumMembers!NetworkMode].map!(t=>t.to!string).join(", "), options.net_mode), &(options.net_mode),
        "p2p-logger", format("Enable conssole logs for libp2p: default: %s", options.p2plogs), &(options.p2plogs),
        "server-token", format("Token to access shared server"), &(options.serverFileDiscovery.token),
        "server-tag", format("Group tag(should be the same as in token payload)"), &(options.serverFileDiscovery.tag),
        "boot", format("Shared boot file: default: %s", options.path_to_shared_info), &(options.path_to_shared_info),
//        "help!h", "Display the help text",    &help_switch,
        // dfmt on



    );
}

static setDefaultOption(ref Options options) {
    // Main

    with (options) {
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
        //port=10900;
        //disable_sockets=false;
        tmp = "/tmp/";
        stdout = "/dev/tty";
        //  s.network_socket_port =11900;
        //        sequential=false;
        min_port = 6000;
        path_to_shared_info = "/tmp/boot.hibon";
        p2plogs = false;
        with (host) {
            timeout = 3000;
            max_size = 1024 * 100;
        }
        with (common) {
            nodeprefix = "Node";
            separator = "_";
            url = "127.0.0.1";
        }
    }

    with (options.heartbeat) {
        task_name = "heartbeat";
    }
    with (options.hostbootrap) {
        enabled = false;
        check_timeout = 1000;
        bootstrapNodes = "";
    }
    with (options.serverFileDiscovery) {
        url = "";
        delay_before_start = 60_000;
        update = 20_000;
        tag = "tag-1";
        token = "";
        task_name = "server_file_discovery";
    }
    // Transcript
    with (options.transcript) {
        pause_from = 333;
        pause_to = 888;
        task_name = "transcript";
    }
    // Transaction
    with (options.transaction) {
        //        port=10800;
        max = 0;
        prefix = "transaction";
        task_name = prefix;
        net_task_name = "transaction_net";
        timeout = 250;
        with (service) {
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
            with (openssl) {
                certificate = "pem_files/domain.pem";
                private_key = "pem_files/domain.key.pem";
                days = 365;
                key_size = 4096;
            }
            task_name = "transaction.service";
        }
        with (host) {
            timeout = 3000;
            max_size = 1024 * 100;
        }
    }
    // LogSubscription
    with (options.logSubscription) {
        //        port=10700;
        max = 0;
        prefix = "logsubscription";
        task_name = prefix;
        net_task_name = "logsubscription_net";
        timeout = 10000;
        with (service) {
            prefix = "logsubscriptionservice";
            task_name = prefix;
            response_task_name = "respose";
            address = "0.0.0.0";
            port = 10_700;
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
            with (openssl) {
                certificate = "pem_files/domain.pem";
                private_key = "pem_files/domain.key.pem";
                days = 365;
                key_size = 4096;
            }
        }
        with (host) {
            timeout = 3000;
            max_size = 1024 * 100;
        }
    }
    // Monitor
    with (options.monitor) {
        port = 10900;
        max = 0;
        prefix = "monitor";
        task_name = prefix;
        timeout = 500;
        dataformat = FileExtension.json;
    }
    // Logger
    with (options.logger) {
        task_name = "logger";
        file_name = "/tmp/tagion.log";
        flush = true;
        to_console = true;
        mask = LoggerType.ALL;
    }
    // Recorder
    with (options.recorder) {
        task_name = "recorder";
        folder_path = "tmp/epoch_blocks/";
    }
    // Discovery
    with (options.discovery) {
        protocol_id = "tagion_dart_mdns_pid";
        task_name = "discovery";
        delay_before_start = 10_000;
        interval = 400;
        notify_enabled = false;
        with (host) {
            timeout = 3000;
            max_size = 1024 * 100;
        }
    }

    // DART
    with (options.dart) {
        task_name = "tagion.dart";
        protocol_id = "tagion_dart_pid";
        with (host) {
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
        with (sync) {
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

            with (host) {
                timeout = 3_000;
                max_size = 1024 * 100;
            }
        }

        with (subs) {
            master_port = 4030;
            master_task_name = "tagion_dart_subs_master_tid";
            slave_task_name = "tagion_dart_subs_slave_tid";
            protocol_id = "tagion_dart_subs_pid";
            tick_timeout = 500;
            with (host) {
                timeout = 3_000_000;
                max_size = 1024 * 100;
            }
        }

        with (commands) {
            read_timeout = 10_000;
        }
    }
    // if (options.net_mode.length == 0) {
    //     options.net_mode = NetworkMode.internal;
    // }
    with (NetworkMode) {
        final switch (options.net_mode) {
        case internal:
            options.dart.fast_load = true;
            options.dart.path = "./data/%dir%/dart".setExtension(FileExtension.dart);
            break;
        case local:
            options.dart.fast_load = true;
            options.dart.path = "./data/%dir%/dart".setExtension(FileExtension.dart);
            options.path_to_shared_info = "./shared-data/boot".setExtension(FileExtension.hibon);
            break;
        case pub:
            options.dart.fast_load = true;
            options.dart.path = "./data/dart".setExtension(FileExtension.dart);
            options.hostbootrap.enabled = true;
            options.dart.master_from_port = false;
            break;
        }
    }
    //    setThreadLocalOptions();
}
static struct DefaultOptions { //TODO: moveout to static options in tagion  + param(miliseconds)
static:
    Duration timeout = 100.seconds;
    int maxSize = 1024 * 10;
    Duration mdnsInterval = 10.seconds;
}

//alias Buffer = immutable(ubyte[]);



