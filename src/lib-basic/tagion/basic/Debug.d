/// \file Debug.d
module tagion.basic.Debug;

import std.exception : assumeWontThrow;
import std.stdio;

/* 
 * This function can be used instead of stderr.writeln 
 * and it is only enabled in debug mode
 * The function can be used in pure/nothrow/@safe function
 * Params:
 *   fmt = string format 
 *   args = argument list
 */
debug {
    void __write(Args...)(string fmt, Args args) @trusted nothrow pure {
        debug assumeWontThrow(stderr.writefln(fmt, args));
    }
}
else {
    void __write(Args...)(string fmt, Args args) @trusted nothrow {
        // empty
    }
}

/* 
 * 
 * Params:
 *   file = name for the test file
 *   module_file = file path to the correct module
 * Returns: 
 * The absolute file path to the test-file
 */
@safe
string testfile(string file, string module_file = __FILE__) {
    import std.path;

    return buildPath(module_file.dirName, "unitdata", file);
}
