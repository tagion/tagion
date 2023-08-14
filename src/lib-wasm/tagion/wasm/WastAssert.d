module tagion.wasm.WastAssert;

import std.outbuffer;

import tagion.basic.Types;
import tagion.hibon.HiBONRecord;
import tagion.wasm.WasmWriter;

@safe
struct Assert {
    enum Method {
        Return,
        Invalid,
        //Return_nan, same as Return
        Trap,
    }

    Method method;
    Buffer invoke;
    @label("*", true) Buffer result;
    @label("*", true) string message;

    mixin HiBONRecord;
    void serialize(ref OutBuffer bout) const {
    }
}

alias SectionAssert = WasmWriter.WasmSection.SectionT!Assert;
