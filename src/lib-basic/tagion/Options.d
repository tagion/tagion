module tagion.Options;


import JSON=std.json;
import std.format;
import std.traits;
import std.file;
import std.getopt;

import tagion.Base : basename;

@safe
class OptionException : Exception {
    this( string msg, string file = __FILE__, size_t line = __LINE__ ) {
        super(msg, file, line );
    }
}

@safe
void check(bool flag, string msg, string file = __FILE__, size_t line = __LINE__) {
    if (!flag) {
        throw new OptionException(msg, file, line);
    }
}

mixin template JSONCommon() {
    JSON.JSONValue toJSON() const {
        JSON.JSONValue result;
        foreach(i, m; this.tupleof) {
            enum name=basename!(this.tupleof[i]);
            alias type=typeof(m);
            static if (is(type==struct)) {
                result[name]=m.toJSON;
            }
            else {
                static if ( is(type : immutable(ubyte[])) ) {
                    result[name]=m.toHexString;
                }
                else {
                    result[name]=m;
                }
            }
        }
        return result;
    }

    string stringify(bool pretty=true)() const {
        static if (pretty) {
            return toJSON.toPrettyString;
        }
        else {
            return toJSON.toString;
        }
    }

    private void parse(ref JSON.JSONValue json_value) {
        foreach(i, m; this.tupleof) {
            enum name=basename!(this.tupleof[i]);
            alias type=typeof(m);
            static if (is(type==struct)) {
                m.parse(json_value[name]);
            }
            else static if (is(type==string)) {
                m=json_value[name].str;
            }
            else static if (isIntegral!type || isFloatingPoint!type) {
                static if (isIntegral!type) {
                    auto value=json_value[name].integer;
                }
                else {
                    auto value=json_value[name].floating;
                }
                check((value >= type.min) && (value <= type.max), format("Value %d out of range for type %s of %s", value, type.stringof, m.stringof ));
                m=cast(type)value;
            }
            else static if (is(type==bool)) {
                check((json_value[name].type == JSON.JSON_TYPE.TRUE) || (json_value[name].type == JSON.JSON_TYPE.FALSE),
                    format("Type %s expected for %s but the json type is %s", type.stringof, m.stringof, json_value[name].type));
                m=json_value[name].type == JSON.JSON_TYPE.TRUE;
            }
            else {
                assert(0, format("Unsupported type %s for %s member", type.stringof, m.stringof));
            }
        }
    }

}

struct Options {
    uint nodes;     /// Number of concurrent nodes (Test mode)

    uint max_monitors;     /++ Maximum number of monitor sockets open
                            If this value is set to 0
                            one socket is opened for each node
                            +/

    uint seed;             /// Random seed for pseudo random sequency (Test mode)

    uint delay;            /// Delay between heart-beats in ms (Test mode)
    uint timeout;          /// Timeout for between nodes
    uint loops;            /// Number of heart-beats until the program stops (Test mode)


    bool infinity;         /// Runs forever

//    uint port;             /// The port number of the first socket port
    string url;            /// URL to be used for the sockets
    bool trace_gossip;     /// Enable the package dump for the transeived packagies
    string tmp;            /// Directory for the trace files etc.
    string stdout;         /// Overwrites the standard output

//    ushort network_socket_port;     /// Port for network socket
    bool sequential;       /// Sequential test mode, used to replace the same graph from a the seed value

    string separator;      /// Name separator
    string nodeprefix;     /// Node name prefix used in emulator mode to set the node name and generate keypairs
    string logext;         /// logfile extension
    string path_arg;       /// Search path
    uint node_id;          /// This is use to set the node_id in emulator mode in normal node this is allways 0
    string node_name;      /// Name of the node

    mixin JSONCommon;

    struct ScriptingEngine {
        string task_name;
        string listener_ip_address;       /// Ip address
        ushort listener_port;             /// Port
        uint listener_max_queue_length;   /// Listener max. incomming connection req. queue length

        uint max_connections;             /// Max simultanious connections for the scripting engine

        uint max_number_of_accept_fibers;        /// Max simultanious fibers for accepting incomming SSL connections.

        uint min_duration_full_fibers_cycle_ms; /// Min duration between a full call cycle for all fibers in milliseconds;

        uint max_number_of_fiber_reuse;   /// Number of times to reuse a fiber

        string tmp_debug_dir;             /// Directory to dump bson data

        string tmp_debug_bills_filename;  /// Name of bills file for debug bson dump

