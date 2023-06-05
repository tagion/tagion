module tagion.hibon.HiBONtoText;

/**
 HiBON Base64 with  ':' added in the front of the string as an indetifyer
 is base64 base on the flowing ASCII characters
 "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 +/"

            1111111111222222 22223333333334444444444455 5555555566 66
  01234567890123456789012345 67890123456789012345678901 2345678901 23

  and = as padding


*/

import misc = tagion.utils.Miscellaneous;
import tagion.hibon.HiBONException;
import std.format;
import std.base64;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;

alias toHex = misc.toHexString;

enum BASE64Indetifyer = '@';

enum {
    hex_prefix = "0x",
    HEX_PREFIX = "0X"
}

@safe string encodeBase64(const(ubyte[]) data) pure {
    const result = BASE64Indetifyer ~ Base64URL.encode(data);
    return result.idup;
}

@safe string encodeBase64(const(Document) doc) pure {
    return encodeBase64(doc.data);
}

@safe string encodeBase64(T)(const(T) t) pure
if (isHiBONRecord!T) {
    return encodeBase64(t.serialize);
}

@nogc @safe bool isHexPrefix(const(char[]) str) pure nothrow {
    if (str.length >= hex_prefix.length) {
        return (str[0 .. hex_prefix.length] == hex_prefix)
            || (str[0 .. HEX_PREFIX.length] == HEX_PREFIX);
    }
    return false;
}

@nogc @safe bool isBase64Prefix(const(char[]) str) pure nothrow {
    return (str.length > 0) && (str[0] is BASE64Indetifyer);
}

@safe immutable(ubyte[]) decode(const(char[]) str) pure {
    if (str[0] is BASE64Indetifyer) {
        return Base64URL.decode(str[1 .. $]).idup;
    }
    else if (isHexPrefix(str)) {
        return misc.decode(str[hex_prefix.length .. $]);
    }
    return misc.decode(str);
}

@safe Document decodeBase64(const(char[]) str) pure {
    return Document(decode(str));
}
