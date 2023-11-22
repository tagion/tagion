module tagion.crypto.random.random;

import std.format;
import std.system : os;
import std.traits;
import tagion.basic.Version;

static if (ver.USE_BUILD_IN_RANDOM_FOR_MOBILE_SHOULD_BE_REMOVED) {
    enum is_getrandom = "Dummy declaration";
}
else static if (ver.linux || ver.Android) {
    enum is_getrandom = true;
    extern (C) ptrdiff_t getrandom(void* buf, size_t buflen, uint flags) nothrow;
}
// Tecnically netbsd and freebsd also provide getrandom(2), so you could use still use that instead
else static if (ver.iOS || ver.OSX || ver.BSD) {
    enum is_getrandom = false;
    extern (C) void arc4random_buf(void* buf, size_t buflen) nothrow;
}
else {
    static assert(0, format("Random function not support for %s", os));
}

bool isGetRandomAvailable() {
    import core.stdc.errno;
    static if (ver.USE_BUILD_IN_RANDOM_FOR_MOBILE_SHOULD_BE_REMOVED) {
        return true;
    }
    else static if(is_getrandom) {
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
void getRandom(ref scope ubyte[] buf) nothrow
in (buf.length <= 256)
do {

    if (buf.length == 0) {
        return;
    }
    static if (ver.USE_BUILD_IN_RANDOM_FOR_MOBILE_SHOULD_BE_REMOVED) {
        pragma(msg, "fixme(cbr);Insecure random is used. This should be fixed");
        import std.algorithm;
        import std.exception : assumeWontThrow;
        import std.random;

        auto rnd = Random(unpredictableSeed);
        assumeWontThrow(buf.each!((ref b) => b = uniform!("[]", ubyte, ubyte)(0, ubyte.max, rnd)));
    }
    else static if (is_getrandom) {
        // GRND_NONBLOCK = 0x0001. Don't block and return EAGAIN instead
        // GRND_RANDOM   = 0x0002. No effect
        // GRND_INSECURE = 0x0004. Return non-cryptographic random bytes

        const size = getrandom(&buf[0], buf.length, 0x0002);
        assert(size == buf.length, "Problem with random generation");
    }
    else {
        arc4random_buf(&buf[0], buf.length);
    } // TODO: add other platforms
}

@trusted
T getRandom(T)() nothrow if (isBasicType!T) {
    T result;
    auto buf = (cast(ubyte*)&result)[0 .. T.sizeof];
    getRandom(buf);
    return result;

}