        string name;                      /// Scripting engine name used for log filename etc.

        uint min_number_of_fibers;
        uint min_duration_for_accept_ms;

        uint max_accept_call_tries() const pure {
            const tries = min_duration_for_accept_ms / min_duration_full_fibers_cycle_ms;
            return tries > 1 ? tries : 2;
        }

        mixin JSONCommon;
    }

    ScriptingEngine scripting_engine;

    struct Transcript {
        string task_name;
        // This maybe removed later used to make internal transaction test without TLS connection
        bool enable;

        uint pause_from; // Sets the from/to delay between transaction test
        uint pause_to;

        // Scripting api log filename
        // Scripting api name used for log filename etc.
        string name;

        mixin JSONCommon;
    }

    Transcript transcript;

    struct Monitor {
        string task_name;
        uint max;     /++ Maximum number of monitor sockets open
                       If this value is set to 0
                       one socket is opened for each node
                       +/
        ushort port; /// Monitor port
        bool disable; /// Disable monitor
        string name;  /// Use for the montor task name
        mixin JSONCommon;
    }

    Monitor monitor;

    struct Transaction {
        string task_name;
        string name;
        ushort port;
        ushort max;
        bool disable;
        mixin JSONCommon;
    }

    Transaction transaction;

    struct DART {
        string task_name;
        string name;
        string path;
        // ushort port;
        // ushort max;
        // bool disable;
        mixin JSONCommon;
    }

    DART dart;

    struct Logger {
        string task_name;
        string file_name;
        mixin JSONCommon;
    }

    Logger logger;

    void parseJSON(string json_text) {
        auto json=JSON.parseJSON(json_text);
        parse(json);
    }

