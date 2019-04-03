module tagion.utils.Miscellaneous;
@safe
immutable(char)[] toHexString(alias ucase=false)(const(ubyte)[] buffer) pure nothrow {
    static if ( ucase ) {
        immutable immutable(char)[] hexdigits = "0123456789ABCDEF";
    }
    else {
        immutable immutable(char)[] hexdigits = "0123456789abcdef";
    }
    uint i = 0;
    char[]  text=new char[buffer.length*2];
    foreach (b; buffer)
    {
        text[i++] = hexdigits[b >> 4];
        text[i++] = hexdigits[b & 0xf];
    }

    return text.idup;
}

unittest {
    {
        enum value="CF80CD8AED482D5D1527D7DC72FCEFF84E6326592848447D2DC0B0E87DFC9A90";
        auto buf=decode(value);
        assert(buf.length*2 == value.length);
        assert(buf.toHexString!true == value);
    }
    {
        enum value="30440220182A108E1448DC8F1FB467D06A0F3BB8EA0533584CB954EF8DA112F1D60E39A202201C66F36DA211C087F3AF88B50EDF4F9BDAA6CF5FD6817E74DCA34DB12390C6E9";
        auto buf=decode(value);
        assert(buf.length*2 == value.length);
        assert(buf.toHexString!true == value);
    }

}

@safe
immutable(ubyte[]) decode(string hex)
in {
    assert(hex.length % 2 == 0);
}
do {
    int to_hex(const(char) c) {
        if ( (c >= '0') && (c <= '9') ) {
            return cast(ubyte)(c-'0');
        }
        else if ( (c >= 'a') && (c <= 'f') ) {
            return c-'a'+10;
        }
        else if ( (c >= 'A') && (c <= 'F') ) {
            return cast(ubyte)(c-'A')+10;
        }
        assert(0, "Bad char '"~c~"'");
    }
    immutable buf_size=hex.length / 2;
    ubyte[] result=new ubyte[buf_size];
    uint j;
    bool event;
    ubyte part;
    foreach(c; hex) {
        if ( c != '_' ) {
//            writefln("j=%d len=%d", j, result.length);
            part <<=4;
            part |=to_hex(c);

            if ( event ) {
                result[j]=part;
                part=0;
                j++;
            }
            event=!event;
        }
    }
    return result.idup;
}
