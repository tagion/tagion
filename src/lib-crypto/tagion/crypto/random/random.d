/// Cryptographic Random using system functions
module tagion.crypto.random.random;

import std.format;
import std.system : os;
import std.traits;
import tagion.basic.Version;

static if (ver.iOS || ver.OSX || ver.BSD || ver.Android) {
    enum is_getrandom = false;
    extern (C) void arc4random_buf(void* buf, size_t buflen) pure nothrow;
}
else static if (ver.linux || ver.WASI) {
    enum is_getrandom = true;
    extern (C) ptrdiff_t getrandom(void* buf, size_t buflen, uint flags) pure nothrow;
}
else {
    static assert(0, format("Random function not support for %s", os));
}

bool isGetRandomAvailable() nothrow {
    import core.stdc.errno;

    static if (is_getrandom) {
        enum GRND_NONBLOCK = 0x0001;
        const res = getrandom(null, 0, GRND_NONBLOCK);
        if (res < 0) {
            switch (errno) {
            case ENOSYS:
            case EPERM:
                return false;
            default:
                return true;
            }
        }
        else {
            return true;
        }
    }
    else {
        return true;
    }
}

unittest {
    assert(isGetRandomAvailable, "hardware random function is not available in this environment");
}

/++
+ getRandom - runs platform specific random function.
+/
@trusted
void getRandom(ref scope ubyte[] buf) pure nothrow
in (buf.length <= 256)
do {
    if (buf.length == 0) {
        return;
    }
    static if (is_getrandom) {
        enum sikkenogetskidt = "Problem with random generation";
        // GRND_NONBLOCK = 0x0001. Don't block and return EAGAIN instead
        enum GRND_RANDOM = 0x0002; // No effect
        // GRND_INSECURE = 0x0004. Return non-cryptographic random bytes
        const size = getrandom(&buf[0], buf.length, GRND_RANDOM);
        assert(size == buf.length, sikkenogetskidt);
    }
    else {
        arc4random_buf(&buf[0], buf.length);
    }
}

@trusted
T getRandom(T)() pure nothrow if (isBasicType!T) {
    T result;
    auto buf = (cast(ubyte*)&result)[0 .. T.sizeof];
    getRandom(buf);
    return result;

}
