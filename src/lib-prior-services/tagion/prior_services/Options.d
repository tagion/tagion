module tagion.prior_services.Options;

import JSON = std.json;
import std.format;
import std.traits;
import std.file;
import std.path : setExtension;
import std.getopt;
import std.array : join;
import std.string : strip;

import tagion.basic.Types : FileExtension;
import tagion.basic.basic : basename;
import tagion.basic.tagionexceptions;
import tagion.logger.Logger : LogLevel;
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

    bool infinity; /// Runs forever
    uint node_id; /// This is use to set the node_id in emulator mode in normal node this is allways 0

    bool trace_gossip; /// Enable the package dump for the transeived packagies
    string tmp; /// Directory for the trace files etc.

    //bool sequential;       /// Sequential test mode, used to replace the same graph from a the seed value

    string logext; /// logfile extension
    string pid_file; /// PID file
    string node_name; /// Name of the node
    string ip;
    ulong port;
    ushort port_base;
    ushort min_port; /// Minum value of the port number
    string path_to_shared_info;
    string path_to_stored_passphrase;
    bool p2plogs;
    uint scrap_depth;
    uint epoch_limit; /// The round until it has produced epoch_limit
    NetworkMode net_mode;
    import tagion.options.CommonOptions;

    uint startup_delay;

    CommonOptions common;

    mixin JSONCommon;

    struct EpochDumpSettings {
        string task_name;
        string transaction_dumps_directory;
        bool enabled;
        mixin JSONCommon;
    }

    EpochDumpSettings epoch_dump;

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

    /** \struct TranscriptOptions
     * Options for Transcript service
     */
    struct TranscriptOptions {
        /** Name of the transcript service */
        string task_name;

        mixin JSONCommon;
    }

    TranscriptOptions transcript;

    struct Monitor {
        string task_name; /// Use for the montor task name
        string prefix;
        bool enable; /// When enabled the Monitor is started
        uint max; /++ Maximum number of monitor.service.server. open
                              If this value is set to 0
                              one.service.server.is opened for each node
                              +/
        ushort port; /// Monitor port
        uint timeout; ///.service.server.listerne timeout in msecs
        FileExtension dataformat;
        /++ This specifies the data-format which is transmitted from the Monitor
         Option is json or hibon
        +/
        mixin JSONCommon;
    }
    // ContactCollector collector;

    Monitor monitor;

    struct Transaction {
        string protocol_id;
        string task_name; /// Transaction task name
        ushort max;
        mixin JSONCommon;
    }

    Transaction transaction;

    struct ContractCollector {
        string task_name; /// Transaction task name
        mixin JSONCommon;
    }

    ContractCollector collector;

    struct LogSubscription {
        string protocol_id;
        string task_name; /// Transaction task name
        //        string prefix;
        //    uint timeout; ///.service.server.listerne timeout in msecs
        ushort max; // max == 0 means all
        bool enable; // Enable logger subscribtion  service
        mixin JSONCommon;
    }

    LogSubscription logsubscription;

    import tagion.prior_services.DARTOptions;

    DARTOptions dart;

    struct Logger {
        string task_name; /// Name of the logger task
        string file_name; /// File used for the logger
        bool flush; /// Will automatic flush the logger file when a message has been received
        bool to_console; /// Will duplicate logger information to the console
        uint mask; /// Logger mask
        uint trunc_size; /// Truct size in bytes (if zero the logger file is not truncated)
        mixin JSONCommon;
    }

    Logger logger;

    struct RecorderChain {
        string task_name; /// Name of the recorder task
        string folder_path; /// Folder used for the recorder service files, default empty path means this feature is disabled
        bool enabled;
        mixin JSONCommon;
    }

    RecorderChain recorder_chain;

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
    //  port for the.service.server.to the tagion network
    ushort network_port;
    //  address for the.service.server.to the tagion network
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
        "transaction-max|D",    format("Transaction max = 0 means all nodes: default %d", 
	options.transaction.max),  &(options.transaction.max),
        "ip", "Host gossip ip", &(options.ip),
        "port", "Host gossip port ", &(options.port),
        "pid", format("Write the pid to %s file", options.pid_file), &(options.pid_file),
        "nodes|N",   format("Sets the number of nodes: default %d", options.nodes), &(options.nodes),
        "timeout|t", format("Sets timeout: default %d (ms)", options.timeout), &(options.timeout),
