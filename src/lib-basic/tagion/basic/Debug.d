module tagion.basic.Debug;

import std.exception : assumeWontThrow;
import std.format;
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
    void __write(Args...)(string fmt, Args args) @trusted nothrow pure {
        pragma(msg, "Cannot call __write without debug flag");
        // assumeWontThrow(stderr.writefln(fmt, args));
    }
}

/**
* This function is same as std.format made nonthow
* It's meant to be used in assert/pre-post
* Parans:
* fmt = string format
* args = argument list
*/
debug {
    string __format(Args...)(string fmt, Args args) @trusted nothrow pure {
        string result;
        debug {
            result = assumeWontThrow(format(fmt, args));
        }
        return result;
    }
}
else {
    string __format(Args...)(string fmt, Args args) @trusted nothrow {
        return assumeWontThrow(format(fmt, args));
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
