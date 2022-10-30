module tagion.basic.Debug;

import std.exception : assumeWontThrow;
import std.stdio;

/* 
 * Function used information under debugging
 * Should not be used to production code
* If the debug flag is enable the function can also be use in pure functions
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

        assumeWontThrow(stderr.writefln(fmt, args));
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
