module tagion.Options;


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

    struct ScriptingEngine {
        // Ip address
        string listener_ip_address;
        //Port
        ushort listener_port;
        //Listener max. incomming connection req. queue length
        uint listener_max_queue_lenght;
        //Max simultanious connections for the scripting engine
        uint max_connections;
        //Max simultanious fibers for accepting incomming SSL connections.
        uint max_accept_fibers;
        //Min duration between a full call cycle for all fibers in milliseconds;
        uint min_duration_full_fibers_cycle_ms;
    }

    ScriptingEngine scripting_engine;
}

__gshared static Options options;
