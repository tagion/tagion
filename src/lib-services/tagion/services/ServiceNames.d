module tagion.services.ServiceNames;

import tagion.Options : Options;
import std.format;

string node_task_name(const Options opt) pure {
    return format("%s%s%d", opt.nodeprefix, opt.separator, opt.node_id);
}

string transaction_task_name(const Options opt) pure {
    return format("%s%s%d", opt.transaction.prefix, opt.separator, opt.node_id);
}

string transcript_task_name(const Options opt) pure {
    return format("%s%s%d", opt.transcript.prefix, opt.separator, opt.node_id);
}

string monitor_task_name(const Options opt) pure {
    return format("%s%s%d", opt.monitor.prefix, opt.separator, opt.node_id);
}