    void load(string config_file) {
        if (config_file.exists) {
            auto json_text=readText(config_file);
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

//__gshared protected static Options __gshared_options;
__gshared static Options __gshared_options;

protected static Options options_memory;

//static immutable(Options*) options;
// Points to the thread global options
static immutable(Options*) options() {
    return cast(immutable)(&options_memory);
}


// static this() @nogc {
//     options=cast(immutable)(&options_memory);

// }

//@trusted
/++
+  Sets the thread global options opt
+/
@safe
static void setOptions(const(Options) opt) {
    options_memory=opt;
//    separator=opt.separator;
//    seperator=opt.seperator;
    // import core.stdc.string : memcpy;
    // memcpy(&options_memory, &__gshared_options, sizeof(Options));
}

/++
 + Sets the thread global options to the value of __gshared_options
 +/
static void setSharedOptions() {
    import std.stdio;
    writefln("__gshared_options=%s", __gshared_options);
    setOptions(__gshared_options);
}

/++
+ Returns:
+     a copy of the options
+/
static Options getOptions() {
    Options result=options_memory;
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
        auto json=JSON.parseJSON(json_text);
        parse(json);
    }

    void load(string config_file) {
        if (config_file.exists) {
            auto json_text=readText(config_file);
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

__gshared static TransactionMiddlewareOptions transaction_middleware_options;


static ref auto all_getopt(ref string[] args, ref bool version_switch, ref bool overwrite_switch) {
    import std.getopt;
    return getopt(
        args,
        std.getopt.config.bundling,
        "version",   "display the version",     &version_switch,
        "overwrite|O", "Overwrite the config file", &overwrite_switch,
        "transact-enable|T", format("Transaction test enable: default: %s", __gshared_options.transcript.enable), &(__gshared_options.transcript.enable),

        "path|I",    "Sets the search path",     &(__gshared_options.path_arg),
        "trace-gossip|g",    "Sets the search path",     &(__gshared_options.trace_gossip),
        "nodes|N",   format("Sets the number of nodes: default %d", __gshared_options.nodes), &(__gshared_options.nodes),
        "seed",      format("Sets the random seed: default %d", __gshared_options.seed),       &(__gshared_options.seed),
        "timeout|t", format("Sets timeout: default %d (ms)", __gshared_options.timeout), &(__gshared_options.timeout),
        "delay|d",   format("Sets delay: default: %d (ms)", __gshared_options.delay), &(__gshared_options.delay),
        "loops",     format("Sets the loop count (loops=0 runs forever): default %d", __gshared_options.loops), &(__gshared_options.loops),
        "url",       format("Sets the url: default %s", __gshared_options.url), &(__gshared_options.url),
        "noserv|n",  format("Disable monitor sockets: default %s", __gshared_options.monitor.disable), &(__gshared_options.monitor.disable),
        "sockets|M", format("Sets maximum number of monitors opened: default %s", __gshared_options.monitor.max), &(__gshared_options.monitor.max),
        "tmp",       format("Sets temporaty work directory: default '%s'", __gshared_options.tmp), &(__gshared_options.tmp),
        "monitor|P",    format("Sets first monitor port of the port sequency: default %d", __gshared_options.monitor.port),  &(__gshared_options.monitor.port),
        "transaction|p",    format("Sets first transaction port of the port sequency: default %d", __gshared_options.transaction.port),  &(__gshared_options.transaction.port),
        "s|seq",     format("The event is produced sequential this is only used in test mode: default %s", __gshared_options.sequential), &(__gshared_options.sequential),
        "stdout",    format("Set the stdout: default %s", __gshared_options.stdout), &(__gshared_options.stdout),

        "script-ip",  format("Sets the listener ip address: default %s", __gshared_options.scripting_engine.listener_ip_address), &(__gshared_options.scripting_engine.listener_ip_address),
        "script-port", format("Sets the listener port: default %d", __gshared_options.scripting_engine.listener_port), &(__gshared_options.scripting_engine.listener_port),
        "script-queue", format("Sets the listener max queue lenght: default %d", __gshared_options.scripting_engine.listener_max_queue_length), &(__gshared_options.scripting_engine.listener_max_queue_length),
        "script-maxcon",  format("Sets the maximum number of connections: default: %d", __gshared_options.scripting_engine.max_connections), &(__gshared_options.scripting_engine.max_connections),
        "script-maxqueue",  format("Sets the maximum queue length: default: %d", __gshared_options.scripting_engine.listener_max_queue_length), &(__gshared_options.scripting_engine.listener_max_queue_length),
        "script-maxfibres",  format("Sets the maximum number of fibres: default: %d", __gshared_options.scripting_engine.max_number_of_accept_fibers), &(__gshared_options.scripting_engine.max_number_of_accept_fibers),
        "script-maxreuse",  format("Sets the maximum number of fibre reuse: default: %d", __gshared_options.scripting_engine.max_number_of_fiber_reuse), &(__gshared_options.scripting_engine.max_number_of_fiber_reuse),
        "script-log",  format("Scripting engine log filename: default: %s", __gshared_options.scripting_engine.name), &(__gshared_options.scripting_engine.name),


        "transcript-from", format("Transcript test from delay: default: %d", __gshared_options.transcript.pause_from), &(__gshared_options.transcript.pause_from),
        "transcript-to", format("Transcript test to delay: default: %d", __gshared_options.transcript.pause_to), &(__gshared_options.transcript.pause_to),
        "transcript-log",  format("Transcript log filename: default: %s", __gshared_options.transcript.name), &(__gshared_options.transcript.name),

//        "help!h", "Display the help text",    &help_switch,
        );
};

__gshared static setDefaultOption() {
    // Main
    with(__gshared_options) {
        nodeprefix="Node";
        logext="log";
        seed=42;
        delay=200;
        timeout=delay*4;
        nodes=4;
        loops=30;
        infinity=false;
        url="127.0.0.1";
        //port=10900;
        //disable_sockets=false;
        tmp="/tmp/";
        stdout="/dev/tty";
        separator="_";
//  s.network_socket_port =11900;
        sequential=false;
    }
    // Scripting
    with(__gshared_options.scripting_engine) {
        listener_ip_address = "0.0.0.0";
        listener_port = 18_444;
        listener_max_queue_length = 100;
        max_connections = 1000;
        max_number_of_accept_fibers = 100;
        min_duration_full_fibers_cycle_ms = 10;
        max_number_of_fiber_reuse = 1000;
        name="engine";
        min_number_of_fibers = 10;
        min_duration_for_accept_ms = 3000;
    }
    // Transcript
    with (__gshared_options.transcript) {
        pause_from=333;
        pause_to=888;
        name="transcript";
    }
    // Transaction
    with(__gshared_options.transaction) {
        port=10800;
        disable=false;
        max=0;
        name="transaction";
    }
    // Monitor
    with(__gshared_options.monitor) {
        port=10900;
        disable=false;
        max=0;
        name="monitor";
    }
    // Logger
    with(__gshared_options.logger) {
        task_name="tagion.logger";
        file_name="/tmp/tagion.log";
    }
    setSharedOptions();
}
