module tagion.tools.dartutil.dartindex;

import std.format;
import tagion.basic.Types : Buffer;
import tagion.hibon.Document;
import tagion.dart.DARTBasic : DARTIndex, dartKey;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.tools.toolsexception;
import tagion.tools.Basic;

DARTIndex dartIndexDecode(const(HashNet) net, const(char[]) str) {
    import tagion.hibon.HiBONtoText;
    import misc = tagion.utils.Miscellaneous;
    import std.base64;
    import std.algorithm;
    import std.array : split;
    import tagion.hibon.HiBONJSON : typeMap, NotSupported;
    import tagion.hibon.HiBONBase;
    import tagion.hibon.HiBONFile : fread;
    import std.traits;
    import tagion.hibon.Document : mut;

    verbose("dart-index %s", str);

    if (isBase64Prefix(str)) {
        return DARTIndex(Base64URL.decode(str[1 .. $]).idup);
    }
    else if (isHexPrefix(str)) {
        return DARTIndex(misc.decode(str[hex_prefix.length .. $]));
    }
    else if (str.canFind(":")) {

        const list = str.split(":");
        const name = list[0];
        if (list.length == 2) {
            return net.dartKey(name, list[1].idup);
        }
    case_type:
        switch (list[1]) {
            static foreach (E; EnumMembers!Type) {
                {
                    enum type_name = typeMap[E];
                    static if (type_name != NotSupported) {
                    case type_name:
                        verbose("Htype %s -> %s", type_name, E);
                        static if (E == Type.BINARY) {
                            Buffer buf = list[2].decode;
                            return net.dartKey(name, buf);
                        }
                        else static if (E == Type.DOCUMENT) {
                            const doc = list[2].fread;
                            return net.dartKey(name, doc.mut);
                        }
                        else static if (E == Type.STRING) {
                            return net.dartKey(name, list[2].idup);
                        }
                        else static if (E == Type.TIME) {
                            import std.datetime;

                            return net.dartKey(name, SysTime.fromISOExtString(list[2]).stdTime);
                        }
                        else {
                            alias Value = ValueT!(false, void, void);
                            alias T = Unqual!(Value.TypeT!E);
                            import std.conv : to;

                            auto val = list[2].to!T;
                            return net.dartKey(name, val);
                        }
                        break case_type;
                    }
                }
            }
            default:
            check(0, format("DART search %s not supported expected name:Type:value or name:text", str));
            // empty
        }
        return net.dartKey(name, list[1].idup);
    }

    return DARTIndex(misc.decode(str));
}

immutable(Buffer) binaryHash(const(HashNet) net, scope const(ubyte[]) h1, scope const(ubyte[]) h2)
in {
    assert(h1.length is 0 || h1.length is net.hashSize,
            format("h1 is not a valid hash (length=%d should be 0 or %d", h1.length, net.hashSize));
    assert(h2.length is 0 || h2.length is net.hashSize,
            format("h2 is not a valid hash (length=%d should be 0 or %d", h2.length, net.hashSize));
}
out (result) {
    if (h1.length is 0) {
        assert(h2 == result);
    }
    else if (h2.length is 0) {
        assert(h1 == result);
    }
}
do {
    assert(h1.length is 0 || h1.length is net.hashSize,
            format("h1 is not a valid hash (length=%d should be 0 or %d", h1.length, net.hashSize));
    assert(h2.length is 0 || h2.length is net.hashSize,
            format("h2 is not a valid hash (length=%d should be 0 or %d", h2.length, net.hashSize));
    if (h1.length is 0) {
        return h2.idup;
    }
    if (h2.length is 0) {
        return h1.idup;
    }
    return net.rawCalcHash(h1 ~ h2);
}
