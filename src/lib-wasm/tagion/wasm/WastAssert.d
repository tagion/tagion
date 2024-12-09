module tagion.wasm.WastAssert;

import std.outbuffer;
import tagion.basic.Types;
import tagion.hibon.HiBONRecord;
import tagion.wasm.WasmWriter;
import tagion.wasm.WasmBase : Types;

@safe
struct Assert {
    enum Method {
        Return,
        Invalid,
        Return_nan,
        Trap,
    }

    string name;
    Method method;
    Buffer invoke;
    @label("results") @optional Buffer types;
    @optional Buffer result;
    @optional string message;

    const(Types[]) results() const pure nothrow @trusted {
        return cast(Types[]) types;
    }

    mixin HiBONRecord;
    void serialize(ref OutBuffer bout) const {
        bout.write(toDoc.serialize);
    }
}

@safe
struct SectionAssert {
    Assert[] asserts;
    mixin HiBONRecord;
}
