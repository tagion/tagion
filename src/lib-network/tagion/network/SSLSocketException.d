module tagion.network.SSLSocketException;

import std.socket : SocketException;
import tagion.network.SSL;
import std.format;

@safe
class SSLSocketException : SocketException {
    immutable SSLErrorCodes error_code;
    this(immutable(char)[] msg, const SSLErrorCodes error_code = SSLErrorCodes.SSL_ERROR_NONE,
    string file = __FILE__, size_t line = __LINE__) pure nothrow {
        this.error_code = error_code;
        import std.exception : assumeWontThrow;

        immutable _msg = assumeWontThrow(format("%s (%s)", msg, error_code));
        super(_msg, file, line);
    }
}

@safe
void check(const bool flag, string msg, const SSLErrorCodes error_code = SSLErrorCodes.SSL_ERROR_NONE,
        string file = __FILE__, size_t line = __LINE__) pure {
    if (!flag) {
        throw new SSLSocketException(msg, error_code, file, line);
    }
}
