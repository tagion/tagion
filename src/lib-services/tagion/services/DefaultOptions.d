module tagion.services.DefaultOptions;

import tagion.Options;

__gshared static setDefaultOption() {
    options.seed=42;
    options.delay=200;
    options.timeout=options.delay*4;
    options.nodes=4;
    options.loops=30;
    options.infinity=false;
    options.url="127.0.0.1";
    options.port=10900;
    options.disable_sockets=false;
    options.tmp="/tmp/";
    options.stdout="/dev/tty";
    options.separator="_";
    options.network_socket_port =11900;
    options.sequential=false;
// Scripting
    options.scripting_engine.listener_ip_address = "0.0.0.0";
    options.scripting_engine.listener_port = 18_444;
    options.scripting_engine.listener_max_queue_length = 100;
    options.scripting_engine.max_connections = 1000;
    options.scripting_engine.max_number_of_accept_fibers = 100;
    options.scripting_engine.min_duration_full_fibers_cycle_ms = 10;
    options.scripting_engine.max_number_of_fiber_reuse = 1000;
    options.scripting_engine.name="engine";

// Transaction test
    options.transcript.pause_from=333;
    options.transcript.pause_to=888;
    options.transcript.name="transcript";

    options.nodeprefix="Node";
    options.logext="log";
}
