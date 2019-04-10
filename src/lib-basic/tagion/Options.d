module tagion.Options;


import JSON=std.json;
import std.format;
import std.traits;
import std.file;
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
    // Number of concurrent nodes
    uint nodes;
    // Maximum number of monitor sockets open
    // If this value is set to 0
    // one socket is opened for each node
    uint max_monitors;
    // Enable sockets
    bool disable_sockets;
    // Random seed for pseudo random sequency
    uint seed;
    // Delay between heart-beats in ms
    uint delay;
    // Timeout for between nodes
    uint timeout;
    // Number of heart-beats until the program stops
    uint loops;
    // Runs forever
    bool infinity;
    // The port number of the first socket port
    uint port;
    // Url to be used for the sockets
    string url;
    // Enable the package dump for the transeived packagies
    bool trace_gossip;
    // Directory for the trace files
    string tmp;
    // Print output
    string stdout;
    //Port for network socket
    ushort network_socket_port;
    // Sequential test mode
    // all the
    bool sequential;
    // Name separator
    string separator;
    // Node name prefix
    string nodeprefix;
    // logfile extension
    string logext;

    // Search path
    string path_arg;
    uint node_id;          /// This is use to set the node_id in emulator mode in normal node this is allways 0
    string node_name;      /// Name of the node

    mixin JSONCommon;

    struct ScriptingEngine {
        // Ip address
        string listener_ip_address;
        //Port
        ushort listener_port;
        //Listener max. incomming connection req. queue length
        uint listener_max_queue_length;
        //Max simultanious connections for the scripting engine
        uint max_connections;
        //Max simultanious fibers for accepting incomming SSL connections.
        uint max_number_of_accept_fibers;
        //Min duration between a full call cycle for all fibers in milliseconds;
        uint min_duration_full_fibers_cycle_ms;
        //Number of times to reuse a fiber
        uint max_number_of_fiber_reuse;
        //Directory to dump bson data
        string tmp_debug_dir;
        //Name of bills file for debug bson dump
        string tmp_debug_bills_filename;
        // Scripting engine name used for log filename etc.
        string name;

        mixin JSONCommon;
    }

    ScriptingEngine scripting_engine;

    struct Transcript {
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
        uint max;     /++ Maximum number of monitor sockets open
                       If this value is set to 0
                       one socket is opened for each node
                       +/
        ushort port; /// Monitor port
        bool disable; // Disable monitor

        mixin JSONCommon;
    }

    Monitor monitor;

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

__gshared static Options options;

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


static auto all_getopt(ref string[] args, ref bool version_switch, ref bool overwrite_switch) {
    import std.getopt;
    return getopt(
        args,
        std.getopt.config.bundling,
        "version",   "display the version",     &version_switch,
        "overwrite|O", "Overwrite the config file", &overwrite_switch,
        "transact-enable|T", format("Transaction test enable: default: %s", options.transcript.enable), &(options.transcript.enable),

        "path|I",    "Sets the search path",     &(options.path_arg),
        "trace-gossip|g",    "Sets the search path",     &(options.trace_gossip),
        "nodes|N",   format("Sets the number of nodes: default %d", options.nodes), &(options.nodes),
        "seed",      format("Sets the random seed: default %d", options.seed),       &(options.seed),
        "timeout|t", format("Sets timeout: default %d (ms)", options.timeout), &(options.timeout),
        "delay|d",   format("Sets delay: default: %d (ms)", options.delay), &(options.delay),
        "loops",     format("Sets the loop count (loops=0 runs forever): default %d", options.loops), &(options.loops),
        "url",       format("Sets the url: default %s", options.url), &(options.url),
        "noserv|n",  format("Disable monitor sockets: default %s", options.disable_sockets), &(options.disable_sockets),
        "sockets|M", format("Sets maximum number of monitors opened: default %s", options.max_monitors), &(options.max_monitors),
        "tmp",       format("Sets temporaty work directory: default '%s'", options.tmp), &(options.tmp),
        "port|p",    format("Sets first port of the port sequency: default %d", options.port),  &(options.port),
        "s|seq",     format("The event is produced sequential this is only used in test mode: default %s", options.sequential), &(options.sequential),
        "stdout",    format("Set the stdout: default %s", options.stdout), &(options.stdout),

        "script-ip",  format("Sets the listener ip address: default %s", options.scripting_engine.listener_ip_address), &(options.scripting_engine.listener_ip_address),
        "script-port", format("Sets the listener port: default %d", options.scripting_engine.listener_port), &(options.scripting_engine.listener_port),
        "script-queue", format("Sets the listener max queue lenght: default %d", options.scripting_engine.listener_max_queue_length), &(options.scripting_engine.listener_max_queue_length),
        "script-maxcon",  format("Sets the maximum number of connections: default: %d", options.scripting_engine.max_connections), &(options.scripting_engine.max_connections),
        "script-maxqueue",  format("Sets the maximum queue length: default: %d", options.scripting_engine.listener_max_queue_length), &(options.scripting_engine.listener_max_queue_length),
        "script-maxfibres",  format("Sets the maximum number of fibres: default: %d", options.scripting_engine.max_number_of_accept_fibers), &(options.scripting_engine.max_number_of_accept_fibers),
        "script-maxreuse",  format("Sets the maximum number of fibre reuse: default: %d", options.scripting_engine.max_number_of_fiber_reuse), &(options.scripting_engine.max_number_of_fiber_reuse),
        "script-log",  format("Scripting engine log filename: default: %s", options.scripting_engine.name), &(options.scripting_engine.name),


        "transcript-from", format("Transcript test from delay: default: %d", options.transcript.pause_from), &(options.transcript.pause_from),
        "transcript-to", format("Transcript test to delay: default: %d", options.transcript.pause_to), &(options.transcript.pause_to),
        "transcript-log",  format("Transcript log filename: default: %s", options.transcript.name), &(options.transcript.name),

//        "help!h", "Display the help text",    &help_switch,
        );
};
