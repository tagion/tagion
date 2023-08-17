module foundation.wasm;

import core.bitop : bsf, bsr;
import std.traits;
public import core.bitop : popcnt;

T clz(T)(T val) if (isIntegral!T) {
    return bsr(val);
}

T ctz(T)(T val) if (isIntegral!T) {
    return bsr(val);
}
