#### HiBON LEB128 

The LEB128 https://en.wikipedia.org/wiki/LEB128 format is used store the integer values in the HiBON stream.

**Sample to encode to LEB128 in D** 

```D
@safe
immutable(ubyte[]) encode(T)(const T v) pure if(isUnsigned!T && isIntegral!T) {
    ubyte[T.sizeof+2] data;
    alias BaseT=TypedefType!T;
    BaseT value=cast(BaseT)v;
    foreach(i, ref d; data) {
        d = value & 0x7f;
        value >>= 7;
        if (value == 0) {
            return data[0..i+1].idup;
        }
        d |= 0x80;
    }
    assert(0);
}

@safe
immutable(ubyte[]) encode(T)(const T v) pure if(isSigned!T && isIntegral!T) {
    enum DATA_SIZE=(T.sizeof*9+1)/8+1;
    ubyte[DATA_SIZE] data;
    if (v == T.min) {
        foreach(ref d; data[0..$-1]) {
            d=0x80;
        }
        data[$-1]=(T.min >> (7*(DATA_SIZE-1))) & 0x7F;
        return data.dup;
    }
    immutable negative=(v < 0);
    T value=v;
    foreach(i, ref d; data) {
        d = value & 0x7f;
        value >>= 7;
        /* sign bit of byte is second high order bit (0x40) */
        if (((value == 0) && !(d & 0x40)) || ((value == -1) && (d & 0x40))) {
            return data[0..i+1].idup;
        }
        d |= 0x80;
    }
    check(0, "Bad LEB128 format");
    assert(0);
}
```

**Sample code to decode a array of bytes in LEB128 in D**

```D
alias DecodeLEB128(T)=Tuple!(T, "value", size_t, "size");

@safe
DecodeLEB128!T decode(T=ulong)(const(ubyte[]) data) pure if (isUnsigned!T) {
    alias BaseT=TypedefType!T;
    ulong result;
    uint shift;
    enum MAX_LIMIT=T.sizeof*8;
    size_t len;
    foreach(i, d; data) {
        check(shift < MAX_LIMIT,
            format("LEB128 decoding buffer over limit of %d %d", MAX_LIMIT, shift));

        result |= (d & 0x7FUL) << shift;
        if ((d & 0x80) == 0) {
            len=i+1;
            static if (!is(BaseT==ulong)) {
                check(result <= BaseT.max, format("LEB128 decoding overflow of %x for %s", result, T.stringof));
            }
            return DecodeLEB128!T(cast(T)result, len);
        }
        shift+=7;
    }
    check(0, format("Bad LEB128 format for type %s data=%s", T.stringof, data[0..min(MAX_LIMIT,data.length)]));
    assert(0);
}

@safe
DecodeLEB128!T decode(T=long)(const(ubyte[]) data) pure if (isSigned!T) {
    alias BaseT=TypedefType!T;
    long result;
    uint shift;
    enum MAX_LIMIT=T.sizeof*8;
    size_t len;
    foreach(i, d; data) {
        check(shift < MAX_LIMIT, "LEB128 decoding buffer over limit");
        const long lsbs=(d & 0x7FL);
        result |= (d & 0x7FL) << shift;
        shift+=7;
        if ((d & 0x80) == 0 ) {
            if ((shift < long.sizeof*8) && ((d & 0x40) != 0)) {
                result |= (~0L << shift);
            }
            len=i+1;
            static if (!is(BaseT==long)) {
                check((T.min <= result) && (result <= T.max),
                    format("LEB128 out of range %d for %s", result, T.stringof));
            }
            return DecodeLEB128!T(cast(BaseT)result, len);
        }
    }
    check(0, format("Bad LEB128 format for type %s data=%s", T.stringof, data[0..min(MAX_LIMIT,data.length)]));
    assert(0);
}
```



## LEB128 Complaints tests ##

Complaint test for encoding LEB128 as a sample code in D syntax

**Test sample 1**

```D
assert(encode!int(-1) == [127]);
wint(int.min) == [128, 128, 128, 128, 120]);
assert(encode!long(int.min) == [128, 128, 128, 128, 120]);
assert(encode!long(int.max) == [255, 255, 255, 255, 7]);
assert(encode!int(-123456) == [192, 187, 120]);

assert(encode!long(-27) == [101]);
assert(encode!long(-1L) == [127]);
assert(encode!long(long.max-1) == [254, 255, 255, 255, 255, 255, 255, 255, 255, 0]);
assert(encode!long(long.max) == [255, 255, 255, 255, 255, 255, 255, 255, 255, 0]);
assert(encode!long(long.min+1) == [129, 128, 128, 128, 128, 128, 128, 128, 128, 127]);
assert(encode!long(long.min) == [128, 128, 128, 128, 128, 128, 128, 128, 128, 127]);

assert(encode!ulong(ulong.max) == [255, 255, 255, 255, 255, 255, 255, 255, 255, 1]);

```



Complaint test for decoding LEB128 as a sample code in D syntax.

**Test sample 2**

```D
assert(decode!int([127]).value == -1);
assert(decode!int([128, 128, 128, 128, 120]).value == int.min);
assert(decode!int([255, 255, 255, 255, 7]).value == int.max);
assert(decode!long([127]).value == -1L);
assert(decode!long([101]).value == -27L);

assert(decode!long([254, 255, 255, 255, 255, 255, 255, 255, 255, 0]).value == long.max-1);
assert(decode!long([255, 255, 255, 255, 255, 255, 255, 255, 255, 0]).value == long.max);
assert(decode!long([129, 128, 128, 128, 128, 128, 128, 128, 128, 127]).value == long.min+1);
assert(decode!long([128, 128, 128, 128, 128, 128, 128, 128, 128, 127]).value == long.min);

assert(decode!ulong([255, 255, 255, 255, 255, 255, 255, 255, 255, 1]) == ulong.max);
```



