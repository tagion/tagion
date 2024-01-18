module tagion.hibon.fix.HiBONtoText;
version(none) {
@safe:
/**
 HiBON Base64 with  ':' added in the front of the string as an indetifyer
 is base64 base on the flowing ASCII characters
 "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 +/"

            1111111111222222 22223333333334444444444455 5555555566 66
  01234567890123456789012345 67890123456789012345678901 2345678901 23

  and = as padding


*/

import std.format;
import tagion.hibon.HiBONException;
import misc = tagion.utils.Miscellaneous;
import std.base64;
import std.typecons : TypedefType;
public import tagion.basic.Types;
import tagion.basic.Types : encodeBase64;
import tagion.hibon.fix.Document;
import tagion.hibon.fix.HiBONRecord;

//alias toHex = misc.toHexString;

enum {
    hex_prefix = "0x",
    HEX_PREFIX = "0X"
}

string encodeBase64(const(Document) doc) pure {
    return encodeBase64(doc.data);
}

string encodeBase64(T)(const(T) t) pure
if (isHiBONRecord!T) {
    return encodeBase64(t.serialize);
}

@nogc bool isHexPrefix(const(char[]) str) pure nothrow {
    if (str.length >= hex_prefix.length) {
        return (str[0 .. hex_prefix.length] == hex_prefix)
            || (str[0 .. HEX_PREFIX.length] == HEX_PREFIX);
    }
    return false;
}

@nogc bool isBase64Prefix(const(char[]) str) pure nothrow {
    return (str.length > 0) && (str[0] is BASE64Indetifyer);
}

immutable(ubyte[]) decode(const(char[]) str) pure {
    if (isBase64Prefix(str)) {
        return Base64URL.decode(str[1 .. $]).idup;
    }
    else if (isHexPrefix(str)) {
        return misc.decode(str[hex_prefix.length .. $]);
    }
    return misc.decode(str);
}

Document decodeBase64(const(char[]) str) pure {
    return Document(decode(str));
}

unittest {
    import tagion.hibon.fix.HiBONRecord;
    import tagion.hibon.fix.HiBONtoText;
    import tagion.basic.Debug;

    static struct InnerTest {
        string inner_string;
        mixin HiBONRecord;
    }

    static struct TestName {
        @label("#name") string name; // Default name should always be "tagion"
        @label("inner") InnerTest inner_hibon;

        mixin HiBONRecord;
    }

    TestName test;
    InnerTest inner;

    inner.inner_string = "wowo";
    test.name = "tagion";
    test.inner_hibon = inner;

    const base64 = test.toDoc.encodeBase64;
    auto serialized = test.toDoc.serialize;
    __write("serialized=%s", serialized);
    const new_doc = Document(serialized);
    const valid = new_doc.valid;

    const after_base64 = new_doc.encodeBase64;

    assert(base64 == after_base64);
    __write("valid = %s", valid);
    assert(valid is Document.Element.ErrorCode.NONE);
}
    }
