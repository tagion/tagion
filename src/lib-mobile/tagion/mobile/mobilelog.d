module tagion.mobile.mobilelog;
import std.file;
import std.path;

debug(android) {
static string log_file;

@safe void write_log(const(string) message) pure nothrow {
    if (!__ctfe) { 
        debug(android) {
            import core.stdc.stdio;
            // printf("%.*s", cast(int) message.length, message.ptr);
            // fprintf(stderr, "%.*s", cast(int) message.length, message.ptr);
            if (log_file !is string.init && log_file.exists) {
                log_file.append(message);
                log_file.append("\n");
            }
        }
    }
}
}
