module tagion.options.ServiceNames;

import tagion.options.CommonOptions : commonOptions;
import std.array : join;
import std.conv : to;

string get_node_name(immutable size_t i) nothrow @safe {
    import std.array : join;

    return [commonOptions.nodeprefix, i.to!string].join(commonOptions.separator);
}

// string task_name(const string name) nothrow {
//     return [name, commonOptions.node_id.to!string].join(commonOptions.separator);
// }
