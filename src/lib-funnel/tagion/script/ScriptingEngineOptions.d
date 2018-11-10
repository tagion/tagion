module tagion.script.ScriptingEngineOptions;

import core.time : Duration, dur;
import tagion.Options;

class ScriptingEngineOptions {
    immutable uint max_connections;
    immutable string listener_ip_address;
    immutable ushort listener_port;
    immutable uint listener_max_queue_length;
    immutable uint max_number_of_accept_fibers;
    immutable Duration min_duration_full_fibers_cycle_ms;
    immutable uint max_number_of_fiber_reuse;
    enum min_number_of_fibers = 10;
    enum min_duration_for_accept_ms = 3000;
    immutable uint max_accept_call_tries;

    this(Options.ScriptingEngine se_options) {
        this.max_connections = se_options.max_connections;
        this.listener_ip_address = se_options.listener_ip_address;
        this.listener_port = se_options.listener_port;
        this.listener_max_queue_length = se_options.listener_max_queue_length;
        this.max_number_of_accept_fibers = se_options.max_number_of_accept_fibers;
        this.min_duration_full_fibers_cycle_ms = dur!"msecs"(se_options.min_duration_full_fibers_cycle_ms);
        this.max_number_of_fiber_reuse = se_options.max_number_of_fiber_reuse;
        const tries = min_duration_for_accept_ms / se_options.min_duration_full_fibers_cycle_ms;
        this.max_accept_call_tries = tries > 1 ? tries : 2;
    }
}