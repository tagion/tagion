module tagion.services.ServiceNames;

import tagion.Options : Options;
import std.array : join;
import std.conv : to;

string node_task_name(const Options opt) pure nothrow {
    return [opt.nodeprefix, opt.node_id.to!string].join(opt.separator);
}

string transaction_task_name(const Options opt) pure nothrow {
    return [opt.transaction.prefix, opt.node_id.to!string].join(opt.separator);
}

string transcript_task_name(const Options opt) pure nothrow {
    return [opt.transcript.prefix, opt.node_id.to!string].join(opt.separator);
}

string monitor_task_name(const Options opt) pure nothrow {
    return [opt.monitor.prefix, opt.node_id.to!string].join(opt.separator);
}
