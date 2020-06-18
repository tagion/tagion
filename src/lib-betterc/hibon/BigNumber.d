module hibon.BigNumber;

import LEB128=hibon.utils.LEB128;

extern(C):
@nogc:
/++
 BigNumber used in the HiBON format
 It is a wrapper of the std.bigint
+/
struct BigNumber {
    @nogc:
    ubyte[] data;
    size_t calc_size() const {
        return LEB128.calc_size(data);
    }

    const(ubyte[]) serialize() const {
        return data;
    }
 }
