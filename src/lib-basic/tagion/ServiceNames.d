module tagion.ServiceNames;

import tagion.Options: Options;
import std.array: join;
import std.conv: to;

string get_node_name(ref const Options opts, immutable size_t i) pure nothrow {
    import std.array: join;

    return [opts.nodeprefix, i.to!string].join(opts.separator);
}

string node_task_name(ref const Options opts) pure nothrow {
    return get_node_name(opts, opts.node_id);
}

string transaction_task_name(ref const Options opts) pure nothrow {
    return [opts.transaction.prefix, opts.node_id.to!string].join(opts.separator);
}

string transervice_task_name(ref const Options opts) pure nothrow {
    return [opts.transaction.service.prefix, opts.node_id.to!string].join(opts.separator);
}

string transcript_task_name(ref const Options opts) pure nothrow {
    return [opts.transcript.prefix, opts.node_id.to!string].join(opts.separator);
}

string monitor_task_name(ref const Options opts) pure nothrow {
    return [opts.monitor.prefix, opts.node_id.to!string].join(opts.separator);
}
