module tagion.mobile.mobilelog;
import std.file;
import std.path;

debug(android) {
static string log_file;

@safe void write_log(const(string) message, const string file = __FILE__, const size_t line = __LINE__) pure nothrow {
    if (!__ctfe) { 
        debug(android) {
            import core.stdc.stdio;
            import tagion.basic.Debug;
            // printf("%.*s", cast(int) message.length, message.ptr);
            // fprintf(stderr, "%.*s", cast(int) message.length, message.ptr);
            if (log_file !is string.init && log_file.exists) {
                log_file.append(__format("%s:%d", file, line));
                log_file.append(message);
            }
        }
    }
}
}
