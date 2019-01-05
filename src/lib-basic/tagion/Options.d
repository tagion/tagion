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

    private void x_parseJSON(ref JSON.JSONValue json_value) {
        foreach(i, m; this.tupleof) {
            enum name=basename!(this.tupleof[i]);
            alias type=typeof(m);
            static if (is(type==struct)) {
                m.x_parseJSON(json_value[name]);
            }
            else static if (is(type==string)) {
                this.tupleof[i]=json_value[name].str;
            }
            else static if (isIntegral!type || isFloatingPoint!type) {
                static if (isIntegral!type) {
                    auto value=json_value[name].integer;
                }
                else {
                    auto value=json_value[name].floating;
                }
                check((value >= type.min) && (value <= type.max), format("Value %d out of range for type %s of %s", value, type.stringof, m.stringof ));
                this.tupleof[i]=cast(type)value;
            }
            else static if (is(type==bool)) {
                check((json_value[name].type == JSON.JSON_TYPE.TRUE) || (json_value[name].type == JSON.JSON_TYPE.FALSE),
                    format("Type %s expected for %s but the json type is %s", type.stringof, m.stringof, json_value[name].type));
                this.tupleof[i]=json_value[name].type == JSON.JSON_TYPE.TRUE;
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
    //Port for network socket
    ushort network_socket_port;
    // Sequential test mode
    // all the
    bool sequential;

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

        mixin JSONCommon;
    }

    ScriptingEngine scripting_engine;

    void parseJSON(string json_text) {
        auto json=JSON.parseJSON(json_text);
        x_parseJSON(json);
    }

    void load(string config_file) {
        if (config_file.exists) {
            auto json_text=readText(config_file);
            parseJSON(json_text);
        }
        else {
            config_file.write(stringify);
        }
    }
}

__gshared static Options options;
