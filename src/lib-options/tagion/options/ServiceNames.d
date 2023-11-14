module tagion.options.ServiceNames;

import std.array : join;
import std.conv : to;
import tagion.options.CommonOptions : commonOptions;

string get_node_name(immutable size_t i) nothrow @safe {
    import std.array : join;
    import std.exception : assumeWontThrow;
    import std.stdio;

    const name = [commonOptions.nodeprefix, i.to!string].join(commonOptions.separator);
    assumeWontThrow(writefln("node_name: %s", name));
    return name;
}

// string task_name(const string name) nothrow {
//     return [name, commonOptions.node_id.to!string].join(commonOptions.separator);
// }