//        "monitors|M", format("Sets maximum number of monitors opened: default %d", 
//    options.monitor.max), &(options.monitor.max),
        "tmp", format("Sets temporaty work directory: default '%s'", options.tmp), &(options.tmp),
        "monitor-port|P", format("Sets first monitor port of the port sequency: default %d", 
		options.monitor.port),  &(options.monitor.port),
       "monitor|M", format("Enable the HashGraph monitor: default %s", options.monitor.enable), 
   &(options.monitor.enable), 

        "epochs",  format("Sets the number of epochs (0 for infinite): default: %d", 
	options.epoch_limit), &(options.epoch_limit),

        "transcript-log",  format("Transcript log filename: default: %s", 
	options.transcript.task_name), &(options.transcript.task_name),
        "dart-filename", format("DART file name. Default: %s", options.dart.path), &(options.dart.path),
        "dart-synchronize", "Need synchronization", &(options.dart.synchronize),

        "dart-init", "Initialize block file", &(options.dart.initialize),
        "dart-path", "Path to dart file", &(options.dart.path),
        "logger-filename" , format("Logger file name: default: %s", options.logger.file_name), &(options.logger.file_name),
        "logger-mask|l" , format("Logger mask: default: %d", options.logger.mask), &(options.logger.mask),
        "logger-size", format("Max size of the logger file (zero means no limit)"), &options.logger.trunc_size,
        "logsub|L" , format("Logger subscription service enabled: default: %d", options.logsubscription.enable), &(options.logsubscription.enable),
        "net-mode", format("Network mode: one of [%s]: default: %s", [EnumMembers!NetworkMode].map!(t=>t.to!string).join(", "), options.net_mode), &(options.net_mode),
        "p2p-logger", format("Enable conssole logs for libp2p: default: %s", options.p2plogs), &(options.p2plogs),
        "boot", format("Shared boot file: default: %s", options.path_to_shared_info), &(options.path_to_shared_info),
        "passphrasefile", "File with setted passphrase for keys pair", &(options.path_to_stored_passphrase),
        "recorderchain", "Path to folder with recorder chain blocks stored for DART recovery", &(options.recorder_chain.folder_path),
        "transactiondumpfolder", "Set separative folder for transaction dump", &(options.epoch_dump.transaction_dumps_directory),
        "startup-dalay", format("Set a delay before node will start following hashgraph: default: %d ms", options.startup_delay), &(options.startup_delay) 
    );
}

static setDefaultOption(ref Options options)
{
    // Main

    with (options)
    {
        ip = "0.0.0.0";
        port = 4001;
        port_base = 4000;
        scrap_depth = 5;
        logext = "log";
        timeout = 800;
        epoch_limit = uint.max;

        nodes = 4;
        infinity = false;
        //port=10900;
        //disable.service.server.=false;
        tmp = "/tmp/";
        //  s.network.service.server.port =11900;
        //        sequential=false;
        min_port = 6000;
        path_to_shared_info = "/tmp/boot.hibon";
        p2plogs = false;
        startup_delay = 500;
        with (host)
        {
            timeout = 3000;
            max_size = 1024 * 100;
        }
        with (common)
        {
            nodeprefix = "Node";
            separator = "_";
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
        task_name = "transcript";
    }
    // Transaction
    with (options.transaction)
    {
        max = 0;
        task_name = "transaction";
    }
    with (options.transaction)
    {
        task_name = "collector";
    }
    // LogSubscription
    with (options.logsubscription)
    {
        max = 0;
        task_name = "logsubscription";
        enable = false;
    }
    // Monitor
    with (options.monitor)
    {
        port = 10900;
        max = 0;
        prefix = "monitor";
        task_name = prefix;
        timeout = 500;
        dataformat = FileExtension.json;
    }
    // Logger
    with (options.logger)
    {
        task_name = "logger";
        file_name = "/tmp/tagion.log";
        flush = true;
        to_console = true;
        mask = LogLevel.ALL;
    }
    // Recorder
    with (options.recorder_chain)
    {
        task_name = "recorder-service";
        enabled = false;
    }
    // Epoch dumping
    with(options.epoch_dump)
    {
        task_name = "epoch-dump-task";
        enabled = false;
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
        initialize = true;
        synchronize = false;
        fast_load = false;
        tick_timeout = 500;
        with (sync)
        {
            tick_timeout = 50;
            reply_tick_timeout = 5;
            protocol_id = "tagion_dart_sync_pid";
            task_name = "dart.sync";

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
    with (NetworkMode)
    {
        final switch (options.net_mode)
        {
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
            break;
        }
    }
}

__gshared string main_task;
