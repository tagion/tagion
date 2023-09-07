module tagion.crypto.random;

import tagion.basic.Version;
import std.system : os;
import std.format;

static if (ver.linux || ver.Android) {
    enum is_getrandom = true;
    extern (C) size_t getrandom(void* buf, size_t buflen, uint flags) @trusted;
}
else static if (ver.iOS) {
    enum is_getrandom = false;
    extern (C) void arc4random_buf(void* buf, size_t buflen) @trusted;
}
else {
    static assert(0, format("Random function not support for %s", os));
}

/++
     + getRandom - runs platform specific random function.
     +/
@trusted
void getRandom(ref scope ubyte[] buf) {

    static if (is_getrandom) {
        // GRND_NONBLOCK = 0x0001. Don't block and return EAGAIN instead
        // GRND_RANDOM   = 0x0002. No effect
        // GRND_INSECURE = 0x0004. Return non-cryptographic random bytes

        getrandom(&buf[0], buf.length, 0x0002);
    }
    else {
        arc4random_buf(&buf[0], buf.length);
    } // TODO: add other platforms
}
